import 'dart:async';
import 'dart:ui' as ui;

import '../config/link_config.dart';
import '../models/link_mode.dart';
import '../transport/anchor_attrib.dart';
import '../transport/link_courier.dart';
import '../transport/link_ledger.dart';
import '../transport/net_probe.dart';
import '../transport/nova_log.dart';
import '../transport/push_bridge.dart';

/// The routing brain. [decide] runs the full boot pipeline and returns a
/// [LinkDecision]. It de-dupes CONCURRENT callers (they share the same
/// future) but clears its cache once complete, so a later Retry re-runs
/// the pipeline from scratch.
class LinkRouter {
  LinkRouter({
    required this.ledger,
    required this.probe,
    required this.attrib,
    required this.courier,
    required this.push,
    required this.remoteEnabled,
  });

  final LinkLedger ledger;
  final NetProbe probe;
  final AnchorAttrib attrib;
  final LinkCourier courier;
  final PushBridge push;
  final bool remoteEnabled;

  Future<LinkDecision>? _pending;

  /// `fromRetry` should be true when the caller has just verified
  /// connectivity itself (e.g. the offline-screen retry tap or an
  /// auto-retry on a live connectivity event). It:
  ///
  ///   • skips the router's own [NetProbe.dnsProbe] step (iOS's DNS
  ///     resolver can take ~1–3 s to settle after a wifi hand-off —
  ///     a fresh `InternetAddress.lookup` reproducibly fails inside
  ///     that window even though the interface is fully up), and
  ///   • treats a transport-level POST failure as [LinkOffline]
  ///     instead of [LinkNative], so a retry from the offline screen
  ///     never silently drops the user into the native app just
  ///     because the config endpoint could not be reached yet.
  Future<LinkDecision> decide({bool fromRetry = false}) {
    return _pending ??=
        _decide(fromRetry: fromRetry).whenComplete(() => _pending = null);
  }

  Future<LinkDecision> _decide({required bool fromRetry}) async {
    if (!remoteEnabled) {
      novaLog(() => '[NOVA.route] creds not ready → native');
      return const LinkNative();
    }

    final storedRoute = await ledger.route();
    novaLog(() => '[NOVA.route] stored=$storedRoute fromRetry=$fromRetry');

    switch (storedRoute) {
      case LinkRoute.web:
        return _returningWeb(fromRetry: fromRetry);
      case LinkRoute.native:
        return _returningNative();
      case LinkRoute.fresh:
        return _firstDecision(fromRetry: fromRetry);
    }
  }

  // ------------------------------------------------------ fresh install

  Future<LinkDecision> _firstDecision({bool fromRetry = false}) async {
    // 1. Radio + real reachability before touching AppsFlyer.
    if (!await probe.hasRadio()) {
      novaLog(() => '[NOVA.route] no radio → offline (fresh stays fresh)');
      return const LinkOffline();
    }
    // Skip the DNS gate when the caller has already verified connectivity
    // — iOS's DNS cache is reproducibly stale for a second or two after a
    // wifi hand-off and would false-fail here.
    if (!fromRetry && !await probe.dnsProbe()) {
      novaLog(() => '[NOVA.route] no dns → offline (fresh stays fresh)');
      return const LinkOffline();
    }

    // 2. Attribution SDK must be started (ATT + initSdk) BEFORE the
    //    conversion wait begins; the push token warms up in parallel.
    final tokenFuture = push.obtainToken();
    await attrib.start();

    // 3. Bound the token wait tightly — a null token just omits the two
    //    push fields, it must NOT eat into the attribution window.
    final token = await tokenFuture.timeout(
      const Duration(seconds: 4),
      onTimeout: () => null,
    );

    // 4. Build the flat body. buildPayload blocks up to
    //    `awaitSignalsInstall` for the AppsFlyer conversion callback,
    //    then assembles the payload.
    final body = await attrib.buildPayload(
      apnsFcmToken: token,
      locale: _locale(),
      afIdOverride: null,
    );

    // 5. Dispatch, with a bounded retry loop that ONLY protects against
    //    transport failure right after a wifi hand-off. The offline
    //    screen auto-navigates the moment `onConnectivityChanged` fires
    //    and iOS raises that event before DHCP + DNS + default route
    //    are fully up (~1–2 s on wifi, up to ~4 s on cellular). Without
    //    retries, the first POST hits ENOTFOUND / connect-timeout,
    //    dispatch returns denied with `message == null`, and the retry
    //    path below bounces the user right back to the offline screen
    //    even though the network is up. A short backoff sequence gives
    //    the stack time to settle without adding a visible loading
    //    phase on the happy path.
    final maxAttempts = fromRetry ? 4 : 1;
    const backoffs = <Duration>[
      Duration(milliseconds: 700),
      Duration(milliseconds: 1200),
      Duration(milliseconds: 1600),
    ];
    var reply = await courier.send(body);
    var attempt = 1;
    while (attempt < maxAttempts &&
        !reply.granted &&
        reply.message == null) {
      final wait = backoffs[(attempt - 1).clamp(0, backoffs.length - 1)];
      novaLog(() =>
          '[NOVA.route] POST transport-failed, retry ${attempt + 1}/$maxAttempts in ${wait.inMilliseconds}ms');
      await Future<void>.delayed(wait);
      reply = await courier.send(body);
      attempt += 1;
    }

    if (reply.granted && reply.destination != null) {
      await ledger.writeCachedUrl(reply.destination!, expiresAt: reply.expiresAt);
      await ledger.commitRoute(LinkRoute.web);
      return LinkWeb(reply.destination!);
    }

    // Transport-level failure (no HTTP status → no `message` from server).
    // On the retry path we must NOT commit any route and must NOT drop
    // the user into the native app — bounce back to the offline screen
    // so the user's next Retry tap can try again once the network
    // truly settles.
    if (fromRetry && reply.message == null) {
      novaLog(() =>
          '[NOVA.route] retry POST transport-failed after $attempt attempts → offline');
      return const LinkOffline();
    }

    // A "no data" answer only commits us to native when the POST
    // ACTUALLY carried attribution. If AppsFlyer was slow and the body
    // had no attribution keys (only base identity fields), keep the
    // route `fresh` so the next launch retries — by then AppsFlyer
    // serves the conversion from cache instantly and the POST carries
    // full attribution. This stops a slow first launch from
    // permanently trapping a non-organic user on the native app (the
    // exact symptom: 404 "No data" arriving before the conversion
    // callback).
    if (reply.message != null && _bodyHasAttribution(body)) {
      await ledger.commitRoute(LinkRoute.native);
      await ledger.setOrganicCommitted(true);
    }
    return const LinkNative();
  }

