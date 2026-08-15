import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../config/relay_config.dart';
import 'agate_log.dart';
import 'relay_vault.dart';

/// Top-level FCM background handler. Required by
/// `FirebaseMessaging.onBackgroundMessage` so FCM knows a Dart isolate can
/// be spun up when the app is terminated / suspended. Even as a no-op it
/// MUST be declared — without it, data-only pushes silently never reach a
/// terminated iOS app on some deliveries. `@pragma('vm:entry-point')`
/// keeps tree-shaking from removing it.
@pragma('vm:entry-point')
Future<void> agateBackgroundMessage(RemoteMessage _) async {}

/// Firebase Messaging + APNs wrapper. Three OS-supplied entry points, all
/// funneled into the same fan-out (`_dispatch`):
///
///   1. Terminated → tap:
///      • primary path — SceneDelegate captures the tap and writes to
///        UserDefaults; ArcTapReader consumes it FIRST in AetherWarmup;
///      • fallback — `FirebaseMessaging.getInitialMessage()` inside
///        `init()` (buffered by Firebase's swizzled AppDelegate methods).
///   2. Backgrounded → tap: `onMessageOpenedApp` listener (registered
///      SYNCHRONOUSLY in `init()` so a tap immediately after resume is
///      never dropped on a broadcast stream with no subscribers).
///   3. Foreground → banner tap: iOS shows the banner natively via
///      `setForegroundNotificationPresentationOptions(alert,badge,sound)`
///      and a tap also fires `onMessageOpenedApp`.
///
/// Delivery to the WebView goes via `onDestination` (matches
/// PulseRelay in the reference sibling). If the WebView is not mounted at
/// dispatch time the URL is stashed in the vault; StormChannel drains it
/// on mount and on `AppLifecycleState.resumed`. Single callback (not a
/// list of listeners) — mirrors the reference exactly and eliminates a
/// class of "which listener won" bugs on remount.
class BoltPulse {
  BoltPulse({required RelayVault vault, this.enabled = true}) : _vault = vault;

  final RelayVault _vault;
  final bool enabled;

  /// Set by the current WebView shell. Null when no shell is mounted; in
  /// that case dispatch stashes the URL to the vault for later drain.
  void Function(String url)? onDestination;

  final _tokenController = StreamController<String>.broadcast();
  Future<void>? _initFuture;
  String? _fcmToken;

  /// Idempotent, future-caching. Callers (main + AetherWarmup) share the
  /// same future — no `_initDone` boolean races.
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    agateLog(() => '[AGATE.pulse] init start (enabled=$enabled)');
    if (!enabled) return;

    // Register listeners FIRST so a tap that arrives while
    // getInitialMessage is still resolving does not fall on the floor.
    try {
      FirebaseMessaging.onBackgroundMessage(agateBackgroundMessage);
      agateLog(() => '[AGATE.pulse] onBackgroundMessage registered');
    } catch (e) {
      agateLog(() => '[AGATE.pulse] onBackgroundMessage register: $e');
    }

