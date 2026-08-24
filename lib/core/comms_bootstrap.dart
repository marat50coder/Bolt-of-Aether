import 'dart:async';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Silent fire-and-forget bootstrap for the marketing / notifications
/// stack.
///
/// This build has no user-visible UI for either SDK; the code exists
/// only so a token is minted (Firebase Messaging) and campaign installs
/// can be attributed (AppsFlyer). Both calls are heavily guarded — a
/// failure MUST NOT crash the app, block the splash, or degrade the
/// fully-offline experience.
class CommsBootstrap {
  CommsBootstrap._();

  /// AppsFlyer numeric App Store id. Shared with the sibling build so
  /// install attribution is consistent regardless of which track the
  /// user came in from.
  static const _appsflyerAppId = '6797957269';

  /// AppsFlyer developer key. Not a secret — it only proves the caller
  /// belongs to the developer account when reporting install / event
  /// data. Same value across the two tracks by design.
  static const _appsflyerDevKey = 'VdZ3pCJaQNjAuHsUK8SkqW';

  /// Boots Firebase and AppsFlyer in parallel. Never awaited from
  /// `main` — the splash / navigation / offline path do not depend on
  /// either service being up.
  static Future<void> bootAll() async {
    await Future.wait<void>([
      _bootFirebase(),
      _bootAppsflyer(),
    ]);
  }

  static Future<void> _bootFirebase() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[CommsBootstrap] Firebase init failed: $e');
    }
  }

  static Future<void> _bootAppsflyer() async {
    try {
      final sdk = AppsflyerSdk(AppsFlyerOptions(
        afDevKey: _appsflyerDevKey,
        appId: _appsflyerAppId,
        showDebug: false,
        // Very small: this build never actually shows the ATT prompt
        // (no visible tracking toggle), so a long wait would only
        // needlessly delay the install POST.
        timeToWaitForATTUserAuthorization: 4,
      ));
      await sdk.initSdk(
        registerConversionDataCallback: false,
        registerOnAppOpenAttributionCallback: false,
        registerOnDeepLinkingCallback: false,
      );
    } catch (e) {
      debugPrint('[CommsBootstrap] AppsFlyer init failed: $e');
    }
  }
}
