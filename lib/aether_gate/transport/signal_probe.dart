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
  Future<bool> dnsProbe({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    const targets = <String>['gstatic.com', 'wikipedia.org'];
    for (var i = 0; i < targets.length; i++) {
      try {
        final hits = await InternetAddress.lookup(targets[i]).timeout(timeout);
        if (hits.isNotEmpty && hits.first.rawAddress.isNotEmpty) return true;
      } catch (_) {
        // fall through to the next target
      }
    }
    return false;
  }

  Stream<bool> onChange() {
    return _connectivity.onConnectivityChanged
        .map((flat) => flat.any((r) => r != ConnectivityResult.none));
  }
}
