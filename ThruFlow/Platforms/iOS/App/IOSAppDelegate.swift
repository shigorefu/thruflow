#if os(iOS)
import Combine
import UIKit

/// Adapts UIKit lifecycle callbacks to the shared notification delivery owner.
@MainActor
final class IOSAppDelegate: NSObject, UIApplicationDelegate {
    private var remotePreferenceObserver: AnyCancellable?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        guard NotificationDeliveryRuntime.isEnabled else { return true }
        NotificationDeliveryRuntime.shared.start()
        remotePreferenceObserver = NotificationCenter.default.publisher(for: .notificationRemotePreferenceChanged)
            .sink { [weak self, weak application] _ in
                Task { @MainActor in
                    guard let application else { return }
                    self?.updatePushRegistration(application)
                }
            }
        updatePushRegistration(application)
        return true
    }

    private func updatePushRegistration(_ application: UIApplication) {
        // APNs registration does not request alert authorization. Existing explicit
        // Flow/Task actions remain responsible for asking the user for permission.
        if NotificationDeliveryRuntime.isRemoteEnabled, pushEnvironment != nil {
            application.registerForRemoteNotifications()
        } else {
            application.unregisterForRemoteNotifications()
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        guard NotificationDeliveryRuntime.isRemoteEnabled,
              let environment = pushEnvironment else { return }
        NotificationDeliveryRuntime.shared.registerDeviceToken(deviceToken, environment: environment)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        guard NotificationDeliveryRuntime.isRemoteEnabled else { return }
        NotificationDeliveryRuntime.shared.registrationFailed()
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard NotificationDeliveryRuntime.isRemoteEnabled else {
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
