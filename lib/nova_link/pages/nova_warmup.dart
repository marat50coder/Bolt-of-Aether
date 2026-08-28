import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/app_palette.dart';
import '../../core/app_state.dart';
import '../../screens/splash_screen.dart'
    show AetherProgressBar, DottedLoadingText, SplashScreen;
import '../config/link_config.dart';
import '../models/link_mode.dart';
import '../router/link_router.dart';
import '../transport/link_agent.dart';
import '../transport/link_ledger.dart';
import '../transport/net_probe.dart';
import '../transport/nova_log.dart';
import '../transport/push_bridge.dart';
import '../transport/tap_bridge.dart';
import 'chime_consent.dart';
import 'hush_screen.dart';
import 'nova_portal.dart';

/// The very first screen the app mounts. Runs the router pipeline and
/// hands off to one of three places: the WebView shell, the native
/// game splash, or the offline screen. Uses the same webp backdrop as
/// the splash so the transition to the native path is visually
/// seamless.
///
/// A horizontal progress bar reflects real bootstrap stages
/// (push.init → cold-URL check → router decide → minimum-splash
/// floor). It reaches 100 % ONLY on the frame right before we push
/// the next screen — a ticker interpolates the shown value toward the
/// current stage target so the fill looks continuous even though the
/// underlying stages are discrete.
class NovaWarmup extends StatefulWidget {
  const NovaWarmup({
    super.key,
    required this.router,
    required this.ledger,
    required this.push,
    required this.agent,
    required this.onNativeReady,
    this.fromRetry = false,
  });

  final LinkRouter router;
  final LinkLedger ledger;
  final PushBridge push;
  final LinkAgent agent;
  final ValueChanged<AppState> onNativeReady;

  /// True when this warmup was mounted by the offline screen's Retry
  /// navigation. Instructs the router to skip its own DNS gate and to
  /// bounce back to the offline screen (rather than the native app) on
  /// a transport-level POST failure — the user is expecting the WebView
  /// flow to resume, not to be dropped into a different app section.
  final bool fromRetry;

  @override
  State<NovaWarmup> createState() => _NovaWarmupState();
}

