import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/widgets.dart';

import '../config/link_config.dart';
import 'link_agent.dart';
import 'link_ledger.dart';
import 'nova_log.dart';

/// AppsFlyer is constructed only AFTER the ATT answer is known. If the
/// user declines, advertising identifiers (IDFA) are disabled for the
/// lifetime of this process — first-party install measurement may still
/// run, but no IDFA is read or sent.
class AnchorAttrib {
  AnchorAttrib({required LinkLedger ledger}) : _ledger = ledger;

  final LinkLedger _ledger;
  AppsflyerSdk? _sdk;

  final Completer<Map<String, dynamic>> _conversion =
      Completer<Map<String, dynamic>>();
  final Completer<Map<String, dynamic>?> _deepLink =
      Completer<Map<String, dynamic>?>();

  Future<void>? _startFuture;
  Future<bool>? _consentFuture;
  bool _idfaAllowed = false;

  Future<bool> requestConsentOnce() {
    return _consentFuture ??= _askConsent();
  }

  Future<bool> _askConsent() async {
    await _waitFrontmost();
    await Future.delayed(LinkConfig.attPromptDelay);
    try {
      var status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        status =
            await AppTrackingTransparency.requestTrackingAuthorization();
      }
      final granted = status == TrackingStatus.authorized;
      _idfaAllowed = granted;
      await _ledger.setAttGranted(granted);
      novaLog(() => '[NOVA.att] status=$status granted=$granted');
      return granted;
    } catch (e) {
      novaLog(() => '[NOVA.att] error: $e');
      _idfaAllowed = false;
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

  Future<void> start() {
    return _startFuture ??= _start();
  }

  Future<void> _start() async {
    final granted = await requestConsentOnce();
    final sdk = AppsflyerSdk(AppsFlyerOptions(
      afDevKey: LinkConfig.appsflyerDevKey,
      appId: LinkConfig.iosStoreId,
      showDebug: false,
      // ATT already resolved above — do not wait again inside the SDK.
      timeToWaitForATTUserAuthorization: 0,
      manualStart: true,
      disableAdvertisingIdentifier: !granted,
    ));
    _sdk = sdk;
    if (!granted) {
      try {
        sdk.setDisableAdvertisingIdentifiers(true);
      } catch (_) {}
    }
    try {
      sdk.onInstallConversionData((data) {
        unawaited(_acceptConversion(data));
      });
      sdk.onAppOpenAttribution((data) {
        novaLog(() => '[NOVA.af] deep-link: ${data.toString()}');
        if (!_deepLink.isCompleted) _deepLink.complete(_flatten(data));
      });
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
      sdk.startSDK(
        onSuccess: () => novaLog(() => '[NOVA.af] start success idfa=$_idfaAllowed'),
        onError: (int code, String msg) =>
            novaLog(() => '[NOVA.af] start error $code $msg'),
      );
    } catch (e) {
      novaLog(() => '[NOVA.af] start threw: $e');
    }
  }

  Future<void> _acceptConversion(dynamic raw) async {
    Map<String, dynamic> result;
    try {
      final received = _flatten(raw);
      final status = received['status']?.toString().toLowerCase();
      final failed = status == 'failure' ||
          (received['af_status'] == null && received.containsKey('status'));
      novaLog(() => '[NOVA.af] conv status=$status '
          'af_status=${received['af_status']} keys=${received.keys.toList()}');
      if (failed) {
        result = <String, dynamic>{};
      } else if (received['af_status'] == 'Organic') {
        await Future.delayed(LinkConfig.organicRecheckDelay);
        result = await _fetchGcd() ?? received;
      } else {
        result = received;
      }
    } catch (e) {
      novaLog(() => '[NOVA.af] conv parse error: $e');
      result = <String, dynamic>{};
    }
    if (!_conversion.isCompleted) _conversion.complete(result);
  }

  Future<Map<String, dynamic>?> _fetchGcd() async {
    final uid = await afId();
    if (uid == null || uid.isEmpty) return null;
    final agent = await LinkAgent.ready();
    return agent.gcdLookup(LinkConfig.iosStoreId, uid);
  }

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
    final sdk = _sdk;
    if (sdk == null) return null;
    try {
      return await sdk.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

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
      timeout: LinkConfig.awaitSignalsInstall,
    );
    final deep = await awaitDeepLink(
      timeout: const Duration(seconds: 2),
    );
    final af = afIdOverride ?? await afId();
    final body = <String, dynamic>{
      if (conv != null) ...conv,
      if (deep != null) ...deep,
      if (af != null && af.isNotEmpty) 'af_id': af,
      'bundle_id': LinkConfig.bundleId,
      'os': 'iOS',
      'store_id': LinkConfig.platformStoreId,
      'locale': locale,
    };
    if (apnsFcmToken != null && apnsFcmToken.isNotEmpty) {
      body['push_token'] = apnsFcmToken;
      body['firebase_project_id'] = LinkConfig.firebaseProjectId;
    }
    return body;
  }
}
