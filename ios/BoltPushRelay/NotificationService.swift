import UserNotifications
import FirebaseMessaging

// Rich-media Notification Service Extension. The payload from FCM must set
// `apns.payload.aps.mutable-content = 1` for iOS to hand the notification to
// this extension before delivery — see gray_flow_guide.md §Push payload.
//
// Firebase Messaging exposes a helper that both downloads any image
// attachment and forwards the tap analytics; we defer to it and only add a
// safety wrapper so a failure never blocks the delivery of the plain text
// notification.

class NotificationService: UNNotificationServiceExtension {
  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttempt: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    let mutable = (request.content.mutableCopy() as? UNMutableNotificationContent)
      ?? UNMutableNotificationContent()
    self.bestAttempt = mutable

    Messaging.serviceExtension().populateNotificationContent(
      mutable,
      withContentHandler: { modified in
        contentHandler(modified)
      }
    )
  }

  override func serviceExtensionTimeWillExpire() {
    // iOS is about to reclaim us — hand back whatever we have so the user
    // still sees the notification (without the image if it didn't finish
    // downloading).
    if let handler = contentHandler, let content = bestAttempt {
      handler(content)
    }
  }
}
