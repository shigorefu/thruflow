import Combine
import CoreData
import Foundation
import OSLog
import SwiftData
import UserNotifications

struct PendingTaskNotification: Equatable {
    let identifier: String
    let reminder: TaskReminderRequest?
    var fallbackFireDate: Date? = nil
}

@MainActor
protocol TaskNotificationCenter: AnyObject {
    func isAuthorized() async -> Bool
    func pending() async -> [PendingTaskNotification]
    func deliveredIdentifiers() async -> [String]
    func add(_ reminder: TaskReminderRequest) async throws
    func removePending(_ identifiers: [String])
    func removeDelivered(_ identifiers: [String])
}

@MainActor
final class SystemTaskNotificationCenter: TaskNotificationCenter {
    private let center = UNUserNotificationCenter.current()
    private let delegate = TaskNotificationPresentationDelegate()

    init() {
        if center.delegate == nil { center.delegate = delegate }
    }

    func isAuthorized() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
#if os(iOS)
        if status == .ephemeral { return true }
#endif
        return status == .authorized || status == .provisional
    }

    func pending() async -> [PendingTaskNotification] {
        await center.pendingNotificationRequests().map { request in
            let content = request.content
            let identifier = content.userInfo["logical_identifier"] as? String ?? request.identifier
            let reminder: TaskReminderRequest?
            if identifier.hasPrefix(TaskReminderRequest.prefix),
               let id = UUID(uuidString: String(identifier.dropFirst(TaskReminderRequest.prefix.count))),
               let timestamp = content.userInfo["taskReminderDate"] as? Double {
                reminder = TaskReminderRequest(taskID: id, title: content.title, body: content.body,
                                               fireDate: Date(timeIntervalSince1970: timestamp))
            } else {
                reminder = nil
            }
            return PendingTaskNotification(identifier: identifier, reminder: reminder,
                fallbackFireDate: (content.userInfo["fallback_fire_at"] as? Double).map(Date.init(timeIntervalSince1970:)))
        }
    }

    func deliveredIdentifiers() async -> [String] {
        await center.deliveredNotifications().map {
            $0.request.content.userInfo["logical_identifier"] as? String ?? $0.request.identifier
        }
    }

    func add(_ reminder: TaskReminderRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.userInfo = ["taskReminderDate": reminder.fireDate.timeIntervalSince1970]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                  from: reminder.fireDate)
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        try await NotificationDeliveryRuntime.shared.add(UNNotificationRequest(
            identifier: reminder.identifier, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        ))
    }

    func removePending(_ identifiers: [String]) {
        NotificationDeliveryRuntime.shared.removePending(identifiers)
    }

    func removeDelivered(_ identifiers: [String]) {
        NotificationDeliveryRuntime.shared.removeDelivered(identifiers)
    }
}

private final class TaskNotificationPresentationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Keep Flow's existing foreground behavior; only Task reminders opt into presentation.
        completionHandler(notification.request.identifier.hasPrefix("task.reminder.") ? [.banner, .sound] : [])
    }
}

/// Serializes system writes: a save arriving during an async add is reconciled next,
/// so an older request cannot win over a newer completion or reschedule.
@MainActor
final class TaskReminderDelivery {
    private struct Snapshot {
        let requests: [TaskReminderRequest]
        let retainedIdentifiers: Set<String>
        let retainedRequests: [String: TaskReminderRequest]?
    }
    private let center: any TaskNotificationCenter
    private let now: () -> Date
    private var nextSnapshot: Snapshot?
    private var worker: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.shigorefu.thruflow", category: "TaskReminders")

    init(center: any TaskNotificationCenter, now: @escaping () -> Date = { .now }) {
        self.center = center
        self.now = now
    }

    func update(requests: [TaskReminderRequest], retainedTaskIDs: Set<UUID>,
                retainedRequests: [TaskReminderRequest]? = nil) {
        nextSnapshot = Snapshot(requests: requests, retainedIdentifiers: Set(retainedTaskIDs.map {
            TaskReminderRequest.prefix + $0.uuidString
        }), retainedRequests: retainedRequests.map { Dictionary($0.map { ($0.identifier, $0) },
            uniquingKeysWith: { first, _ in first }) })
        guard worker == nil else { return }
        worker = Task { [weak self] in
            guard let self else { return }
            while let snapshot = self.nextSnapshot {
                self.nextSnapshot = nil
                await self.apply(snapshot)
            }
            self.worker = nil
        }
    }

