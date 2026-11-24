#if os(macOS)
import AppKit
import Security

final class MacOSAppDelegate: NSObject, NSApplicationDelegate {
    private var remoteNotificationEnvironment: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }

        guard NotificationDeliveryRuntime.isEnabled else { return }
        NotificationDeliveryRuntime.shared.start()
        guard let environment = signedPushEnvironment else { return }
        remoteNotificationEnvironment = environment
        // Registration does not request permission to display notifications.
        NSApplication.shared.registerForRemoteNotifications()
    }

    func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        guard NotificationDeliveryRuntime.isEnabled,
              let environment = remoteNotificationEnvironment else { return }
        NotificationDeliveryRuntime.shared.registerDeviceToken(deviceToken, environment: environment)
    }

    func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        guard NotificationDeliveryRuntime.isEnabled else { return }
        NotificationDeliveryRuntime.shared.registrationFailed()
    }

    func application(
        _ application: NSApplication,
        didReceiveRemoteNotification userInfo: [String: Any]
    ) {
        guard NotificationDeliveryRuntime.isEnabled else { return }
        Task {
            _ = await NotificationDeliveryRuntime.shared.receive(userInfo: userInfo)
        }
    }

    private var signedPushEnvironment: String? {
        guard let task = SecTaskCreateFromSelf(nil),
              let environment = SecTaskCopyValueForEntitlement(
                  task, "com.apple.developer.aps-environment" as CFString, nil
              ) as? String else { return nil }
        switch environment {
        case "development": return "sandbox"
        case "production": return "production"
        default: return nil
        }
    }
}
#endif