    try {
      FirebaseMessaging.onMessage.listen((msg) {
        // Foreground arrival — iOS renders the banner natively via the
        // presentation options below. A passive arrival must NOT navigate
        // (only a TAP should yank the user to a new URL). Log so we can
        // see that pushes are actually reaching the app.
        agateLog(() => '[AGATE.pulse] onMessage fg payload=${msg.data}');
      });
      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        agateLog(() => '[AGATE.pulse] onMessageOpenedApp payload=${msg.data}');
        final url = _extract(msg.data);
        if (url != null) {
          agateLog(() => '[AGATE.pulse] onMessageOpenedApp url=$url');
          _dispatch(url);
        } else {
          agateLog(() => '[AGATE.pulse] onMessageOpenedApp: no url in payload');
        }
      });
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _fcmToken = token;
        _tokenController.add(token);
      });
      agateLog(() => '[AGATE.pulse] onMessage / onMessageOpenedApp listeners attached');
    } catch (e) {
      agateLog(() => '[AGATE.pulse] listener wiring failed: $e');
    }

    try {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      agateLog(() => '[AGATE.pulse] fg presentation options set');
    } catch (e) {
      agateLog(() => '[AGATE.pulse] fg presentation options failed: $e');
    }

    // Terminated-tap fallback path. Primary path is
    // SceneDelegate → ArcTapReader (works even when Firebase Proxy
    // swallowed the response). Short cap because iOS occasionally leaves
    // this pending on non-push cold launches.
    try {
      final initial = await FirebaseMessaging.instance
          .getInitialMessage()
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (initial == null) {
        agateLog(() => '[AGATE.pulse] getInitialMessage=null (normal cold-launch)');
      } else {
        agateLog(() => '[AGATE.pulse] getInitialMessage payload=${initial.data}');
        final url = _extract(initial.data);
        if (url != null) {
          agateLog(() => '[AGATE.pulse] getInitialMessage url=$url');
          // Stash so AetherWarmup._boot picks it up via
          // `vault.consumePushUrl()` BEFORE routing decides.
          await _vault.writePushUrl(url);
        } else {
          agateLog(() => '[AGATE.pulse] getInitialMessage: no url in payload');
        }
      }
    } catch (e) {
      agateLog(() => '[AGATE.pulse] getInitialMessage failed: $e');
    }

    agateLog(() => '[AGATE.pulse] init complete');
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
      await _vault.setPushGranted(granted);
      await _vault.setPushBlockedByOs(s == AuthorizationStatus.denied);
      return granted;
    } catch (e) {
      agateLog(() => '[AGATE.pulse] askPermission failed: $e');
      return false;
    }
  }

  /// Poll APNs then FCM. Returns the FCM token once available.
  Future<String?> obtainToken({bool longWait = false}) async {
    if (!enabled) return null;
    final attempts = AetherRelayConfig.apnsPollAttempts * (longWait ? 2 : 1);
    for (var i = 0; i < attempts; i++) {
      try {
        if (Platform.isIOS) {
          final apns = await FirebaseMessaging.instance.getAPNSToken();
          if (apns == null || apns.isEmpty) {
            await Future.delayed(AetherRelayConfig.apnsPollStep);
            continue;
          }
        }
        final fcm = await FirebaseMessaging.instance.getToken();
        if (fcm != null && fcm.isNotEmpty) {
          _fcmToken = fcm;
          return fcm;
        }
      } catch (e) {
        agateLog(() => '[AGATE.pulse] getToken err: $e');
      }
      await Future.delayed(AetherRelayConfig.apnsPollStep);
    }
    return _fcmToken;
  }

  String? get cachedToken => _fcmToken;
  Stream<String> get tokenRefreshes => _tokenController.stream;

  /// Persist FIRST, then invoke the live callback. The persistent write
  /// covers the race where a background-tap resumes the app after the
  /// current WebView has been torn down (route change, offline screen)
  /// but before a new WebView has attached `onDestination`. StormChannel
  /// drains the vault on mount + on `AppLifecycleState.resumed`.
  Future<void> _dispatch(String url) async {
    if (url.isEmpty) return;
    try {
      await _vault.writePushUrl(url);
    } catch (_) {}
    final cb = onDestination;
    if (cb != null) {
      agateLog(() => '[AGATE.pulse] dispatch → live callback ($url)');
      try {
        cb(url);
      } catch (_) {}
    } else {
      agateLog(() => '[AGATE.pulse] dispatch → vault (no live cb) ($url)');
    }
  }

  /// Match the sibling reference (`PulseRelay._extract`,
  /// `EggSignalHub._extract`): first non-empty string in known keys, plus
  /// ONE level of nested `data` / `payload`. No scheme filter, no
  /// last-resort scan — a stricter extractor keeps garbage out and the
  /// backend contract is fixed (URL always lives in one of these keys).
  static const List<String> _urlKeys = <String>[
    'target',
    'url',
    'deep_link',
    'link',
    'deeplink',
    'destination',
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
