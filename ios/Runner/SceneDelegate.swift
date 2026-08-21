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

  // Payload URL extractor — MUST match the Dart `_extract` (BoltPulse) so
  // both the terminated-tap path (this delegate) and the Firebase-swizzled
  // path pick the SAME link. Historical bug (fixed): the old scanner had
  // an "any string containing ://" catch-all, so a rich-push payload with
  // `fcm_options.image` or `google.c.*` metadata URLs made the first push
  // load the image URL instead of the campaign `deep_link`.
  //
  // Strict rules now:
  //   • Only strings under one of the known URL keys count.
  //   • Recurse into nested dictionaries (any depth) — matches the
  //     Dart-side one-level `data` / `payload` behaviour and also copes
  //     with senders that nest deeper.
  //   • Only when the container value is a JSON-encoded blob do we parse
  //     it and rescan, still key-restricted.
  private static let urlKeys: [String] = [
    "deep_link", "target", "url", "deeplink", "link", "destination",
  ]

  private func extractUrl(from userInfo: [AnyHashable: Any]) -> String? {
    guard let dict = userInfo as? [String: Any] else { return nil }
    return scan(dict)
  }

  private func scan(_ dict: [String: Any]) -> String? {
    for key in Self.urlKeys {
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

  private func parseBlob(_ blob: String) -> String? {
    let trimmed = blob.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let data = trimmed.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data)
            as? [String: Any]
    else { return nil }
    return scan(json)
  }

  private func persist(_ url: String) {
    guard !url.isEmpty else { return }
    let defaults = UserDefaults.standard
    defaults.set(url, forKey: tapUrlKey)
    defaults.synchronize()
  }
}
