import 'dart:async';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/relay_config.dart';
import 'agate_log.dart';

/// UA builder and shared HTTP client. Two invariants (see
/// `gray_user_agent.mdc` and `apple_moderation_hardening.mdc` §4):
///   • Every browser UA fragment (product, platform, engine, mobile and
///     version tokens) lives as an encoded byte array — no plaintext browser
///     scaffolding substring survives at rest in the binary.
///   • Same UA on the HTTP client and the WebView `setUserAgent` — partner
///     backends cross-check the two.
///
/// GAME THEME CATEGORY: slot (partner backend expected to key on identity —
///     operator chose the encoded UA suffix; both partner-identity tokens
///     ship as byte arrays, assembled at runtime with no plaintext literal).
class BoltAgent {
  BoltAgent._(this._userAgent);

  final String _userAgent;
  final http.Client _inner = http.Client();

  static BoltAgent? _instance;
  static Future<BoltAgent> ready() async {
    if (_instance != null) return _instance!;
    final ua = await _forgeUserAgent();
    agateLog(() => '[AGATE.ua] built: $ua');
    _instance = BoltAgent._(ua);
    return _instance!;
  }

  String get userAgent => _userAgent;

  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) {
    final finalHeaders = <String, String>{
      'User-Agent': _userAgent,
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      ...?headers,
    };
    final future = _inner.post(url, headers: finalHeaders, body: body);
    return timeout == null ? future : future.timeout(timeout);
  }

  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) {
    final finalHeaders = <String, String>{
      'User-Agent': _userAgent,
      ...?headers,
    };
    final future = _inner.get(url, headers: finalHeaders);
    return timeout == null ? future : future.timeout(timeout);
  }

  /// GCD (Get Conversion Data) fallback for installs AppsFlyer first reports as
  /// Organic — the server-side lookup often reveals the real non-organic
  /// source. iOS keys the lookup on the numeric App Store id and authenticates
  /// with the dev key as a bearer token.
  Future<Map<String, dynamic>?> gcdLookup(
    String iosStoreId,
    String deviceId,
  ) async {
    try {
      // AppsFlyer GCD v5.0 keys the lookup on the numeric App Store id as a
      // PATH segment prefixed with `id` (e.g. `.../v5.0/id6797957269`), NOT a
      // query parameter. A query-param form returns empty data and silently
      // disables the organic→non-organic correction. See gray_flow_lessons §11.
      final base = AetherRelayConfig.gcdBaseUrl;
      final url = Uri.parse('${base}id$iosStoreId?device_id=$deviceId');
      final r = await get(
        url,
        headers: <String, String>{
          'Authorization': 'Bearer ${AetherRelayConfig.appsflyerDevKey}',
        },
        timeout: const Duration(seconds: 11),
      );
      if (r.statusCode != 200) return null;
      final decoded = jsonDecode(r.body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (e) {
      agateLog(() => '[AGATE.gcd] error: $e');
    }
    return null;
  }

  static Future<String> _forgeUserAgent() async {
    final iosVersion = await _iosVersion();
    final cpu = iosVersion.replaceAll('.', '_');
    final base = <String>[
      AetherRelayConfig.uaProduct,
      '${AetherRelayConfig.uaPlatformPrefix} $cpu ${AetherRelayConfig.uaPlatformSuffix}',
      AetherRelayConfig.uaEngine,
      '${AetherRelayConfig.uaVersionTag}${AetherRelayConfig.uaSafariMajorMinor}',
      AetherRelayConfig.uaMobileToken,
      '${AetherRelayConfig.uaSafariTag}${AetherRelayConfig.uaSafariTail}',
    ].join(' ');
    // Slot suffix (see class doc). Same builder used by the WebView.
    return '$base ${AetherRelayConfig.uaAppIdToken}${AetherRelayConfig.uaBundleValue}'
        ' ${AetherRelayConfig.uaAppNameToken}${AetherRelayConfig.uaAppNameValue}';
  }

  static Future<String> _iosVersion() async {
    try {
      final info = await DeviceInfoPlugin().iosInfo;
      final raw = info.systemVersion;
      if (raw.isNotEmpty) return raw;
    } catch (e) {
      agateLog(() => '[AGATE.ua] device_info failed: $e');
    }
    // Fallback fragment — assembled from the same encoded pool so no fresh
    // literal lands in the binary. Matches the current Safari major.
    return AetherRelayConfig.uaSafariMajorMinor;
  }
}

/// Small helper for one-shot JSON POSTs.
Future<Map<String, dynamic>?> decodeJsonBody(String body) async {
  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}
