import Foundation
import Testing
@testable import ThruFlow

@MainActor
struct TaskReminderDeliveryTests {
    @Test func updateReplacesTimeAndCancelsOnlyTaskNotifications() async {
        let center = FakeTaskCenter()
        let clock = Date(timeIntervalSince1970: 2_000_000_000)
        let delivery = TaskReminderDelivery(center: center, now: { clock })
        let old = request(date: clock.addingTimeInterval(60))
        center.requests["flow.focusFinished"] = PendingTaskNotification(identifier: "flow.focusFinished", reminder: nil)
        delivery.update(requests: [old], retainedTaskIDs: [old.taskID])
        await delivery.waitUntilIdle()
        let moved = TaskReminderRequest(taskID: old.taskID, title: old.title, body: old.body,
                                        fireDate: clock.addingTimeInterval(120))
        delivery.update(requests: [moved], retainedTaskIDs: [moved.taskID])
        await delivery.waitUntilIdle()
        #expect(center.requests[moved.identifier]?.reminder == moved)
        #expect(center.additions.count == 2)
        delivery.update(requests: [moved], retainedTaskIDs: [moved.taskID])
        await delivery.waitUntilIdle()
        #expect(center.additions.count == 2)
        center.delivered = [moved.identifier, "flow.breakFinished"]
        delivery.update(requests: [], retainedTaskIDs: [])
        await delivery.waitUntilIdle()
        #expect(center.requests.count == 1)
        #expect(center.requests["flow.focusFinished"] != nil)
        #expect(center.delivered == ["flow.breakFinished"])
    }

    @Test func noPermissionCancelsPendingWithoutRequestingAuthorization() async {
        let center = FakeTaskCenter()
        let clock = Date(timeIntervalSince1970: 2_000_000_000)
        let item = request(date: clock.addingTimeInterval(60))
        center.requests[item.identifier] = PendingTaskNotification(identifier: item.identifier, reminder: item)
        center.authorized = false
        let delivery = TaskReminderDelivery(center: center, now: { clock })
        delivery.update(requests: [item], retainedTaskIDs: [item.taskID])
        await delivery.waitUntilIdle()
        #expect(center.requests.isEmpty)
        #expect(center.additions.isEmpty)
        // The abstraction deliberately has no requestAuthorization operation.
    }

    @Test func completionDuringSuspendedAddWinsAndNextRefreshRetriesFailures() async {
        let center = FakeTaskCenter()
        let clock = Date(timeIntervalSince1970: 2_000_000_000)
        let item = request(date: clock.addingTimeInterval(60))
        let delivery = TaskReminderDelivery(center: center, now: { clock })
        center.onAdd = { delivery.update(requests: [], retainedTaskIDs: []) }
        delivery.update(requests: [item], retainedTaskIDs: [item.taskID])
        await delivery.waitUntilIdle()
        #expect(center.requests.isEmpty)
        center.onAdd = nil
        center.shouldFail = true
        delivery.update(requests: [item], retainedTaskIDs: [item.taskID])
        await delivery.waitUntilIdle()
        #expect(center.requests.isEmpty)
        center.shouldFail = false
        delivery.update(requests: [item], retainedTaskIDs: [item.taskID])
        await delivery.waitUntilIdle()
        #expect(center.requests[item.identifier]?.reminder == item)
    }

    @Test func queueCapacityPreservesForeignNotificationsAndRejectsPastDates() async {
        let center = FakeTaskCenter()
        let clock = Date(timeIntervalSince1970: 2_000_000_000)
        for index in 0..<10 {
            let id = "foreign.\(index)"
            center.requests[id] = PendingTaskNotification(identifier: id, reminder: nil)
        }
        let items = (0..<70).map { request(date: clock.addingTimeInterval(Double($0 * 60))) }
        let delivery = TaskReminderDelivery(center: center, now: { clock })
        delivery.update(requests: items, retainedTaskIDs: Set(items.map(\.taskID)))
        await delivery.waitUntilIdle()
        #expect(center.requests.count == 64)
        #expect(center.additions.count == 54)
        #expect(center.requests[items[0].identifier] == nil)
        #expect(center.requests["foreign.9"] != nil)
    }

    @Test func deliveredPastReminderRemainsUntilTaskBecomesIneligible() async {
        let center = FakeTaskCenter()
        let item = request(date: .distantPast)
        center.delivered = [item.identifier]
        let delivery = TaskReminderDelivery(center: center)
        delivery.update(requests: [], retainedTaskIDs: [item.taskID])
        await delivery.waitUntilIdle()
        #expect(center.delivered == [item.identifier])
    }

    private func request(date: Date) -> TaskReminderRequest {
        TaskReminderRequest(taskID: UUID(), title: "Reminder", body: "Study", fireDate: date)
    }
}

@MainActor
private final class FakeTaskCenter: TaskNotificationCenter {
    var authorized = true
    var requests: [String: PendingTaskNotification] = [:]
    var delivered: [String] = []
    var additions: [TaskReminderRequest] = []
    var shouldFail = false
    var onAdd: (() -> Void)?
    func isAuthorized() async -> Bool { authorized }
    func pending() async -> [PendingTaskNotification] { Array(requests.values) }
    func deliveredIdentifiers() async -> [String] { delivered }
    func add(_ reminder: TaskReminderRequest) async throws {
        if shouldFail { throw Failure.expected }
        onAdd?()
        await Task.yield()
        requests[reminder.identifier] = PendingTaskNotification(identifier: reminder.identifier, reminder: reminder)
        additions.append(reminder)
    }
    func removePending(_ identifiers: [String]) { for id in identifiers { requests[id] = nil } }
    func removeDelivered(_ identifiers: [String]) { delivered.removeAll { identifiers.contains($0) } }
    enum Failure: Error { case expected }
}
