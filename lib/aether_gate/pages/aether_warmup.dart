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
import '../config/relay_config.dart';
import '../models/gate_mode.dart';
import '../router/aether_router.dart';
import '../transport/agate_log.dart';
import '../transport/arc_tap_reader.dart';
import '../transport/bolt_agent.dart';
import '../transport/bolt_pulse.dart';
import '../transport/relay_vault.dart';
import '../transport/signal_probe.dart';
import 'silence_screen.dart';
import 'spark_permit.dart';
import 'storm_channel.dart';

/// The very first screen the app mounts. Runs the router pipeline and hands
/// off to one of three places: WebView shell (gray), the existing SplashScreen
/// (white), or the No-Signal screen (offline). Uses the same webp backdrop
/// as SplashScreen so the transition to the game path is visually seamless.
///
/// A horizontal progress bar reflects real bootstrap stages (pulse.init →
/// cold-URL check → router decide → minimum-splash floor). The bar reaches
/// 100 % ONLY in the frame right before we push the next screen — a ticker
/// interpolates the shown value toward the stage target so the fill looks
/// continuous even though the underlying stages are discrete.
class AetherWarmup extends StatefulWidget {
  const AetherWarmup({
    super.key,
    required this.router,
    required this.vault,
    required this.pulse,
    required this.agent,
    required this.onNativeReady,
    this.fromRetry = false,
  });

  final AetherRouter router;
  final RelayVault vault;
  final BoltPulse pulse;
  final BoltAgent agent;
  final ValueChanged<AppState> onNativeReady;

  /// True when this warmup was mounted by SilenceScreen's Retry navigation.
  /// Instructs the router to skip its own DNS gate and to bounce back to
  /// SilenceScreen (rather than the native game) if the config POST fails
  /// with a transport error — the user is expecting the WebView flow to
  /// resume, not to be dropped into a different app section.
  final bool fromRetry;

  @override
  State<AetherWarmup> createState() => _AetherWarmupState();
}

