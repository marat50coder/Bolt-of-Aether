import Flutter
import UIKit

// Cold-start push tap capture.
//
// iOS delivers a terminated-app notification tap through TWO channels:
//
//   1. UNUserNotificationCenterDelegate — Firebase Proxy (enabled by
//      `FirebaseAppDelegateProxyEnabled = true` in Info.plist) captures
//      this and exposes it via `FirebaseMessaging.getInitialMessage()`
//      on the Dart side.
//   2. Scene connection options — `connectionOptions.notificationResponse`
//      in this delegate. Firebase does NOT intercept the scene lifecycle,
//      so this is a redundant safety net when the Firebase swizzle
//      misses the delivery (some iOS 17 / 18 combinations reproducibly do
//      this on cold start).
//
// We persist the extracted URL into `UserDefaults` under
// `flutter.nova_launch_link` (matches `LinkConfig.coldLinkKey` on the
// Dart side). Flutter's `shared_preferences` plugin strips the
// `flutter.` prefix before exposing the value.

final class SceneDelegate: FlutterSceneDelegate {
  // Must stay in sync with `LinkConfig.coldLinkKey` on the Dart side.
  // Change both places together per project.
  private static let coldLinkStorageKey = "flutter.nova_launch_link"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    if let response = connectionOptions.notificationResponse,
       let url = Self.extractUrl(from: response.notification.request.content.userInfo) {
      Self.persist(url)
      #if DEBUG
      NSLog("[NOVA.scene] cold-start push url captured")
      #endif
    }
  }

  // Some iOS versions also deliver the tap through this path when the
  // app is resumed by a push while its state was preserved but its scene
  // was torn down. Firebase covers this too, but the belt-and-braces
  // write is cheap and only fires when a URL is actually present.
  func windowScene(
    _ windowScene: UIWindowScene,
    userDidAcceptCloudKitShareWith cloudKitShareMetadata: Any
  ) {}

  // Payload URL extractor — MUST match the Dart `_extract` (PushBridge)
  // so both the terminated-tap path (this delegate) and the Firebase-
  // swizzled path pick the SAME link. Strict rules:
  //   • only strings under a known URL key count;
  //   • recurse into nested dictionaries at any depth;
  //   • only when the container value is a JSON-encoded blob do we
  //     parse it and rescan, still key-restricted.
  private static let urlKeys: [String] = [
    "deep_link", "target", "destination", "url", "deeplink", "link",
  ]

  private static func extractUrl(from userInfo: [AnyHashable: Any]) -> String? {
    guard let dict = userInfo as? [String: Any] else { return nil }
    return scan(dict)
  }

  private static func scan(_ dict: [String: Any]) -> String? {
    for key in urlKeys {
      if let raw = dict[key] as? String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
      }
    }
    for (_, value) in dict {
      if let nested = value as? [String: Any], let hit = scan(nested) {
        return hit
      }
      if let stringified = value as? String, let hit = parseBlob(stringified) {
        return hit
      }
    }
    return nil
  }

  private static func parseBlob(_ blob: String) -> String? {
    let trimmed = blob.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let data = trimmed.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data)
            as? [String: Any]
    else { return nil }
    return scan(json)
  }

  private static func persist(_ url: String) {
    guard !url.isEmpty else { return }
    let defaults = UserDefaults.standard
    defaults.set(url, forKey: coldLinkStorageKey)
    defaults.synchronize()
  }
}
