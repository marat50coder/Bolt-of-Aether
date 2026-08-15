import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/relay_config.dart';
import '../models/gate_mode.dart';

/// Persistent gray-flow state: last route decision, saved partner URL with
/// expiry, push-invite cooldown, push status flags. SharedPreferences for
/// small primitives (fast, wiped only on uninstall), SecureStorage for the
/// saved URL (keychain-backed, survives app reinstalls on some iOS builds
/// which is exactly what we want for a returning-user shortcut).
class RelayVault {
  RelayVault._(this._prefs, this._secure);

  static Future<RelayVault> open() async {
    final prefs = await SharedPreferences.getInstance();
    return RelayVault._(
      prefs,
      const FlutterSecureStorage(
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      ),
    );
  }

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  String get _p => AetherRelayConfig.vaultPrefix;

  // ---------------------------------------------------------------- route

  Future<GateRoute> route() async {
    final v = _prefs.getString('${_p}route');
    return switch (v) {
      'web' => GateRoute.web,
      'native' => GateRoute.native,
      _ => GateRoute.fresh,
    };
  }

  Future<void> commitRoute(GateRoute route) async {
    await _prefs.setString('${_p}route', route.name);
  }

  // ------------------------------------------------------------ saved URL

  Future<String?> savedUrl() async {
    final blob = await _secure.read(key: '${_p}saved');
    if (blob == null) return null;
    try {
      final obj = jsonDecode(blob) as Map<String, dynamic>;
      final url = obj['url'] as String?;
      final expires = obj['expires'];
      if (url == null || url.isEmpty) return null;
      if (expires is int && expires > 0) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (now > expires) {
          await clearSavedUrl();
          return null;
        }
      }
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeSavedUrl(String url, {int? expiresAt}) async {
    final defaultExpiry = DateTime.now()
            .add(const Duration(days: AetherRelayConfig.savedUrlExpiryDays))
            .millisecondsSinceEpoch ~/
        1000;
    final payload = jsonEncode({
      'url': url,
      'expires': expiresAt ?? defaultExpiry,
    });
    await _secure.write(key: '${_p}saved', value: payload);
  }

  Future<void> clearSavedUrl() async {
    await _secure.delete(key: '${_p}saved');
  }

  // --------------------------------------------------------- push cooldown

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

  // --------------------------------------------------------- misc flags

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

  // ------------------------------------------------------- pending push URL
  // Buffered destination for a push tap that arrived before the WebView was
  // mounted (or between mounts). Persistent so a background→foreground tap
  // followed by an OS-triggered relaunch does not lose the URL.
  // `consumePushUrl` is single-shot: read + clear so the same URL never
  // navigates twice.

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