class _AetherWarmupState extends State<AetherWarmup>
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

  /// Only advances the target — never rewinds. The ticker interpolates the
  /// shown value toward it, so the bar always crawls forward smoothly.
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
    // Slow crawl by default; sprint hard when the target is far ahead so
    // the bar can always catch up to the final 1.0 before the transition.
    // Ceiling raised well above the previous 0.40/s to guarantee the
    // finalize step's 500 ms window actually closes the gap.
    final speed = min(2.2, max(0.14, diff * 3.2));
    setState(() => _shown = min(_target, _shown + speed * dt));
  }

  Future<void> _boot() async {
    _advance(0.14);

    // FAST OFFLINE PATH — check the OS radio state before touching Firebase,
    // AppsFlyer or the config POST. When there is no radio at all, every one
    // of those calls will time out for seconds (Firebase 4 s, AppsFlyer 9 s,
    // POST 17 s) and the user stares at a loading bar for the whole window
    // before we finally show SilenceScreen. Skipping straight to the
    // no-wifi screen means the user sees it within one frame of the boot
    // instead. Firebase/AppsFlyer are re-initialised naturally the next time
    // the retry rebuilds AetherWarmup.
    if (!await SignalProbe(Connectivity()).hasRadio()) {
      agateLog(() => '[AGATE.warm] no radio at boot → SilenceScreen fast-path');
      if (!mounted) return;
      _showOffline();
      return;
    }

    // Firebase `getInitialMessage` MUST resolve before we look for a
    // cold-start URL — with FirebaseAppDelegateProxyEnabled=true (default)
    // Firebase eats the notification response and SceneDelegate never sees
    // it, so `ArcTapReader` alone returns null on the terminated-tap path.
    // BoltPulse.init writes any initial-message URL into the same vault key
    // we read below.
    try {
      await widget.pulse.init();
    } catch (_) {}
    _advance(0.34);

    // Cold-start push tap consumed FIRST — see START_HERE §5.1. Two paths:
    // (a) SceneDelegate (works when FirebaseAppDelegateProxyEnabled=false or
    //     the OS delivered the tap to Scene before Firebase swizzled),
    // (b) Firebase getInitialMessage → vault.writePushUrl (the default path).
    //
    // Both paths run BEFORE we choose which URL wins — we always drain the
    // vault as well, even if ArcTapReader already returned a URL. Otherwise
    // the vault keeps a stale copy from `pulse.init()` that
    // `StormChannel._consumePendingPush` fires on the NEXT
    // `AppLifecycleState.resumed` (i.e., on the 2nd push tap the WebView
    // silently reloads the previous session's URL before onMessageOpenedApp
    // even delivers the new one). See gray_flow_lessons.md §12.
    final tapUrl = await ArcTapReader.consume();
    final vaultUrl = await widget.vault.consumePushUrl();
    final coldUrl = tapUrl ?? vaultUrl;
    _advance(0.48);
    if (coldUrl != null && coldUrl.isNotEmpty) {
      agateLog(() => '[AGATE.warm] cold-start push → $coldUrl');
      await _finalize(() => _openPortal(coldUrl, coldStart: true));
      return;
    }

    final decision = await widget.router.decide(fromRetry: widget.fromRetry);
    agateLog(() => '[AGATE.warm] decision=$decision');
    _advance(0.82);

    // Small floor so the loading art does not flash on a fast decision.
    final elapsed = DateTime.now().difference(_startedAt);
    if (elapsed < AetherRelayConfig.minimumSplash) {
      await Future.delayed(AetherRelayConfig.minimumSplash - elapsed);
    }
    _advance(0.94);
    if (!mounted) return;

    switch (decision) {
      case GateWeb(url: final url):
        await _finalize(() => _openPermitOrPortal(url));
      case GateNative():
        await _finalize(_handOffToNative);
      case GateOffline():
        await _finalize(_showOffline);
    }
  }

  /// Push the bar to 100 % with a dedicated finish animation, then
  /// navigate. The ticker is bypassed for the final leg so the fill is
  /// GUARANTEED to reach the right edge no matter what the shown value
  /// happens to be when routing decides — the previous "wait for the
  /// ticker to catch up in 260 ms" window sometimes ended around 50–60 %
  /// because the diff → speed curve tops out.
  Future<void> _finalize(FutureOr<void> Function() navigate) async {
    const finishDuration = Duration(milliseconds: 520);
    final start = DateTime.now();
    final from = _shown;
    final delta = 1.0 - from;
    // Manual eased fill (easeOutCubic) — 16 ms tick, ~32 frames, so the
    // shown value monotonically climbs to exactly 1.0 in `finishDuration`.
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

  Future<void> _openPermitOrPortal(String url) async {
    final needsInvite = !widget.vault.pushGranted &&
        !widget.vault.pushBlockedByOs &&
        !widget.vault.inviteSnoozed;
    if (!needsInvite) {
      await _openPortal(url, coldStart: false);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      _fade(SparkPermit(
        pulse: widget.pulse,
        vault: widget.vault,
        agent: widget.agent,
        destination: url,
      )),
    );
  }

  Future<void> _openPortal(String url, {required bool coldStart}) async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(_fade(
      StormChannel(
        destination: url,
        pulse: widget.pulse,
        vault: widget.vault,
        agent: widget.agent,
        coldStartPush: coldStart,
      ),
    ));
  }

  void _handOffToNative() {
    // The existing SplashScreen runs the white-game bootstrap and hands the
    // AppState back to the app root via onReady.
    Navigator.of(context).pushReplacement(_fade(
      SplashScreen(onReady: widget.onNativeReady),
    ));
  }

  void _showOffline() {
    Navigator.of(context).pushReplacement(_fade(
      SilenceScreen(
        retryBuilder: (_) => AetherWarmup(
          router: widget.router,
          vault: widget.vault,
          pulse: widget.pulse,
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