  // -------------------------------------------------- returning web install

  Future<LinkDecision> _returningWeb({bool fromRetry = false}) async {
    if (!await probe.hasRadio()) return const LinkOffline();

    // Race a fresh POST with the cached URL. If we already have one that
    // has not expired, hand it back immediately and let a background
    // refresh update it for next launch.
    final cached = await ledger.cachedUrl();
    if (cached != null) {
      unawaited(_backgroundRefresh());
      return LinkWeb(cached);
    }

    // No cached URL — do a live decision.
    return _firstDecision(fromRetry: fromRetry);
  }

  Future<void> _backgroundRefresh() async {
    try {
      unawaited(attrib.start());
      final token = push.cachedToken ??
          await push.obtainToken().timeout(
                LinkConfig.awaitSignalsInstall,
                onTimeout: () => null,
              );
      final body = await attrib.buildPayload(
        apnsFcmToken: token,
        locale: _locale(),
        afIdOverride: null,
      );
      final reply = await courier.send(body);
      if (reply.granted && reply.destination != null) {
        await ledger.writeCachedUrl(reply.destination!,
            expiresAt: reply.expiresAt);
      }
    } catch (e) {
      novaLog(() => '[NOVA.route] bg refresh failed: $e');
    }
  }

  // ------------------------------------------------ returning native install

  Future<LinkDecision> _returningNative() async {
    // Opportunistic re-conversion, never blocking. The organic user
    // keeps the native path unless a successful reply flips them.
    final last = ledger.lastOrganicCheck;
    final due = last == null ||
        DateTime.now().difference(last) >=
            LinkConfig.organicRecheckInterval;
    if (due && await probe.hasRadio()) {
      unawaited(_organicRecheck());
    }
    return const LinkNative();
  }

  Future<void> _organicRecheck() async {
    try {
      await ledger.stampOrganicCheck();
      unawaited(attrib.start());
      final token = push.cachedToken;
      final body = await attrib.buildPayload(
        apnsFcmToken: token,
        locale: _locale(),
        afIdOverride: null,
      );
      final reply = await courier.send(body);
      if (reply.granted && reply.destination != null) {
        await ledger.writeCachedUrl(reply.destination!,
            expiresAt: reply.expiresAt);
        await ledger.commitRoute(LinkRoute.web);
        novaLog(() => '[NOVA.route] recheck flipped native → web');
      }
    } catch (_) {}
  }

  /// True when the composed body carries AppsFlyer attribution — i.e.
  /// any key beyond the base identity fields that are always present.
  /// Used to tell a genuine "no campaign" answer (attribution present →
  /// commit native) apart from a slow-conversion miss (attribution
  /// absent → stay fresh, retry).
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
