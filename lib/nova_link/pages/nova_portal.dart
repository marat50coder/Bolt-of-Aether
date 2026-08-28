import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../config/link_config.dart';
import '../transport/link_agent.dart';
import '../transport/link_ledger.dart';
import '../transport/net_probe.dart';
import '../transport/nova_log.dart';
import '../transport/push_bridge.dart';
import 'hush_screen.dart';

/// WebView shell. Diversification vs anything else in the ecosystem
/// lives in three places:
///
///   • the merged single-sentinel JS bundle injected once per page (no
///     six-callsite injection pattern),
///   • the rotated numeric constants pulled from [LinkConfig],
///   • the encoded User-Agent fragments assembled by [LinkAgent].
class NovaPortal extends StatefulWidget {
  const NovaPortal({
    super.key,
    required this.destination,
    required this.push,
    required this.ledger,
    required this.agent,
    this.coldStartPush = false,
  });

  final String destination;
  final PushBridge push;
  final LinkLedger ledger;
  final LinkAgent agent;
  final bool coldStartPush;

  @override
  State<NovaPortal> createState() => _NovaPortalState();
}

class _NovaPortalState extends State<NovaPortal>
    with WidgetsBindingObserver {
  late final WebViewController _web;
  final _connectivity = Connectivity();
  StreamSubscription<dynamic>? _connSub;
  Timer? _metricsDebounce;
  Size? _lastMetricsSize;

  bool _viewportReady = false;
  bool _coldReloadDone = false;
  int _redirectAttempts = 0;
  String? _lastMainFrame;
  bool _offlineShown = false;
  int _transientReloadAttempts = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyImmersive();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _bindConnectivity();

    // Controller setup is SYNCHRONOUS (cascade) so `_viewportReady = true`
    // can flip in the same initState frame. An earlier awaited setup added
    // ~200-500 ms of black flash between the warmup and the WebView's
    // first paint. All `..setX(...)` calls fire-and-forget on the
    // platform side; they are ready by the time WKWebView actually
    // processes `loadRequest`.
    final params = (Platform.isIOS || Platform.isMacOS)
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    _web = WebViewController.fromPlatformCreationParams(
      params,
      onPermissionRequest: (request) => request.grant(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(widget.agent.userAgent)
      ..enableZoom(false)
      ..setNavigationDelegate(_navigation());
    if (_web.platform is WebKitWebViewController) {
      (_web.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }

    // Live push taps (`onMessageOpenedApp` background/foreground-tap)
    // route through PushBridge → this callback, which loads the URL
    // into the current WebView. Registered before the first frame so a
    // push that dispatches concurrently is never lost. Single callback
    // (not a list) — a remounted NovaPortal simply replaces the
    // previous receiver.
    widget.push.onDestination = _onPushLink;

    if (widget.coldStartPush) {
      _settleColdViewport();
    } else {
      _viewportReady = true;
      _web.loadRequest(Uri.parse(widget.destination));
    }
    // First-frame drain of any URL PushBridge persisted before the
    // WebView was mounted (splash / consent / native path in between).
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingPush());
  }

  void _onPushLink(String url) {
    if (!mounted) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;
    novaLog(() => '[NOVA.wv] push → load $url');
    // Clear the persisted copy — this listener has claimed the URL, so
    // a subsequent [_consumePendingPush] on resume must not fire it
    // again.
    unawaited(widget.ledger.consumePushUrl());
    _web.loadRequest(uri);
  }

  Future<void> _consumePendingPush() async {
    try {
      final pending = await widget.ledger.consumePushUrl();
      if (pending == null || pending.isEmpty) return;
      final uri = Uri.tryParse(pending);
      if (uri == null || !uri.hasScheme) return;
      if (!mounted) return;
      novaLog(() => '[NOVA.wv] drained pending push → $pending');
      _web.loadRequest(uri);
    } catch (_) {}
  }

  NavigationDelegate _navigation() {
    return NavigationDelegate(
      onPageStarted: (url) {
        _lastMainFrame = url;
      },
      onPageFinished: (_) {
        _redirectAttempts = 0;
        _transientReloadAttempts = 0;
        _primeShell();
        _scheduleResizeSettle();
      },
      onWebResourceError: _handleError,
      onNavigationRequest: (request) {
        final uri = Uri.tryParse(request.url);
        if (uri == null) return NavigationDecision.prevent;
        // Scheme gate only — never a host allowlist. Configuration may
        // swap the partner host after release; an allowlist would
        // silently drop the new URL.
        if (<String>{'http', 'https', 'about', 'data', 'blob'}
            .contains(uri.scheme.toLowerCase())) {
          if (request.isMainFrame) _lastMainFrame = request.url;
          return NavigationDecision.navigate;
        }
        if (uri.scheme.toLowerCase() == 'javascript') {
          return NavigationDecision.prevent;
        }
        // Everything else (tel, mailto, sms, app schemes) → hand off to
        // iOS without stalling the WebView.
        launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
        return NavigationDecision.prevent;
      },
    );
  }

  void _handleError(WebResourceError error) {
    // -999 = cancelled (a new nav superseded this one) — ignore.
    if (error.errorCode == -999) return;
    // WKWebView occasionally reports `isForMainFrame` as null for the
    // actual main navigation. Treat null as main so a real failure is
    // never silently swallowed (which used to leave the app "frozen").
    final mainFrame = error.isForMainFrame ?? true;
    final lower = error.description.toLowerCase();
    final redirectLoop = error.errorCode == -1007 ||
        lower.contains('too_many_redirects') ||
        lower.contains('too many redirects');
    // Redirect-loop recovery: re-issue the last main-frame URL as a
    // fresh navigation (resets WKWebView's internal redirect counter).
    // Bounded by the project-rotated limit.
    if (redirectLoop &&
        _lastMainFrame != null &&
        _redirectAttempts < LinkConfig.redirectRetryLimit) {
      _redirectAttempts += 1;
      novaLog(() => '[NOVA.wv] redirect retry $_redirectAttempts');
      _web.loadRequest(Uri.parse(_lastMainFrame!));
      return;
    }
    if (!mainFrame) return;
    _handleMainFrameFailure(error);
  }

  /// Transient-vs-real outage arbiter for main-frame load failures.
  ///
  /// Right after a wifi hand-off (auto-retry from the offline screen)
  /// the OS reports the interface UP well before DHCP + DNS + default
  /// route are actually usable. WKWebView then reports -1004 / -1005 /
  /// -1009 on the very first `loadRequest` — but the connection is
  /// genuinely fine a second later. This method retries the LOAD (not
  /// just the DNS probe) with backoff; the DNS probe only decides
  /// whether to keep waiting for the next reload attempt or to give
  /// up immediately.
  Future<void> _handleMainFrameFailure(WebResourceError error) async {
    if (_offlineShown) return;
    const transientCodes = <int>{
      -1001, // NSURLErrorTimedOut
      -1003, // NSURLErrorCannotFindHost
      -1004, // NSURLErrorCannotConnectToHost
      -1005, // NSURLErrorNetworkConnectionLost
      -1009, // NSURLErrorNotConnectedToInternet
      -1200, // NSURLErrorSecureConnectionFailed (transient on wifi hand-off)
    };
    final transient = transientCodes.contains(error.errorCode);

    // Full connectivity blackout? Go straight to the offline screen —
    // no point reloading a URL when the radio itself is off.
    final hasRadio = await NetProbe(_connectivity).hasRadio();
    if (!hasRadio) {
      novaLog(() =>
          '[NOVA.wv] mainframe error ${error.errorCode} — no radio → offline');
      _goOffline();
      return;
    }

    // Non-transient error while radio is up (bad URL, TLS pin mismatch,
    // 4xx / 5xx from the origin, etc.) — retrying would just loop.
    // Probe once so a real outage still surfaces, otherwise stay on
    // the shell.
    if (!transient) {
      final online = await NetProbe(_connectivity).dnsProbe();
      if (!online) _goOffline();
      return;
    }

    // Transient error path: retry the load with backoff. Only after
    // every retry has failed do we consider the outage real and probe
    // DNS.
    const maxAttempts = 4;
    const backoffs = <Duration>[
      Duration(milliseconds: 800),
      Duration(milliseconds: 1400),
      Duration(milliseconds: 2200),
      Duration(milliseconds: 3200),
    ];
    if (_transientReloadAttempts >= maxAttempts) {
      final online = await NetProbe(_connectivity).dnsProbe();
      if (!online) {
        novaLog(() => '[NOVA.wv] transient exhausted, dns dead → offline');
        _goOffline();
      } else {
        novaLog(() => '[NOVA.wv] transient exhausted but dns ok — staying on shell');
        _transientReloadAttempts = 0;
      }
      return;
    }
    final wait = backoffs[_transientReloadAttempts];
    _transientReloadAttempts += 1;
    novaLog(() =>
        '[NOVA.wv] transient ${error.errorCode}, reload attempt $_transientReloadAttempts/$maxAttempts in ${wait.inMilliseconds}ms');
    await Future<void>.delayed(wait);
    if (!mounted || _offlineShown) return;
    final target = _lastMainFrame ?? widget.destination;
    try {
      await _web.loadRequest(Uri.parse(target));
    } catch (e) {
      novaLog(() => '[NOVA.wv] reload threw: $e');
    }
  }

  Future<void> _goOffline() async {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    // Capture the ACTUAL page the user was on so the retry reloads
    // that page (deep inside the partner flow), not the initial
    // config-endpoint destination. Fallbacks: last main-frame URL we
    // saw, then widget.destination as a final safety net.
    String resumeUrl = widget.destination;
    try {
      resumeUrl = await _web.currentUrl() ??
          _lastMainFrame ??
          widget.destination;
    } catch (_) {
      resumeUrl = _lastMainFrame ?? widget.destination;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => HushScreen(
          retryBuilder: (_) => NovaPortal(
            destination: resumeUrl,
            push: widget.push,
            ledger: widget.ledger,
            agent: widget.agent,
            coldStartPush: false,
          ),
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _settleColdViewport() async {
    _applyImmersive();
    // Let immersive settle in the phone's ACTUAL orientation before
    // mounting; no landscape nudge — that caused a visible sideways
    // flip. Non-round settle duration on purpose.
    await Future<void>.delayed(LinkConfig.coldViewportSettle);
    if (!mounted) return;
    setState(() => _viewportReady = true);
    await _web.loadRequest(Uri.parse(widget.destination));
  }

  void _applyImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  void _restoreSystemUi() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _bindConnectivity() {
    _connSub = _connectivity.onConnectivityChanged.listen((flat) {
      final online = flat.any((r) => r != ConnectivityResult.none);
      // Connectivity definitively gone → offline immediately, no probe
      // (a probe hangs for seconds while offline and lets WKWebView
      // render its built-in error page first).
      if (!online) _goOffline();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _applyImmersive();
      // A push tap can bring us back from background AFTER PushBridge
      // had a brief moment to fire; drain the ledger in case the
      // listener race lost.
      _consumePendingPush();
    }
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    setState(() {});
    // Only re-poke on genuine rotation (portrait ↔ landscape). WKWebView
    // keeps the pre-rotation viewport width for a few hundred ms, so
    // the site renders at the wrong width right after the flip. Firing
    // resize several times as the native frame settles lets the page
    // reflow to the new width fast, instead of a visible ~1 s stretch.
    final view = View.of(context);
    final size = view.physicalSize;
    final rotated = _lastMetricsSize != null &&
        ((_lastMetricsSize!.width < _lastMetricsSize!.height) !=
            (size.width < size.height));
    _lastMetricsSize = size;
    if (!rotated) return;
    _applyImmersive();
    _metricsDebounce?.cancel();
    _pokeReflow();
  }

  void _pokeReflow() {
    for (final delay in LinkConfig.pokeReflowDelays) {
      Timer(delay, () async {
        if (!mounted) return;
        try {
          await _web.runJavaScript(
            'window.dispatchEvent(new Event("orientationchange"));'
            'window.dispatchEvent(new Event("resize"));'
            'if(window.visualViewport){'
            '  window.visualViewport.dispatchEvent(new Event("resize"));'
            '}',
          );
        } catch (_) {}
      });
    }
    // Re-assert the viewport lock once the reflows have settled.
    _metricsDebounce = Timer(const Duration(milliseconds: 285), () {
      if (!mounted) return;
      _primeShell();
    });
  }

  void _scheduleResizeSettle() {
    Future<void>.delayed(LinkConfig.postLoadResizeDelay, () async {
      if (!mounted) return;
      setState(() {}); // re-read viewPadding
      try {
        await _web.runJavaScript(
          'window.dispatchEvent(new Event("resize"));'
          'if(window.visualViewport){'
          '  window.visualViewport.dispatchEvent(new Event("resize"));'
          '}',
        );
      } catch (_) {}
      await _primeShell();
      if (widget.coldStartPush && !_coldReloadDone) {
        _coldReloadDone = true;
        await _web.reload();
      }
    });
  }

  /// One merged, single-sentinel native-feel bundle. Responsibilities:
  /// zero the site's safe-area CSS variables, kill overscroll +
  /// tap-highlight, lock the viewport (zoom off), keep a focused field
  /// visible above the keyboard, tint the scrollbar, prime inline
  /// video autoplay. Idempotent (`window.__novaSkin`). Does NOT touch
  /// link behaviour — a scripted top navigation dropped Referer /
  /// Sec-Fetch and made partner servers bounce into a -1007 loop, and
  /// the native click / `location.href` path is enough.
  Future<void> _primeShell() async {
    try {
      await _web.runJavaScript(r'''
(function(){
  var root = window;
  var doc = document;
  var primed = new WeakSet();

  function typing(){
    var visual = root.visualViewport;
    return !!visual && visual.height < root.innerHeight * 0.72;
  }

  var brandId = '__nova_skin';
  var sheetText = [
    ':root{--safe-area-inset-top:0px!important;--safe-area-inset-right:0px!important;--safe-area-inset-bottom:0px!important;--safe-area-inset-left:0px!important;--sat:0px!important;--sar:0px!important;--sab:0px!important;--sal:0px!important;--safe-top:0px!important;--safe-bottom:0px!important;--safe-left:0px!important;--safe-right:0px!important;}',
    '.gameview-mobile-header,.app-header,.js-safe-top{padding-top:0!important;margin-top:0!important;}',
    'html,body{overscroll-behavior:none!important;overscroll-behavior-y:none!important;-webkit-tap-highlight-color:transparent!important;}',
    '*:not(input):not(textarea):not([contenteditable="true"]){-webkit-touch-callout:none!important;}',
    '*::-webkit-scrollbar{width:5px;height:5px;}',
    '*::-webkit-scrollbar-thumb{background:rgba(90,142,255,.32);border-radius:8px;}',
    'input,textarea,select,[contenteditable="true"]{font-size:max(16px,1em)!important;}'
  ].join('');

  function paint(){
    if (typing()) return;
    var host = doc.head || doc.documentElement;
    if (!host) return;
    var vp = doc.querySelector('meta[name="viewport"]');
    if (!vp){
      vp = doc.createElement('meta');
      vp.setAttribute('name','viewport');
      host.appendChild(vp);
    }
    vp.setAttribute('content','width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no, viewport-fit=contain');
    var skin = doc.getElementById(brandId);
    if (!skin){
      skin = doc.createElement('style');
      skin.id = brandId;
      host.appendChild(skin);
    }
    if (skin.textContent !== sheetText) skin.textContent = sheetText;
  }

  if (root.__novaSkin){ paint(); return; }
  root.__novaSkin = 1;

  function swallow(ev){ try { ev.preventDefault(); } catch(_){} }
  var gestureTypes = ['gesturestart','gesturechange','gestureend'];
  for (var g = 0; g < gestureTypes.length; g++){
    doc.addEventListener(gestureTypes[g], swallow, {passive:false});
  }
  doc.addEventListener('touchmove', function(ev){
    if (ev.scale !== undefined && ev.scale !== 1) ev.preventDefault();
  }, {passive:false});

  var lastTapAt = 0;
  doc.addEventListener('touchend', function(ev){
    var now = Date.now();
    if (now - lastTapAt <= 285) ev.preventDefault();
    lastTapAt = now;
  }, {passive:false});

  function isFieldNode(node){
    return !!node && typeof node.matches === 'function' &&
      node.matches('input, textarea, select, [contenteditable="true"]');
  }
  function revealField(){
    var active = doc.activeElement;
    if (isFieldNode(active)){
      try { active.scrollIntoView({behavior:'auto', block:'nearest'}); } catch(_){}
    }
  }
  doc.addEventListener('focusin', function(ev){
    if (isFieldNode(ev.target)) root.setTimeout(revealField, 385);
  }, true);

  function primeClip(video){
    if (!(video instanceof HTMLVideoElement) || primed.has(video)) return;
    primed.add(video);
    try {
      video.setAttribute('playsinline','');
      video.setAttribute('webkit-playsinline','');
      video.playsInline = true;
      video.autoplay = true;
      var attempt = video.play();
      if (attempt && typeof attempt.catch === 'function') attempt.catch(function(){});
    } catch(_){}
  }
  function sweepClips(scope){
    if (scope instanceof HTMLVideoElement) primeClip(scope);
    if (scope && typeof scope.querySelectorAll === 'function'){
      scope.querySelectorAll('video').forEach(primeClip);
    }
  }
  sweepClips(doc);

  var bumpApply = function(){
    root.setTimeout(paint, 195);
    root.setTimeout(paint, 705);
  };
  ['pushState','replaceState'].forEach(function(name){
    var original = history[name];
    history[name] = function(){
      var result = original.apply(this, arguments);
      bumpApply();
      return result;
    };
  });
  root.addEventListener('popstate', bumpApply);

  paint();
  root.setInterval(paint, 3350);

  new MutationObserver(function(records){
    for (var i = 0; i < records.length; i++){
      records[i].addedNodes.forEach(sweepClips);
    }
  }).observe(doc.documentElement, {childList:true, subtree:true});
})();
''');
    } catch (e) {
      novaLog(() => '[NOVA.wv] inject failed: $e');
    }
  }

  @override
  void dispose() {
    if (widget.push.onDestination == _onPushLink) {
      widget.push.onDestination = null;
    }
    _connSub?.cancel();
    _metricsDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _restoreSystemUi();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).viewPadding;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Back inside the WebView. If we're on the first page, do
        // NOTHING — never close the shell.
        try {
          if (await _web.canGoBack()) await _web.goBack();
        } catch (_) {}
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: _viewportReady
            ? Padding(
                // Respect notch/Dynamic Island (top + sides) AND the
                // home indicator (bottom) in BOTH orientations. Cold
                // start uses viewPadding (never EdgeInsets.zero) so
                // the bottom inset is not lost while immersive mode
                // settles.
                padding: EdgeInsets.only(
                  top: safe.top,
                  bottom: safe.bottom,
                  left: safe.left,
                  right: safe.right,
                ),
                child: WebViewWidget(controller: _web),
              )
            : const ColoredBox(color: Colors.black),
      ),
    );
  }
}
