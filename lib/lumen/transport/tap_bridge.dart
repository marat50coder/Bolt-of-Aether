import 'package:shared_preferences/shared_preferences.dart';

import '../config/link_config.dart';
import 'nova_log.dart';

/// Bridges the URL captured by `SceneDelegate.swift` when the user taps a
/// notification while the app is terminated. The Swift side writes to
/// `UserDefaults` under `"flutter." + LinkConfig.coldLinkKey`, which the
/// `shared_preferences` plugin exposes here as [LinkConfig.coldLinkKey].
///
/// [consume] reads AND clears the key so a stale URL never fires twice.
class TapBridge {
  TapBridge._();

  static Future<String?> consume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = LinkConfig.coldLinkKey;
      final value = prefs.getString(key);
      if (value == null || value.isEmpty) return null;
      await prefs.remove(key);
      novaLog(() => '[NOVA.tap] consumed cold-start url');
      return value;
    } catch (e) {
      novaLog(() => '[NOVA.tap] consume error: $e');
      return null;
    }
  }
}
