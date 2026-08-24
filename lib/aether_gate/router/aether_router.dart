import 'dart:async';
import 'dart:ui' as ui;

import '../config/relay_config.dart';
import '../models/gate_mode.dart';
import '../transport/agate_log.dart';
import '../transport/bolt_pulse.dart';
import '../transport/channel_dispatch.dart';
import '../transport/relay_vault.dart';
import '../transport/signal_probe.dart';
import '../transport/storm_attrib.dart';

/// The routing brain. `decide()` runs the full boot pipeline and returns a
/// GateDecision. It de-dupes CONCURRENT callers (returning the same future)
/// but clears its cache once complete, so a later Retry re-runs the whole
/// pipeline — see `gray_flow_lessons.md` §3.
class AetherRouter {
  AetherRouter({
    required this.vault,
    required this.probe,
    required this.attrib,
    required this.dispatch,
    required this.pulse,
    required this.gateEnabled,
  });

  final RelayVault vault;
  final SignalProbe probe;
  final StormAttrib attrib;
  final ChannelDispatch dispatch;
  final BoltPulse pulse;
  final bool gateEnabled;

  Future<GateDecision>? _pending;

  /// `fromRetry` should be set to true when the caller has just verified
  /// connectivity itself (e.g., SilenceScreen's Retry tap or auto-retry on
  /// a live connectivity event). It:
  ///   • skips the router's own `dnsProbe` step (iOS's DNS resolver takes
  ///     up to ~1–3 s to settle after a wifi hand-off — a fresh
  ///     `InternetAddress.lookup` reproducibly fails during that window
  ///     even though the interface is fully up), and
  ///   • treats a transport-level POST failure as `GateOffline` instead of
  ///     `GateNative`, so a retry from the no-wifi screen never silently
  ///     dumps the user into the native game just because the config
  ///     endpoint could not be reached yet.
  Future<GateDecision> decide({bool fromRetry = false}) {
    return _pending ??=
        _decide(fromRetry: fromRetry).whenComplete(() => _pending = null);
  }

  Future<GateDecision> _decide({required bool fromRetry}) async {
    if (!gateEnabled) {
      agateLog(() => '[AGATE.route] creds not ready → native');
      return const GateNative();
    }

    final storedRoute = await vault.route();
    agateLog(() => '[AGATE.route] stored=$storedRoute fromRetry=$fromRetry');

    switch (storedRoute) {
      case GateRoute.web:
        return _returningWeb(fromRetry: fromRetry);
      case GateRoute.native:
        return _returningNative();
      case GateRoute.fresh:
        return _firstDecision(fromRetry: fromRetry);
    }
  }

  // ---------------------------------------------------------- fresh install

  Future<GateDecision> _firstDecision({bool fromRetry = false}) async {
    // 1. Radio + real reachability before touching AppsFlyer — see lessons §25.
    if (!await probe.hasRadio()) {
      agateLog(() => '[AGATE.route] no radio → offline (fresh stays fresh)');
      return const GateOffline();
    }
    // Skip the DNS gate when the caller (SilenceScreen retry) has already
    // verified connectivity — iOS's DNS cache is reproducibly stale for a
    // second or two after a wifi hand-off and would false-fail here.
    if (!fromRetry && !await probe.dnsProbe()) {
      agateLog(() => '[AGATE.route] no dns → offline (fresh stays fresh)');
      return const GateOffline();
    }

    // 2. Attribution SDK must be started (ATT + initSdk) BEFORE we begin the
    //    conversion wait; the push token warms up in parallel. See lessons §26.
    final tokenFuture = pulse.obtainToken();
    await attrib.start();

    // 3. Bound the token wait tightly — a null token just omits the two push
    //    fields, it must NOT eat into the attribution window below.
    final token = await tokenFuture.timeout(
      const Duration(seconds: 4),
      onTimeout: () => null,
    );

    // 4. Build the flat body. buildPayload blocks up to `awaitSignalsInstall`
    //    for the AppsFlyer conversion callback, then assembles the payload.
    final body = await attrib.buildPayload(
      apnsFcmToken: token,
      locale: _locale(),
      afIdOverride: null,
    );
    // 5. Dispatch, with a bounded retry loop that ONLY protects against
    //    transport failure right after a wifi hand-off. `SilenceScreen`
    //    auto-navigates the moment `onConnectivityChanged` fires and iOS
    //    raises that event before DHCP + DNS + default route are fully up
    //    (~1–2 s on wifi, up to ~4 s on cellular). Without retries, the
    //    first POST hits an ENOTFOUND/connect-timeout, dispatch returns
    //    denied with `message == null`, and the retry path below bounces
    //    the user right back to SilenceScreen even though the network is
    //    up. A short backoff sequence gives the stack time to settle
    //    without introducing an extra "loading" phase on the happy path.
    final maxAttempts = fromRetry ? 4 : 1;
    const backoffs = <Duration>[
      Duration(milliseconds: 700),
      Duration(milliseconds: 1200),
      Duration(milliseconds: 1600),
    ];
    var reply = await dispatch.send(body);
    var attempt = 1;
    while (attempt < maxAttempts &&
        !reply.granted &&
        reply.message == null) {
      final wait = backoffs[(attempt - 1).clamp(0, backoffs.length - 1)];
      agateLog(() =>
          '[AGATE.route] POST transport-failed, retry ${attempt + 1}/$maxAttempts in ${wait.inMilliseconds}ms');
      await Future<void>.delayed(wait);
      reply = await dispatch.send(body);
      attempt += 1;
    }

    if (reply.granted && reply.destination != null) {
      await vault.writeSavedUrl(reply.destination!, expiresAt: reply.expiresAt);
      await vault.commitRoute(GateRoute.web);
      return GateWeb(reply.destination!);
    }

    // Transport-level failure (no HTTP status → no `message` from server).
    // On the retry path we must NOT commit any route and must NOT drop the
    // user into the native game — bounce back to SilenceScreen so the
    // user's next Retry tap can try again once the network truly settles.
    if (fromRetry && reply.message == null) {
      agateLog(() =>
          '[AGATE.route] retry POST transport-failed after $attempt attempts → offline');
      return const GateOffline();
    }

    // A "no data" answer only commits us to native when the POST ACTUALLY
    // carried attribution. If AppsFlyer was slow and the body had no
    // attribution keys (only the base identity fields), keep the route `fresh`
    // so the next launch retries — by then AppsFlyer serves the conversion
    // from cache instantly and the POST carries full attribution. This stops a
    // slow first launch from permanently trapping a non-organic user on the
    // native game (the exact symptom: 404 "No data" arriving before the
    // conversion callback). See gray_flow_lessons.md §5.
    if (reply.message != null && _bodyHasAttribution(body)) {
      await vault.commitRoute(GateRoute.native);
      await vault.setOrganicCommitted(true);
    }
    return const GateNative();
  }

