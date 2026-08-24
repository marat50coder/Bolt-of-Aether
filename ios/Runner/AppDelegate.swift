import Flutter
import UIKit

// Deliberately minimal. Firebase auto-configures from GoogleService-Info.plist
// via the `firebase_core` Flutter plugin at GeneratedPluginRegistrant time
// (see `FirebaseAppDelegateProxyEnabled = true` in Info.plist). Once the
// proxy is enabled, Firebase installs itself as the
// UNUserNotificationCenterDelegate so `getInitialMessage` /
// `onMessageOpenedApp` fire correctly. Overriding that delegate here — or
// calling `FirebaseApp.configure()` before plugin registration — breaks the
// delivery chain (tapped pushes silently never reach Dart). Every sibling
// gray-flow app (EggRunnerAdventure / Crazy_Hen_Run) uses this exact form.
//
// The ONLY thing we do beyond the parent implementation is kick APNs
// registration so a token can be minted on the very first cold start —
// before the Dart side asks for permission via `pulse.askPermission`.

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
