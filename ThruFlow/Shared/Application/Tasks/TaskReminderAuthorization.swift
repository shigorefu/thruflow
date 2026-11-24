import Foundation
import UserNotifications

/// User-action entry point. Never changes a draft or a synchronized preference.
@MainActor
enum TaskReminderAuthorization {
    static let didChange = Notification.Name("TaskReminderAuthorizationDidChange")
    private static var request: Task<Void, Never>?

    static func requestForUserAction() {
        guard !AppModelContainerFactory.usesDemoData,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              !ScreenshotMode.isEnabled(), !ProcessInfo.processInfo.arguments.contains("--uitesting"), request == nil else { return }
        request = Task {
            let center = UNUserNotificationCenter.current()
            if await center.notificationSettings().authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
            }
            // Reconcile immediately even if capture has already saved and closed.
            NotificationCenter.default.post(name: didChange, object: nil)
            request = nil
        }
    }
}