  // ---------------------------------------------------- returning web install

  Future<GateDecision> _returningWeb({bool fromRetry = false}) async {
    if (!await probe.hasRadio()) return const GateOffline();

    // Race a fresh POST with the saved URL. If we already have a saved URL
    // that has not expired, hand it back immediately and let a background
    // refresh update it for next launch.
    final saved = await vault.savedUrl();
    if (saved != null) {
      unawaited(_backgroundRefresh());
      return GateWeb(saved);
    }

    // No saved URL — do a live decision.
    return _firstDecision(fromRetry: fromRetry);
  }

  Future<void> _backgroundRefresh() async {
    try {
      unawaited(attrib.start());
      final token = pulse.cachedToken ??
          await pulse.obtainToken().timeout(
                AetherRelayConfig.awaitSignalsInstall,
                onTimeout: () => null,
              );
      final body = await attrib.buildPayload(
        apnsFcmToken: token,
        locale: _locale(),
        afIdOverride: null,
      );
      final reply = await dispatch.send(body);
      if (reply.granted && reply.destination != null) {
        await vault.writeSavedUrl(reply.destination!,
            expiresAt: reply.expiresAt);
      }
    } catch (e) {
      agateLog(() => '[AGATE.route] bg refresh failed: $e');
    }
  }

  // --------------------------------------------------- returning native install

  Future<GateDecision> _returningNative() async {
    // Occasional re-conversion — never blocking. The organic user keeps the
    // native path unless a successful reply flips them.
    final last = vault.lastOrganicCheck;
    final due = last == null ||
        DateTime.now().difference(last).inSeconds >=
            AetherRelayConfig.organicRecheckSeconds * 3600;
    if (due && await probe.hasRadio()) {
      unawaited(_organicRecheck());
    }
    return const GateNative();
  }

  Future<void> _organicRecheck() async {
    try {
      await vault.stampOrganicCheck();
      unawaited(attrib.start());
      final token = pulse.cachedToken;
      final body = await attrib.buildPayload(
        apnsFcmToken: token,
        locale: _locale(),
        afIdOverride: null,
      );
      final reply = await dispatch.send(body);
      if (reply.granted && reply.destination != null) {
        await vault.writeSavedUrl(reply.destination!,
            expiresAt: reply.expiresAt);
        await vault.commitRoute(GateRoute.web);
        agateLog(() => '[AGATE.route] recheck flipped native → web');
      }
    } catch (_) {}
  }

  /// True when the composed body carries AppsFlyer attribution — i.e. any key
  /// beyond the base identity fields that are always present. Used to tell a
  /// genuine "no campaign" answer (attribution present → commit native) apart
  /// from a slow-conversion miss (attribution absent → stay fresh, retry).
  static bool _bodyHasAttribution(Map<String, dynamic> body) {
    const baseKeys = <String>{
      'af_id',
      'bundle_id',
      'os',
      'store_id',
      'locale',
      'push_token',
      'firebase_project_id',
    };
    return body.keys.any((k) => !baseKeys.contains(k));
  }

  static String _locale() {
    try {
      final l = ui.PlatformDispatcher.instance.locale;
      final code = l.countryCode == null || l.countryCode!.isEmpty
          ? l.languageCode
          : '${l.languageCode}_${l.countryCode}';
      return code.isEmpty ? 'en_US' : code;
    } catch (_) {
      return 'en_US';
    }
  }
}
