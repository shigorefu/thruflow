#if os(iOS)
import UIKit

/// Adapts UIKit lifecycle callbacks to the shared notification delivery owner.
@MainActor
final class IOSAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        guard NotificationDeliveryRuntime.isEnabled else { return true }
        NotificationDeliveryRuntime.shared.start()
        // APNs registration does not request alert authorization. Existing explicit
        // Flow/Task actions remain responsible for asking the user for permission.
        if pushEnvironment != nil {
            application.registerForRemoteNotifications()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        guard NotificationDeliveryRuntime.isEnabled,
              let environment = pushEnvironment else { return }
        NotificationDeliveryRuntime.shared.registerDeviceToken(deviceToken, environment: environment)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        guard NotificationDeliveryRuntime.isEnabled else { return }
        NotificationDeliveryRuntime.shared.registrationFailed()
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard NotificationDeliveryRuntime.isEnabled else {
            completionHandler(.noData)
            return
        }
        Task {
            let accepted = await NotificationDeliveryRuntime.shared.receive(userInfo: userInfo)
            completionHandler(accepted ? .newData : .noData)
        }
    }

    private var pushEnvironment: String? {
        // Supplied alongside the signing entitlement by the build configuration.
        // Fail closed instead of guessing from DEBUG or the device-token bytes.
        guard let value = Bundle.main.object(forInfoDictionaryKey: "ThruFlowPushEnvironment") as? String,
              value == "sandbox" || value == "production" else { return nil }
        return value
    }
}
#endif
