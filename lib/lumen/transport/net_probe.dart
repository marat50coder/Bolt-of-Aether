import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'nova_log.dart';

/// Two-step reachability check. `hasRadio` reads the OS-level flag first,
/// then `dnsProbe` performs a real name-resolution against a rotating set
/// of anchor hosts. Callers MUST bail on `hasRadio == false` before
/// probing DNS — a DNS lookup while genuinely offline hangs for seconds
/// and lets a WKWebView paint its own error page.
class NetProbe {
  NetProbe(this._connectivity);

  final Connectivity _connectivity;

  /// True when at least one radio (wifi / mobile / ethernet / vpn) is up.
  /// Does NOT prove packets travel — pair with [dnsProbe] for that.
  Future<bool> hasRadio() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (e) {
      novaLog(() => '[NOVA.probe] radio check failed: $e');
      return false;
    }
  }

  /// Simple DNS probe against three well-known anchors.
  ///
  /// One retry loop with a short delay between passes. Immediately after
  /// a wifi hand-off iOS's DNS resolver can take up to ~1 s to settle
  /// even though `Connectivity.checkConnectivity()` already reports the
  /// interface up. Without the retry the "Try Again" tap after a wifi
  /// recovery bounces straight back to the offline screen because the
  /// first-pass lookup fails on a stale resolver.
  Future<bool> dnsProbe({
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    const anchors = <String>['gstatic.com', 'wikipedia.org', 'apple.com'];
    for (var attempt = 0; attempt < 2; attempt++) {
      for (var i = 0; i < anchors.length; i++) {
        try {
          final hits = await InternetAddress.lookup(anchors[i]).timeout(timeout);
          if (hits.isNotEmpty && hits.first.rawAddress.isNotEmpty) return true;
        } catch (_) {
          // fall through to the next anchor
        }
      }
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    return false;
  }

  /// Single-shot reachability check — one DNS lookup, tight timeout, no
  /// retry. Meant for the boot fast-path: the app must decide whether
  /// to show the loading art or the offline screen within a frame of
  /// launch, instead of waiting on Firebase + AppsFlyer + config POST +
  /// the router's own dnsProbe (roughly 14 s worst case) before finally
  /// deciding "offline".
  ///
  /// When the device is truly offline `InternetAddress.lookup` throws a
  /// `SocketException` almost instantly (<200 ms), so this returns false
  /// fast enough for the offline screen to feel immediate. When the
  /// resolver is merely slow (real network coming up) the timeout caps
  /// the wait so the splash doesn't stall either.
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