    func waitUntilIdle() async { await worker?.value }

    private func apply(_ snapshot: Snapshot) async {
        let authorized = await center.isAuthorized()
        let pending = await center.pending()
        let foreignCount = pending.filter { !$0.identifier.hasPrefix(TaskReminderRequest.prefix) }.count
        // Leave room for Flow's four notification kinds in the system's bounded queue.
        let capacity = max(0, 64 - max(4, foreignCount))
        let requests = authorized ? Array(snapshot.requests.filter { $0.fireDate > now() }.prefix(capacity)) : []
        let graceIdentifiers = Set(pending.filter {
            authorized && snapshot.retainedIdentifiers.contains($0.identifier) &&
            (snapshot.retainedRequests == nil || snapshot.retainedRequests?[$0.identifier] == $0.reminder) &&
            $0.reminder.map { $0.fireDate <= now() } == true &&
            $0.fallbackFireDate.map { $0 > now() } == true
        }.map(\.identifier))
        let identifiers = Set(requests.map(\.identifier)).union(graceIdentifiers)
        let obsolete = pending.map(\.identifier).filter {
            $0.hasPrefix(TaskReminderRequest.prefix) && !identifiers.contains($0)
        }
        center.removePending(obsolete)
        let delivered = await center.deliveredIdentifiers()
        center.removeDelivered(delivered.filter {
            $0.hasPrefix(TaskReminderRequest.prefix) && !snapshot.retainedIdentifiers.contains($0)
        })
        let existing = Dictionary(pending.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first })
        for request in requests where existing[request.identifier]?.reminder != request {
            // Never turn a time that elapsed while querying the system into an immediate alert.
            guard request.fireDate > now() else { continue }
            do { try await center.add(request) }
            catch { logger.error("Could not schedule a Task reminder: \(error.localizedDescription, privacy: .public)") }
        }
    }
}

/// App-lifetime observer, independent of the currently visible screen or active Flow.
@MainActor
final class TaskReminderScheduler: ObservableObject {
    private var container: ModelContainer?
    private var calendar = Calendar.current
    private var subscriptions = Set<AnyCancellable>()
    private var delivery: TaskReminderDelivery?
    private let logger = Logger(subsystem: "com.shigorefu.thruflow", category: "TaskReminders")

    func start(modelContext: ModelContext, calendar: Calendar) {
        let process = ProcessInfo.processInfo
        guard !AppModelContainerFactory.usesDemoData,
              process.environment["XCTestConfigurationFilePath"] == nil,
              !ScreenshotMode.isEnabled(), !process.arguments.contains("--uitesting") else { return }
        self.container = modelContext.container
        self.calendar = calendar
        if delivery == nil {
            delivery = TaskReminderDelivery(center: SystemTaskNotificationCenter())
            let center = NotificationCenter.default
            let names: [Notification.Name] = [
                ModelContext.didSave, .NSManagedObjectContextDidSave, .NSPersistentStoreRemoteChange,
                TaskReminderAuthorization.didChange,
                NSPersistentCloudKitContainer.eventChangedNotification,
                .NSSystemTimeZoneDidChange, .NSSystemClockDidChange
            ]
            Publishers.MergeMany(names.map { center.publisher(for: $0) })
                .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
                .sink { [weak self] _ in self?.refresh() }
                .store(in: &subscriptions)
            Timer.publish(every: 60, on: .main, in: .common).autoconnect()
                .sink { [weak self] _ in self?.refresh() }
                .store(in: &subscriptions)
        }
        refresh()
    }

    private func refresh() {
        guard let container else { return }
        // A fresh context sees committed local and imported state, never an editor's draft mutations.
        let context = ModelContext(container)
        do {
            let todos = try context.fetch(FetchDescriptor<Todo>(predicate: #Predicate { $0.reminderEnabled }))
            var calendar = calendar
            calendar.timeZone = .current
            let retained = Set(todos.filter(TaskReminderPlan.isEligible).map(\.id))
            delivery?.update(requests: TaskReminderPlan().requests(todos: todos, calendar: calendar, now: .now),
                             retainedTaskIDs: retained,
                             retainedRequests: TaskReminderPlan().requests(todos: todos, calendar: calendar,
                                 now: .distantPast, limit: Int.max))
        } catch {
            // A transient read failure must not erase previously scheduled reminders.
            logger.error("Could not read Tasks for reminders: \(error.localizedDescription, privacy: .public)")
        }
    }
}
