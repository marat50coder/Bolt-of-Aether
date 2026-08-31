import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../config/link_config.dart';
import 'link_ledger.dart';
import 'nova_log.dart';

/// Top-level FCM background handler. Required by
/// `FirebaseMessaging.onBackgroundMessage` so FCM knows a Dart isolate
/// can be spun up when the app is terminated / suspended. Even as a
/// no-op it MUST be declared — without it, data-only pushes silently
/// never reach a terminated iOS app on some deliveries.
/// `@pragma('vm:entry-point')` protects it from tree-shaking.
@pragma('vm:entry-point')
Future<void> novaBackgroundMessage(RemoteMessage _) async {}

/// Firebase Messaging + APNs wrapper. Three OS-supplied entry points, all
/// funneled into the same fan-out ([_dispatch]):
///
///   1. Terminated → tap:
///        • primary path — `SceneDelegate` captures the tap and writes
///          it to `UserDefaults`; [TapBridge] consumes it FIRST from
///          the boot screen;
///        • fallback — `FirebaseMessaging.getInitialMessage()` inside
///          [init] (buffered by Firebase's swizzled AppDelegate).
///   2. Backgrounded → tap: `onMessageOpenedApp` listener, registered
///      SYNCHRONOUSLY in [init] so a tap immediately after resume is
///      never dropped on a broadcast stream with no subscribers.
///   3. Foreground → banner tap: iOS renders the banner natively via
///      `setForegroundNotificationPresentationOptions(alert, badge,
///      sound)` and a tap fires `onMessageOpenedApp`.
///
/// Delivery reaches the WebView through the single [onDestination]
/// callback. When no WebView is mounted at dispatch time the URL is
/// stashed in the ledger; `NovaPortal` drains it on mount AND on
/// `AppLifecycleState.resumed`.
class PushBridge {
  PushBridge({required LinkLedger ledger, this.enabled = true})
      : _ledger = ledger;

  final LinkLedger _ledger;
  final bool enabled;

  /// Set by the currently mounted WebView. When null, [_dispatch] stashes
  /// the URL in the ledger so a later mount can drain it.
  void Function(String url)? onDestination;

  final _tokenController = StreamController<String>.broadcast();
  Future<void>? _initFuture;
  String? _fcmToken;

  /// Idempotent, future-caching. Callers (main + NovaWarmup) share the
  /// same future — no `_initDone` boolean races.
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    novaLog(() => '[NOVA.push] init start (enabled=$enabled)');
    if (!enabled) return;

    // Register listeners FIRST so a tap that arrives while
    // getInitialMessage is still resolving is never dropped.
    try {
      FirebaseMessaging.onBackgroundMessage(novaBackgroundMessage);
      novaLog(() => '[NOVA.push] onBackgroundMessage registered');
    } catch (e) {
      novaLog(() => '[NOVA.push] onBackgroundMessage register: $e');
    }

