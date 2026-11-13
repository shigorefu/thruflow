import CoreData
import Foundation

enum OnboardingWorkspaceSettler {
    /// SwiftData does not expose a definitive "initial CloudKit import is done"
    /// state. Prefer the first successful Core Data CloudKit import event, while
    /// keeping first launch usable when the device is offline or the account is
    /// genuinely empty.
    static let maximumWait: Duration = .seconds(4)

    static func waitForInitialImportOrTimeout() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                try? await Task.sleep(for: maximumWait)
            }
            group.addTask {
                for await notification in NotificationCenter.default.notifications(
                    named: NSPersistentCloudKitContainer.eventChangedNotification
                ) {
                    guard !Task.isCancelled else { return }
                    guard let event = notification.userInfo?[
                        NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                    ] as? NSPersistentCloudKitContainer.Event,
                    event.type == .import,
                    event.endDate != nil,
                    event.succeeded else {
                        continue
                    }
                    return
                }
            }

            _ = await group.next()
            group.cancelAll()
        }

        await Task.yield()
    }
}
