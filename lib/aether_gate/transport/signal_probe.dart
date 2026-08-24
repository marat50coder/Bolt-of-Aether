import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'agate_log.dart';

/// Two-step reachability check: the OS-level "have I got a radio" flag first,
/// then a real DNS probe. Callers MUST bail on connectivity `none` BEFORE
/// probing (`gray_flow_lessons.md` §2 — a DNS probe hangs for seconds while
/// offline and lets the WebView paint its own error page).
class SignalProbe {
  SignalProbe(this._connectivity);

  final Connectivity _connectivity;

  /// True when at least one radio (wifi / mobile / ethernet / vpn) is up.
  /// Does NOT prove packets travel — pair with [dnsProbe] for that.
  Future<bool> hasRadio() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (e) {
      agateLog(() => '[AGATE.probe] radio check failed: $e');
      return false;
    }
  }

  /// Simple DNS probe. The resolve targets are rotated per project (never the
  /// template's `cloudflare.com`) — see `gray_part_mixing_review.mdc` §1.
  ///
  /// One retry loop with a short delay between passes. Right after a wifi
  /// handoff iOS's DNS resolver can take up to ~1 s to settle even though
  /// `Connectivity.checkConnectivity()` already reports the interface up.
  /// Without the retry the SilenceScreen "Try Again" tap immediately after
  /// wifi returns bounces back to SilenceScreen because the first-pass
  /// lookup for `gstatic.com` fails on a stale resolver, so the router
  /// returns `GateOffline` even though the network is fine.
  Future<bool> dnsProbe({
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    const targets = <String>['gstatic.com', 'wikipedia.org', 'apple.com'];
    for (var attempt = 0; attempt < 2; attempt++) {
      for (var i = 0; i < targets.length; i++) {
        try {
          final hits = await InternetAddress.lookup(targets[i]).timeout(timeout);
          if (hits.isNotEmpty && hits.first.rawAddress.isNotEmpty) return true;
        } catch (_) {
          // fall through to the next target
        }
      }
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    return false;
  }

  /// One-shot reachability check — a single DNS lookup with a tight timeout
  /// and NO retry. Meant for the boot fast-path: the app must decide whether
  /// to show the loading art or the SilenceScreen "within a frame" of launch
  /// instead of waiting for Firebase init + AppsFlyer + POST + the router's
  /// own dnsProbe (~14 s worst case) before finally deciding "offline".
  ///
  /// When the device is truly offline `InternetAddress.lookup` throws a
  /// `SocketException` almost instantly (<200 ms), so this method returns
  /// false fast enough for the SilenceScreen to feel instant. When the
  /// resolver is merely slow (real network coming up) the timeout caps the
  /// wait so we do not stall the splash either.
  Future<bool> quickReach({
    Duration timeout = const Duration(milliseconds: 800),
  }) async {
    if (!await hasRadio()) return false;
    try {
      final hits =
          await InternetAddress.lookup('gstatic.com').timeout(timeout);
      return hits.isNotEmpty && hits.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Stream<bool> onChange() {
    return _connectivity.onConnectivityChanged
        .map((flat) => flat.any((r) => r != ConnectivityResult.none));
  }
}