    try {
      FirebaseMessaging.onMessage.listen((msg) {
        // Foreground arrival — iOS renders the banner natively via the
        // presentation options set below. A passive arrival must NOT
        // navigate (only a TAP should yank the user to a new URL). Log
        // so it's obvious pushes are actually reaching the app.
        novaLog(() => '[NOVA.push] onMessage fg payload=${msg.data}');
      });
      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        novaLog(() => '[NOVA.push] onMessageOpenedApp payload=${msg.data}');
        final url = _extract(msg.data);
        if (url != null) {
          novaLog(() => '[NOVA.push] onMessageOpenedApp url=$url');
          _dispatch(url);
        } else {
          novaLog(() => '[NOVA.push] onMessageOpenedApp: no url in payload');
        }
      });
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _fcmToken = token;
        _tokenController.add(token);
      });
      novaLog(() => '[NOVA.push] onMessage / onMessageOpenedApp listeners attached');
    } catch (e) {
      novaLog(() => '[NOVA.push] listener wiring failed: $e');
    }

    try {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      novaLog(() => '[NOVA.push] fg presentation options set');
    } catch (e) {
      novaLog(() => '[NOVA.push] fg presentation options failed: $e');
    }

    // Terminated-tap fallback path. Primary path is SceneDelegate →
    // TapBridge (works even when Firebase Proxy swallowed the response).
    // Short cap because iOS occasionally leaves this pending on non-push
    // cold launches.
    try {
      final initial = await FirebaseMessaging.instance
          .getInitialMessage()
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (initial == null) {
        novaLog(() => '[NOVA.push] getInitialMessage=null (normal cold-launch)');
      } else {
        novaLog(() => '[NOVA.push] getInitialMessage payload=${initial.data}');
        final url = _extract(initial.data);
        if (url != null) {
          novaLog(() => '[NOVA.push] getInitialMessage url=$url');
          // Stash so NovaWarmup._boot picks it up via
          // `ledger.consumePushUrl()` BEFORE routing decides.
          await _ledger.writePushUrl(url);
        } else {
          novaLog(() => '[NOVA.push] getInitialMessage: no url in payload');
        }
      }
    } catch (e) {
      novaLog(() => '[NOVA.push] getInitialMessage failed: $e');
    }

    novaLog(() => '[NOVA.push] init complete');
  }

  /// Ask the OS for permission. Returns true on granted / provisional.
  Future<bool> askPermission() async {
    if (!enabled) return false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      final s = settings.authorizationStatus;
      final granted = s == AuthorizationStatus.authorized ||
          s == AuthorizationStatus.provisional;
      await _ledger.setPushGranted(granted);
      await _ledger.setPushBlockedByOs(s == AuthorizationStatus.denied);
      return granted;
    } catch (e) {
      novaLog(() => '[NOVA.push] askPermission failed: $e');
      return false;
    }
  }

  /// Poll APNs then FCM. Returns the FCM token once available.
  Future<String?> obtainToken({bool longWait = false}) async {
    if (!enabled) return null;
    final attempts = LinkConfig.apnsPollAttempts * (longWait ? 2 : 1);
    for (var i = 0; i < attempts; i++) {
      try {
        if (Platform.isIOS) {
          final apns = await FirebaseMessaging.instance.getAPNSToken();
          if (apns == null || apns.isEmpty) {
            await Future.delayed(LinkConfig.apnsPollStep);
            continue;
          }
        }
        final fcm = await FirebaseMessaging.instance.getToken();
        if (fcm != null && fcm.isNotEmpty) {
          _fcmToken = fcm;
          return fcm;
        }
      } catch (e) {
        novaLog(() => '[NOVA.push] getToken err: $e');
      }
      await Future.delayed(LinkConfig.apnsPollStep);
    }
    return _fcmToken;
  }

  String? get cachedToken => _fcmToken;
  Stream<String> get tokenRefreshes => _tokenController.stream;

  /// Persist FIRST, then invoke the live callback. The persistent write
  /// covers the race where a background-tap resumes the app after the
  /// current WebView has been torn down (route change, offline screen)
  /// but before a new WebView has attached [onDestination]. `NovaPortal`
  /// drains the ledger on mount + on `AppLifecycleState.resumed`.
  Future<void> _dispatch(String url) async {
    if (url.isEmpty) return;
    try {
      await _ledger.writePushUrl(url);
    } catch (_) {}
    final cb = onDestination;
    if (cb != null) {
      novaLog(() => '[NOVA.push] dispatch → live callback ($url)');
      try {
        cb(url);
      } catch (_) {}
    } else {
      novaLog(() => '[NOVA.push] dispatch → ledger (no live cb) ($url)');
    }
  }

  /// First non-empty string in a known key, plus ONE level of nested
  /// `data` / `payload`. Strict allowlist keeps garbage out — the
  /// backend contract fixes the URL to one of these keys.
  static const List<String> _urlKeys = <String>[
    'deep_link',
    'target',
    'destination',
    'url',
    'deeplink',
    'link',
  ];
  static const List<String> _urlContainers = <String>['data', 'payload'];

  String? _extract(Map<String, dynamic> payload) {
    for (final key in _urlKeys) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    for (final container in _urlContainers) {
      final nested = payload[container];
      if (nested is Map) {
        final found = _extract(Map<String, dynamic>.from(nested));
        if (found != null) return found;
      }
    }
    return null;
  }
}
