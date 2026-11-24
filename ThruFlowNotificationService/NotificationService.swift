import Foundation
import UserNotifications

/// Receipts are best effort. APNs acceptance is never treated as device delivery.
final class NotificationService: UNNotificationServiceExtension {
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        // Disabling server delivery must never let a late remote receipt cancel
        // a restored local notification. It cannot recall a push already in flight.
        let preferences = UserDefaults(suiteName: "group.com.shigorefu.thruflow")
        guard preferences?.object(forKey: "notification.remote.enabled") as? Bool != false else {
            contentHandler(request.content)
            return
        }
        let info = request.content.userInfo
        guard let identifier = info["local_identifier"] as? String,
              let version = info["event_version"] as? String,
              UUID(uuidString: version) != nil,
              identifier.hasPrefix("flow.") || identifier.hasPrefix("task.reminder.") else {
            contentHandler(request.content)
            return
        }
        // A receipt can arrive before the schedule HTTP response. The app checks
        // this marker before extending/re-adding its local safety request.
        let defaults = UserDefaults(suiteName: "group.com.shigorefu.thruflow")
        let prefix = "notification.receipt."
        defaults?.set(Date().timeIntervalSince1970, forKey: prefix + version)
        if let defaults {
            let cutoff = Date().timeIntervalSince1970 - 86_400
            for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(prefix) {
                if let timestamp = value as? Double, timestamp < cutoff { defaults.removeObject(forKey: key) }
            }
        }
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            if pending.contains(where: {
                $0.identifier == identifier && $0.content.userInfo["event_version"] as? String == version
            }) {
                center.removePendingNotificationRequests(withIdentifiers: [identifier])
            }
            contentHandler(request.content)
        }
    }
}
