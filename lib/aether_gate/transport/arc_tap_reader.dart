import 'package:shared_preferences/shared_preferences.dart';

import '../config/relay_config.dart';
import 'agate_log.dart';

/// Bridges the URL captured by `SceneDelegate.swift` on a cold-start push
/// tap. The Swift side writes to `UserDefaults` under the key
/// `"flutter." + AetherRelayConfig.vaultLaunchKey`, which Flutter's
/// shared_preferences plugin exposes as `vaultLaunchKey` on iOS.
///
/// [consume] reads + clears the key so a stale URL never fires twice.
class ArcTapReader {
  ArcTapReader._();

  static Future<String?> consume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = AetherRelayConfig.vaultLaunchKey;
      final v = prefs.getString(key);
      if (v == null || v.isEmpty) return null;
      await prefs.remove(key);
      agateLog(() => '[AGATE.arc] consumed cold-start url');
      return v;
    } catch (e) {
      agateLog(() => '[AGATE.arc] consume error: $e');
      return null;
    }
  }
}
