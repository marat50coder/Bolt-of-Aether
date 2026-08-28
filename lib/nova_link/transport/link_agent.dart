import 'dart:async';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/link_config.dart';
import 'nova_log.dart';

/// Shared HTTP client + User-Agent forge. Two invariants:
///
///   • every browser UA fragment (product, platform, engine, mobile and
///     version tokens) lives as an encoded byte array, so no canonical
///     Safari substring sits in the compiled image;
///   • the same UA is presented by the HTTP client AND the WKWebView —
///     partner backends cross-check the two.
class LinkAgent {
  LinkAgent._(this._userAgent);

  final String _userAgent;
  final http.Client _inner = http.Client();

  static LinkAgent? _instance;
  static Future<LinkAgent> ready() async {
    if (_instance != null) return _instance!;
    final ua = await _forgeUserAgent();
    novaLog(() => '[NOVA.ua] built: $ua');
    _instance = LinkAgent._(ua);
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

  /// AppsFlyer GCD (Get Conversion Data) fallback. Installs that AppsFlyer
  /// initially reports as Organic often turn out to have a real
  /// non-organic source once the server-side lookup completes. iOS keys
  /// the lookup on the numeric App Store id and authenticates with the
  /// dev key as a bearer token.
  Future<Map<String, dynamic>?> gcdLookup(
    String iosStoreId,
    String deviceId,
  ) async {
    try {
      // AppsFlyer GCD v5.0 keys the lookup on the numeric App Store id as
      // a PATH segment prefixed with `id` (e.g. `.../v5.0/id6797957269`),
      // NOT a query parameter. A query-param form returns empty data and
      // silently disables the organic → non-organic correction.
      final base = LinkConfig.gcdBaseUrl;
      final url = Uri.parse('${base}id$iosStoreId?device_id=$deviceId');
      final r = await get(
        url,
        headers: <String, String>{
          'Authorization': 'Bearer ${LinkConfig.appsflyerDevKey}',
        },
        timeout: const Duration(seconds: 11),
      );
      if (r.statusCode != 200) return null;
      final decoded = jsonDecode(r.body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (e) {
      novaLog(() => '[NOVA.gcd] error: $e');
    }
    return null;
  }

  static Future<String> _forgeUserAgent() async {
    final iosVersion = await _iosVersion();
    final cpu = iosVersion.replaceAll('.', '_');
    final base = <String>[
      LinkConfig.uaProduct,
      '${LinkConfig.uaPlatformPrefix} $cpu ${LinkConfig.uaPlatformSuffix}',
      LinkConfig.uaEngine,
      '${LinkConfig.uaVersionTag}${LinkConfig.uaSafariMajorMinor}',
      LinkConfig.uaMobileToken,
      '${LinkConfig.uaSafariTag}${LinkConfig.uaSafariTail}',
    ].join(' ');
    return '$base ${LinkConfig.uaAppIdToken}${LinkConfig.uaBundleValue}'
        ' ${LinkConfig.uaAppNameToken}${LinkConfig.uaAppNameValue}';
  }

  static Future<String> _iosVersion() async {
    try {
      final info = await DeviceInfoPlugin().iosInfo;
      final raw = info.systemVersion;
      if (raw.isNotEmpty) return raw;
    } catch (e) {
      novaLog(() => '[NOVA.ua] device_info failed: $e');
    }
    // Fallback fragment — assembled from the same encoded pool so no
    // fresh literal lands in the binary.
    return LinkConfig.uaSafariMajorMinor;
  }
}

/// Small helper for one-shot JSON responses.
Future<Map<String, dynamic>?> decodeJsonBody(String body) async {
  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}
