import UserNotifications

/// Notification Service Extension without Firebase.
///
/// The Runner already brings Firebase via Flutter (CocoaPods locally, Swift
/// Package Manager on some CI images). Pinning `pod 'Firebase/Messaging'`
/// on this target as well produced two identical `module Firebase`
/// declarations in the same Xcode workspace and the archive died with
/// `Redefinition of module 'Firebase'`.
///
/// This extension only attaches a remote image (when the payload carries
/// one) so the banner still shows rich media. Tap-URL capture stays in
/// `SceneDelegate` / `BoltPulse` — those already parse the same payload
/// keys.
final class NotificationService: UNNotificationServiceExtension {
  private var deliver: ((UNNotificationContent) -> Void)?
  private var draft: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    deliver = contentHandler
    guard let draft = request.content.mutableCopy() as? UNMutableNotificationContent else {
      contentHandler(request.content)
      return
    }
    self.draft = draft

    guard let imageURL = Self.imageURL(in: request.content.userInfo) else {
      contentHandler(draft)
      return
    }

    Self.attach(imageURL, onto: draft) { finished in
      contentHandler(finished)
    }
  }

  override func serviceExtensionTimeWillExpire() {
    if let deliver, let draft {
      deliver(draft)
    }
  }

  private static func imageURL(in userInfo: [AnyHashable: Any]) -> URL? {
    let keys = ["image", "image_url", "imageUrl", "media-url", "attachment-url"]
    if let direct = firstHTTPURL(in: userInfo, keys: keys) {
      return direct
    }
    if let options = userInfo["fcm_options"] as? [AnyHashable: Any],
       let nested = firstHTTPURL(in: options, keys: ["image"]) {
      return nested
    }
    if let nested = userInfo["data"] as? [AnyHashable: Any],
       let nestedURL = firstHTTPURL(in: nested, keys: keys) {
      return nestedURL
    }
    return nil
  }

  private static func firstHTTPURL(
    in bag: [AnyHashable: Any],
    keys: [String]
  ) -> URL? {
    for key in keys {
      guard let raw = bag[key] as? String else { continue }
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      if let url = URL(string: trimmed),
         let scheme = url.scheme?.lowercased(),
         scheme == "https" || scheme == "http" {
        return url
      }
    }
    return nil
  }

  private static func attach(
    _ url: URL,
    onto content: UNMutableNotificationContent,
    done: @escaping (UNNotificationContent) -> Void
  ) {
    let task = URLSession.shared.downloadTask(with: url) { location, response, _ in
      defer { done(content) }
      guard let location else { return }

      let ext: String
      if let mime = (response as? HTTPURLResponse)?
        .value(forHTTPHeaderField: "Content-Type")?
        .split(separator: ";").first?
        .trimmingCharacters(in: .whitespaces)
        .lowercased() {
        ext = mime.contains("png") ? "png"
          : mime.contains("gif") ? "gif"
          : mime.contains("webp") ? "webp"
          : "jpg"
      } else {
        let pathExt = url.pathExtension.lowercased()
        ext = pathExt.isEmpty ? "jpg" : pathExt
      }

      let dest = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(ext)
      do {
        try FileManager.default.moveItem(at: location, to: dest)
        let attachment = try UNNotificationAttachment(
          identifier: "bolt-media",
          url: dest,
          options: nil
        )
        content.attachments = [attachment]
      } catch {
        // Plain-text banner is still delivered via `defer`.
      }
    }
    task.resume()
  }
}
