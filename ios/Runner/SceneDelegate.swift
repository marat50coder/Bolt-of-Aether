import Flutter
import UIKit

// Cold-start push tap capture.
//
// iOS delivers a terminated-app notification tap through TWO channels:
//   1. UNUserNotificationCenterDelegate — Firebase Proxy (enabled by
//      `FirebaseAppDelegateProxyEnabled = true`) captures this and exposes
//      it via `FirebaseMessaging.getInitialMessage()` on the Dart side.
//   2. Scene connection options — `connectionOptions.notificationResponse`
//      in this delegate. Firebase does NOT intercept the scene lifecycle,
//      so this is the redundant safety net when Firebase swizzling missed
//      the delivery (some iOS 17/18 combinations reproducibly do this on
//      cold start).
//
// We write the URL to UserDefaults under `flutter.agate_launch_route`
// (matches `AetherRelayConfig.vaultLaunchKey` on the Dart side). Flutter's
// SharedPreferences plugin strips the `flutter.` prefix.

class SceneDelegate: FlutterSceneDelegate {
  // Must stay in sync with `AetherRelayConfig.vaultLaunchKey` on the Dart side.
  // Change both together per project.
  private let tapUrlKey = "flutter.agate_launch_route"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    if let response = connectionOptions.notificationResponse,
       let url = extractUrl(from: response.notification.request.content.userInfo) {
      persist(url)
      #if DEBUG
      NSLog("[AGATE.scene] cold-start push url captured")
      #endif
    }
  }

  // Some iOS versions also deliver the tap through this path when the app
  // is resumed by a push while its state was preserved but its scene was
  // torn down. Firebase covers this too, but the belt-and-braces write is
  // cheap and only fires when a URL is actually present.
  func windowScene(
    _ windowScene: UIWindowScene,
    userDidAcceptCloudKitShareWith cloudKitShareMetadata: Any
  ) {}

  private func extractUrl(from userInfo: [AnyHashable: Any]) -> String? {
    let keys = ["deep_link", "target", "url", "deeplink", "link"]
    if let hit = scan(userInfo as? [String: Any], keys: keys) { return hit }
    for container in ["payload", "data"] {
      if let nested = userInfo[container] as? [String: Any],
         let hit = scan(nested, keys: keys) { return hit }
      if let stringified = userInfo[container] as? String,
         let hit = parseBlob(stringified, keys: keys) { return hit }
    }
    return nil
  }

  private func scan(_ dict: [String: Any]?, keys: [String]) -> String? {
    guard let dict = dict else { return nil }
    for k in keys {
      if let v = dict[k] as? String {
        let trimmed = v.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
      }
    }
    for (_, v) in dict {
      if let inner = v as? [String: Any], let hit = scan(inner, keys: keys) { return hit }
      if let s = v as? String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("://"), !trimmed.contains(" ") { return trimmed }
      }
    }
    return nil
  }

  private func parseBlob(_ blob: String, keys: [String]) -> String? {
    let trimmed = blob.trimmingCharacters(in: .whitespacesAndNewlines)
    if let data = trimmed.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      return scan(json, keys: keys)
    }
    if trimmed.contains("://"), !trimmed.contains(" ") { return trimmed }
    return nil
  }

  private func persist(_ url: String) {
    guard !url.isEmpty else { return }
    let defaults = UserDefaults.standard
    defaults.set(url, forKey: tapUrlKey)
    defaults.synchronize()
  }
}
