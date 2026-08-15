import 'dart:async';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/widgets.dart';

import '../config/relay_config.dart';
import 'agate_log.dart';
import 'bolt_agent.dart';
import 'relay_vault.dart';

/// AppsFlyer wrapper. Consent is asked BEFORE the SDK starts (so the ATT
/// prompt is always the first modal the user sees on this launch), and the
/// consent future is memoized separately from the SDK-start future — see
/// `gray_flow_lessons.md` §26.
class StormAttrib {
  StormAttrib({required RelayVault vault}) : _vault = vault {
    _sdk = AppsflyerSdk(AppsFlyerOptions(
      afDevKey: AetherRelayConfig.appsflyerDevKey,
      appId: AetherRelayConfig.iosStoreId,
      showDebug: false,
      // Keep this SMALL. ATT is resolved by `requestConsentOnce()` before the
      // SDK starts, so a large value here only risks delaying the conversion
      // callback (the reference uses 4). A long wait makes the first-launch
      // POST fire before attribution and misroutes non-organic users.
      timeToWaitForATTUserAuthorization: 6,
      manualStart: true,
    ));
  }

  final RelayVault _vault;
  late final AppsflyerSdk _sdk;

  final Completer<Map<String, dynamic>> _conversion =
      Completer<Map<String, dynamic>>();
  final Completer<Map<String, dynamic>?> _deepLink =
      Completer<Map<String, dynamic>?>();

  Future<void>? _startFuture;
  Future<bool>? _consentFuture;

  /// Ask ATT once per process, on the first `resumed` frame. Never re-asks.
  Future<bool> requestConsentOnce() {
    return _consentFuture ??= _askConsent();
  }

  Future<bool> _askConsent() async {
    await _waitFrontmost();
    await Future.delayed(AetherRelayConfig.attPromptDelay);
    try {
      var status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        status = await AppTrackingTransparency
            .requestTrackingAuthorization();
      }
      final granted = status == TrackingStatus.authorized;
      await _vault.setAttGranted(granted);
      agateLog(() => '[AGATE.att] status=$status granted=$granted');
      return granted;
    } catch (e) {
      agateLog(() => '[AGATE.att] error: $e');
      return false;
    }
  }

  static Future<void> _waitFrontmost() async {
    const attempts = 20;
    for (var i = 0; i < attempts; i++) {
      final state = WidgetsBinding.instance.lifecycleState;
      if (state == null || state == AppLifecycleState.resumed) return;
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  /// Starts the SDK exactly once per process. Waits for consent first (so
  /// the SDK's own IDFA-fetch respects the user's answer).
  Future<void> start() {
    return _startFuture ??= _start();
  }

  Future<void> _start() async {
    await requestConsentOnce();
    try {
      _sdk.onInstallConversionData((data) {
        unawaited(_acceptConversion(data));
      });
      _sdk.onAppOpenAttribution((data) {
        agateLog(() => '[AGATE.af] deep-link: ${data.toString()}');
        if (!_deepLink.isCompleted) _deepLink.complete(_flatten(data));
      });
      await _sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
      _sdk.startSDK(
        onSuccess: () => agateLog(() => '[AGATE.af] start success'),
        onError: (int code, String msg) =>
            agateLog(() => '[AGATE.af] start error $code $msg'),
      );
    } catch (e) {
      agateLog(() => '[AGATE.af] start threw: $e');
    }
  }

  /// Normalises the raw conversion callback before completing `_conversion`.
  ///   • A `{status:failure,...}` map (AppsFlyer can't reach its servers —
  ///     e.g. an ad-blocking VPN blackholes *.appsflyersdk.com) must NOT be
  ///     merged into the config body, so we complete with an empty map.
  ///   • `af_status == Organic` is often a first-report that a server-side GCD
  ///     lookup later corrects to a real non-organic source. Wait the rotated
  ///     recheck window, try GCD, and prefer its result.
  /// Mirrors the reference `FlightAttribution._acceptInstall`.
  Future<void> _acceptConversion(dynamic raw) async {
    Map<String, dynamic> result;
    try {
      final received = _flatten(raw);
      final status = received['status']?.toString().toLowerCase();
      final failed = status == 'failure' ||
          (received['af_status'] == null && received.containsKey('status'));
      agateLog(() => '[AGATE.af] conv status=$status '
          'af_status=${received['af_status']} keys=${received.keys.toList()}');
      if (failed) {
        result = <String, dynamic>{};
      } else if (received['af_status'] == 'Organic') {
        await Future.delayed(
          Duration(seconds: AetherRelayConfig.organicRecheckSeconds),
        );
        result = await _fetchGcd() ?? received;
      } else {
        result = received;
      }
    } catch (e) {
      agateLog(() => '[AGATE.af] conv parse error: $e');
      result = <String, dynamic>{};
    }
    if (!_conversion.isCompleted) _conversion.complete(result);
  }

  Future<Map<String, dynamic>?> _fetchGcd() async {
    final uid = await afId();
    if (uid == null || uid.isEmpty) return null;
    final agent = await BoltAgent.ready();
    return agent.gcdLookup(AetherRelayConfig.iosStoreId, uid);
  }

  /// Times out gracefully — a missing conversion callback must never hang
  /// the boot pipeline (`gray_flow_lessons.md` §5).
  Future<Map<String, dynamic>?> awaitConversion({
    required Duration timeout,
  }) async {
    try {
      return await _conversion.future.timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> awaitDeepLink({
    required Duration timeout,
  }) async {
    try {
      return await _deepLink.future.timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  Future<String?> afId() async {
    try {
      final id = await _sdk.getAppsFlyerUID();
      return id;
    } catch (_) {
      return null;
    }
  }

  /// Flattens a nested `{data: {...}, ...}` shape from the SDK callback into
  /// a plain string→dynamic map — the config body is a flat object.
  Map<String, dynamic> _flatten(dynamic raw) {
    if (raw is Map) {
      final out = <String, dynamic>{};
      raw.forEach((key, value) {
        if (value is Map) {
          value.forEach((k2, v2) {
            out['$k2'] = v2;
          });
        } else {
          out['$key'] = value;
        }
      });
      return out;
    }
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> buildPayload({
    required String? apnsFcmToken,
    required String locale,
    required String? afIdOverride,
  }) async {
    final conv = await awaitConversion(
      timeout: AetherRelayConfig.awaitSignalsInstall,
    );
    final deep = await awaitDeepLink(
      timeout: const Duration(seconds: 2),
    );
    final af = afIdOverride ?? await afId();
    final body = <String, dynamic>{
      if (conv != null) ...conv,
      if (deep != null) ...deep,
      if (af != null && af.isNotEmpty) 'af_id': af,
      'bundle_id': AetherRelayConfig.uaBundleValue,
      'os': 'iOS',
      'store_id': AetherRelayConfig.platformStoreId,
      'locale': locale,
    };
    if (apnsFcmToken != null && apnsFcmToken.isNotEmpty) {
      body['push_token'] = apnsFcmToken;
      body['firebase_project_id'] = AetherRelayConfig.firebaseProjectId;
    }
    return body;
  }
}