class _NovaWarmupState extends State<NovaWarmup>
    with SingleTickerProviderStateMixin {
  DateTime _startedAt = DateTime.now();

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _target = 0.08;
  double _shown = 0.0;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Only advances the target — never rewinds. The ticker interpolates
  /// the shown value toward it, so the bar always crawls forward.
  void _advance(double stage) {
    if (!mounted) return;
    setState(() => _target = max(_target, stage.clamp(0.0, 1.0)));
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    final diff = _target - _shown;
    if (diff <= 0) return;
    // Slow crawl by default; sprint hard when the target is far ahead
    // so the bar can always catch up to the final 1.0 before the
    // transition. Ceiling raised above the previous 0.40/s so the
    // finalize step's 500 ms window actually closes the gap.
    final speed = min(2.2, max(0.14, diff * 3.2));
    setState(() => _shown = min(_target, _shown + speed * dt));
  }

  Future<void> _boot() async {
    _advance(0.14);

    // FAST OFFLINE PATH — check reachability before touching Firebase,
    // AppsFlyer or the config POST. Without this the pipeline would eat
    // ~14 s of timeouts (Firebase init 4 s + AppsFlyer wait 9 s + POST
    // 17 s + finalize 0.6 s) with the loading art on screen before
    // finally showing the offline screen. Two-stage check:
    //   • `hasRadio` — cheap OS flag, catches "airplane mode / wifi off".
    //   • `quickReach` — single DNS lookup with a tight timeout, no
    //     retry. Catches "wifi UP but no packets" (dead hotspot,
    //     captive portal, VPN dead). On a truly offline device the
    //     lookup throws SocketException within ~200 ms so the offline
    //     screen still feels instant.
    // Firebase / AppsFlyer initialise naturally the next time the retry
    // rebuilds this warmup, once the network is actually up.
    final bootProbe = NetProbe(Connectivity());
    if (!await bootProbe.quickReach()) {
      novaLog(() => '[NOVA.warm] offline at boot → hush fast-path');
      if (!mounted) return;
      _showOffline();
      return;
    }

    // Firebase `getInitialMessage` MUST resolve before we look for a
    // cold-start URL. With FirebaseAppDelegateProxyEnabled = true
    // (default) Firebase eats the notification response and
    // SceneDelegate never sees it, so [TapBridge] alone returns null
    // on the terminated-tap path. PushBridge.init writes any
    // initial-message URL into the same ledger key we read below.
    try {
      await widget.push.init();
    } catch (_) {}
    _advance(0.34);

    // Cold-start push tap is consumed FIRST. Two paths:
    //  (a) SceneDelegate (works when FirebaseAppDelegateProxyEnabled =
    //      false or the OS delivered the tap to Scene before Firebase
    //      swizzled),
    //  (b) Firebase getInitialMessage → ledger.writePushUrl (the
    //      default path).
    //
    // Both paths run BEFORE we choose which URL wins — we always drain
    // the ledger as well, even if [TapBridge] already returned a URL.
    // Otherwise the ledger keeps a stale copy from `push.init()` that
    // NovaPortal._consumePendingPush fires on the next
    // AppLifecycleState.resumed (i.e., on the 2nd push tap the WebView
    // silently reloads the previous session's URL before
    // onMessageOpenedApp even delivers the new one).
    final tapUrl = await TapBridge.consume();
    final ledgerUrl = await widget.ledger.consumePushUrl();
    final coldUrl = tapUrl ?? ledgerUrl;
    _advance(0.48);
    if (coldUrl != null && coldUrl.isNotEmpty) {
      novaLog(() => '[NOVA.warm] cold-start push → $coldUrl');
      await _finalize(() => _openPortal(coldUrl, coldStart: true));
      return;
    }

    final decision = await widget.router.decide(fromRetry: widget.fromRetry);
    novaLog(() => '[NOVA.warm] decision=$decision');
    _advance(0.82);

    // Small floor so the loading art does not flash on a fast decision.
    final elapsed = DateTime.now().difference(_startedAt);
    if (elapsed < LinkConfig.minimumSplash) {
      await Future.delayed(LinkConfig.minimumSplash - elapsed);
    }
    _advance(0.94);
    if (!mounted) return;

    switch (decision) {
      case LinkWeb(url: final url):
        await _finalize(() => _openConsentOrPortal(url));
      case LinkNative():
        await _finalize(_handOffToNative);
      case LinkOffline():
        await _finalize(_showOffline);
    }
  }

  /// Push the bar to 100 % with a dedicated finish animation, then
  /// navigate. The ticker is bypassed for the final leg so the fill is
  /// GUARANTEED to reach the right edge no matter what the shown value
  /// happens to be when routing decides.
  Future<void> _finalize(FutureOr<void> Function() navigate) async {
    const finishDuration = Duration(milliseconds: 520);
    final start = DateTime.now();
    final from = _shown;
    final delta = 1.0 - from;
    // Manual eased fill (easeOutCubic) — 16 ms tick, ~32 frames — so the
    // shown value monotonically climbs to exactly 1.0 within
    // `finishDuration`.
    while (mounted) {
      final elapsed = DateTime.now().difference(start);
      final t = (elapsed.inMicroseconds / finishDuration.inMicroseconds)
          .clamp(0.0, 1.0);
      final eased = 1 - pow(1 - t, 3).toDouble();
      final next = from + delta * eased;
      setState(() {
        _shown = max(_shown, next);
        _target = max(_target, _shown);
      });
      if (t >= 1.0) break;
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    // Small linger so the eye reads "100 %" as a beat, not a cut.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    await navigate();
  }

  Future<void> _openConsentOrPortal(String url) async {
    final needsInvite = !widget.ledger.pushGranted &&
        !widget.ledger.pushBlockedByOs &&
        !widget.ledger.inviteSnoozed;
    if (!needsInvite) {
      await _openPortal(url, coldStart: false);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      _fade(ChimeConsent(
        push: widget.push,
        ledger: widget.ledger,
        agent: widget.agent,
        destination: url,
      )),
    );
  }

  Future<void> _openPortal(String url, {required bool coldStart}) async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(_fade(
      NovaPortal(
        destination: url,
        push: widget.push,
        ledger: widget.ledger,
        agent: widget.agent,
        coldStartPush: coldStart,
      ),
    ));
  }

  void _handOffToNative() {
    // The existing SplashScreen runs the white-game bootstrap and hands
    // the AppState back to the app root via onReady.
    Navigator.of(context).pushReplacement(_fade(
      SplashScreen(onReady: widget.onNativeReady),
    ));
  }

  void _showOffline() {
    Navigator.of(context).pushReplacement(_fade(
      HushScreen(
        retryBuilder: (_) => NovaWarmup(
          router: widget.router,
          ledger: widget.ledger,
          push: widget.push,
          agent: widget.agent,
          onNativeReady: widget.onNativeReady,
          fromRetry: true,
        ),
      ),
    ));
  }

  PageRouteBuilder<T> _fade<T>(Widget page) => PageRouteBuilder<T>(
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AetherColors.night,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final portrait = orientation == Orientation.portrait;
          final asset = portrait
              ? 'assets/Vertical_Loading_Screen.webp'
              : 'assets/Horizontal_Loading_Screen.webp';
          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AetherColors.backdrop),
              ),
              Image.asset(asset, fit: BoxFit.cover, filterQuality: FilterQuality.high),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AetherColors.night.withValues(alpha: portrait ? 0.72 : 0.85),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: portrait ? 30 : 76,
                      vertical: portrait ? 44 : 22,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const DottedLoadingText(text: 'Loading', fontSize: 22),
                          const SizedBox(height: 18),
                          AetherProgressBar(value: _shown),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
