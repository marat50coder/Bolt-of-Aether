import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/link_config.dart';
import '../models/link_mode.dart';

/// Persistent state for the remote-content pipeline: the last route
/// decision, the cached partner URL with its expiry, the push-invite
/// cooldown, and a handful of state flags. `SharedPreferences` handles
/// the small primitives (fast, wiped only on uninstall); the cached URL
/// lives in the OS keychain via `FlutterSecureStorage` for the tiny
/// additional survival benefit some iOS reinstall scenarios provide.
class LinkLedger {
  LinkLedger._(this._prefs, this._secure);

  static Future<LinkLedger> open() async {
    final prefs = await SharedPreferences.getInstance();
    return LinkLedger._(
      prefs,
      const FlutterSecureStorage(
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      ),
    );
  }

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  String get _p => LinkConfig.ledgerPrefix;

  // -------------------------------------------------------------- route

  Future<LinkRoute> route() async {
    final v = _prefs.getString('${_p}route');
    return switch (v) {
      'web' => LinkRoute.web,
      'native' => LinkRoute.native,
      _ => LinkRoute.fresh,
    };
  }

  Future<void> commitRoute(LinkRoute route) async {
    await _prefs.setString('${_p}route', route.name);
  }

  // ------------------------------------------------------------ cached URL

  Future<String?> cachedUrl() async {
    final blob = await _secure.read(key: '${_p}cached');
    if (blob == null) return null;
    try {
      final obj = jsonDecode(blob) as Map<String, dynamic>;
      final url = obj['url'] as String?;
      final expires = obj['expires'];
      if (url == null || url.isEmpty) return null;
      if (expires is int && expires > 0) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (now > expires) {
          await clearCachedUrl();
          return null;
        }
      }
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeCachedUrl(String url, {int? expiresAt}) async {
    final defaultExpiry = DateTime.now()
            .add(const Duration(days: LinkConfig.cachedUrlExpiryDays))
            .millisecondsSinceEpoch ~/
        1000;
    final payload = jsonEncode({
      'url': url,
      'expires': expiresAt ?? defaultExpiry,
    });
    await _secure.write(key: '${_p}cached', value: payload);
  }

  Future<void> clearCachedUrl() async {
    await _secure.delete(key: '${_p}cached');
  }

  // ------------------------------------------------------- push cooldown

  DateTime? get inviteCooldownUntil {
    final ms = _prefs.getInt('${_p}invite_snooze_until');
    if (ms == null || ms == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  bool get inviteSnoozed {
    final until = inviteCooldownUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  Future<void> writeInviteCooldown(DateTime until) async {
    await _prefs.setInt('${_p}invite_snooze_until', until.millisecondsSinceEpoch);
  }

  bool get pushGranted => _prefs.getBool('${_p}push_granted') ?? false;
  Future<void> setPushGranted(bool v) =>
      _prefs.setBool('${_p}push_granted', v);

  bool get pushBlockedByOs => _prefs.getBool('${_p}push_os_denied') ?? false;
  Future<void> setPushBlockedByOs(bool v) =>
      _prefs.setBool('${_p}push_os_denied', v);

  // ----------------------------------------------------------- misc flags

  bool get organicCommitted => _prefs.getBool('${_p}organic_committed') ?? false;
  Future<void> setOrganicCommitted(bool v) =>
      _prefs.setBool('${_p}organic_committed', v);

  DateTime? get lastOrganicCheck {
    final ms = _prefs.getInt('${_p}organic_last_check');
    if (ms == null || ms == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> stampOrganicCheck() =>
      _prefs.setInt('${_p}organic_last_check', DateTime.now().millisecondsSinceEpoch);

  bool get attGranted => _prefs.getBool('${_p}att_granted') ?? false;
  Future<void> setAttGranted(bool v) =>
      _prefs.setBool('${_p}att_granted', v);

  // ------------------------------------------------------ pending push URL
  // A push tap that arrives before the WebView is mounted (or between
  // mounts) is buffered here. Persistent so that a background→foreground
  // tap followed by an OS relaunch doesn't lose the URL. [consumePushUrl]
  // is single-shot: read + clear so the same URL never navigates twice.

  Future<void> writePushUrl(String url) async {
    if (url.isEmpty) return;
    await _prefs.setString('${_p}push_url', url);
  }

  Future<String?> consumePushUrl() async {
    final v = _prefs.getString('${_p}push_url');
    if (v == null || v.isEmpty) return null;
    await _prefs.remove('${_p}push_url');
    return v;
  }
}
