import Foundation
import Testing
import UserNotifications
@testable import ThruFlow

@MainActor
struct NotificationDeliveryRuntimeTests {
    @Test func noServerReadinessKeepsOriginalLocalDeadlineAndPrivateTextLocal() async throws {
        let fixture = Fixture()
        defer { fixture.clean() }
        fixture.transport.ready = false
        fixture.runtime.registerDeviceToken(Data([1, 2]), environment: "sandbox")
        let request = fixture.request()
        try await fixture.runtime.add(request)
        await fixture.runtime.waitUntilIdle()
        let local = try #require(fixture.center.logicalRequest(request.identifier))
        #expect(local.content.body == "Private task title")
        #expect(abs(local.fireDate!.timeIntervalSince(fixture.fireDate)) < 2)
        #expect(fixture.transport.snapshots.isEmpty)
    }

    @Test func durableAcceptanceDelaysFallbackAndExportsOnlyGenericTaskCopy() async throws {
        let fixture = Fixture()
        defer { fixture.clean() }
        fixture.runtime.registerDeviceToken(Data([1]), environment: "production")
        let request = fixture.request()
        try await fixture.runtime.add(request)
        await fixture.runtime.waitUntilIdle()
        let local = try #require(fixture.center.logicalRequest(request.identifier))
        #expect(abs(local.fireDate!.timeIntervalSince(fixture.fireDate) - 30) < 2)
        #expect(local.content.body == "Private task title")
        #expect(local.content.userInfo["taskReminderDate"] as? Double == fixture.fireDate.timeIntervalSince1970)
        let sent = try #require(fixture.transport.snapshots.last?.events.first)
        #expect(sent.title == "タスクの時間です")
        #expect(sent.body.isEmpty)
        #expect(sent.fireAt == fixture.fireDate.timeIntervalSince1970)
        #expect(fixture.center.logicalRequest(request.identifier) != nil)
    }

    @Test func receiptMustMatchCurrentVersionAndNeverCancelsRescheduledTask() async throws {
        let fixture = Fixture()
        defer { fixture.clean() }
        let request = fixture.request()
        try await fixture.runtime.add(request)
        let first = try #require(fixture.center.logicalRequest(request.identifier))
        let moved = fixture.request(date: fixture.fireDate.addingTimeInterval(60))
        try await fixture.runtime.add(moved)
        let second = try #require(fixture.center.logicalRequest(request.identifier))
        #expect(first.content.userInfo["event_version"] as? String != second.content.userInfo["event_version"] as? String)
        #expect(!(await fixture.runtime.receive(userInfo: first.content.userInfo)))
        await fixture.runtime.waitUntilIdle()
        #expect(fixture.center.logicalRequest(request.identifier) != nil)
        #expect(await fixture.runtime.receive(userInfo: second.content.userInfo))
        await fixture.runtime.waitUntilIdle()
        #expect(fixture.center.logicalRequest(request.identifier) == nil)
        #expect(await fixture.runtime.receive(userInfo: second.content.userInfo))
    }

    @Test func cancelDuringServerAcceptanceCannotResurrectLocalOrRemoteEvent() async throws {
        let fixture = Fixture()
        defer { fixture.clean() }
        let request = fixture.request()
        try await fixture.runtime.add(request)
        fixture.transport.onReplace = { fixture.runtime.removePending([request.identifier]) }
        fixture.runtime.registerDeviceToken(Data([1]), environment: "sandbox")
        await fixture.runtime.waitUntilIdle()
        #expect(fixture.center.logicalRequest(request.identifier) == nil)
        #expect(fixture.transport.snapshots.last?.events.isEmpty == true)
        #expect(fixture.transport.snapshots.map(\.revision).sorted() == fixture.transport.snapshots.map(\.revision))
    }

    @Test func registrationFailureRestoresOriginalDeadlineAndNoSavedTokenEnablesRelaunch() async throws {
        let fixture = Fixture()
        defer { fixture.clean() }
        fixture.runtime.registerDeviceToken(Data([1]), environment: "sandbox")
        try await fixture.runtime.add(fixture.request())
        await fixture.runtime.waitUntilIdle()
        fixture.runtime.registrationFailed()
        await fixture.runtime.waitUntilIdle()
        let local = try #require(fixture.center.logicalRequest(fixture.identifier))
        #expect(abs(local.fireDate!.timeIntervalSince(fixture.fireDate)) < 2)
        let transport = FakeRemoteTransport()
        let restored = NotificationDeliveryRuntime(center: fixture.center, defaults: fixture.defaults,
            transport: transport, enabled: { true }, systemHooks: false)
        restored.start()
        await restored.waitUntilIdle()
        #expect(transport.enrollmentCount == 0)
        restored.registerDeviceToken(Data([2]), environment: "production")
        await restored.waitUntilIdle()
        #expect(transport.snapshots.last?.events.count == 1)
    }

    @Test func receiptBeforeServerAcknowledgmentPreventsFallbackRecreation() async throws {
        let fixture = Fixture()
        defer { fixture.clean() }
        try await fixture.runtime.add(fixture.request())
        let local = try #require(fixture.center.logicalRequest(fixture.identifier))
        fixture.transport.onReplaceAsync = { _ = await fixture.runtime.receive(userInfo: local.content.userInfo) }
        fixture.runtime.registerDeviceToken(Data([1]), environment: "sandbox")
        await fixture.runtime.waitUntilIdle()
        #expect(fixture.center.logicalRequest(fixture.identifier) == nil)
        #expect(fixture.transport.snapshots.last?.events.isEmpty == true)
    }

    @Test func disabledRuntimeStaysFullyLocal() async throws {
        let fixture = Fixture(enabled: false)
        defer { fixture.clean() }
        fixture.runtime.registerDeviceToken(Data([1]), environment: "sandbox")
        try await fixture.runtime.add(fixture.request())
        await fixture.runtime.waitUntilIdle()
        let local = try #require(fixture.center.logicalRequest(fixture.identifier))
        #expect(local.content.userInfo["event_version"] == nil)
        #expect(fixture.transport.enrollmentCount == 0)
    }

    @Test func foregroundPresentsEachVersionOnceAcrossLocalAndRemoteCallbacks() async throws {
        let fixture = Fixture()
        defer { fixture.clean() }
        try await fixture.runtime.add(fixture.request())
        let local = try #require(fixture.center.logicalRequest(fixture.identifier))
        #expect(await fixture.runtime.receive(userInfo: local.content.userInfo))
        #expect(await fixture.runtime.shouldPresentRemote(userInfo: local.content.userInfo))
        #expect(!(await fixture.runtime.shouldPresentRemote(userInfo: local.content.userInfo)))
        #expect(!fixture.runtime.shouldPresentLocal(userInfo: local.content.userInfo))
    }

    @Test func newerEnrollmentRevisionRebasesRestoredClientBeforeReplacingSnapshot() async throws {
        let fixture = Fixture()
        defer { fixture.clean() }
        fixture.transport.revision = Int64.max / 2
        fixture.runtime.registerDeviceToken(Data([1]), environment: "sandbox")
        await fixture.runtime.waitUntilIdle()
        #expect(fixture.transport.snapshots.first?.revision == fixture.transport.revision + 1)
        #expect(fixture.transport.snapshots.first?.events.isEmpty == true)
    }

    @Test func explicitCancellationInvalidatesPreviouslyReceivedVersion() async throws {
        let fixture = Fixture()
        defer { fixture.clean() }
        try await fixture.runtime.add(fixture.request())
        let local = try #require(fixture.center.logicalRequest(fixture.identifier))
        #expect(await fixture.runtime.receive(userInfo: local.content.userInfo))
        fixture.runtime.removePending([fixture.identifier])
        await fixture.runtime.waitUntilIdle()
        #expect(!(await fixture.runtime.shouldPresentRemote(userInfo: local.content.userInfo)))
    }
}

@MainActor
private final class Fixture {
    let suite = "NotificationDeliveryRuntimeTests.\(UUID().uuidString)"
    let center = FakeDeliveryCenter()
    let transport = FakeRemoteTransport()
    let fireDate = Date.now.addingTimeInterval(3_600)
    let identifier = "task.reminder.\(UUID().uuidString)"
    let defaults: UserDefaults
    let runtime: NotificationDeliveryRuntime
    init(enabled: Bool = true) {
        defaults = UserDefaults(suiteName: suite)!
        runtime = NotificationDeliveryRuntime(center: center, defaults: defaults, transport: transport,
                                              enabled: { enabled }, systemHooks: false)
    }
    func clean() { defaults.removePersistentDomain(forName: suite) }
    func request(date: Date? = nil) -> UNNotificationRequest {
        let date = date ?? fireDate
        let content = UNMutableNotificationContent()
        content.title = "タスクの時間です"
        content.body = "Private task title"
        content.userInfo = ["taskReminderDate": date.timeIntervalSince1970]
        return UNNotificationRequest(identifier: identifier, content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: date.timeIntervalSinceNow, repeats: false))
    }
}

@MainActor
private final class FakeDeliveryCenter: NotificationDeliveryCenter {
    var requests: [String: UNNotificationRequest] = [:]
    func logicalRequest(_ id: String) -> UNNotificationRequest? {
        requests.values.first { $0.identifier == id || $0.content.userInfo["logical_identifier"] as? String == id }
    }
    func pending() async -> [UNNotificationRequest] { Array(requests.values) }
    func delivered() async -> [UNNotificationRequest] { [] }
    func add(_ request: UNNotificationRequest) async throws { requests[request.identifier] = request }
    func removePending(_ identifiers: [String]) { for id in identifiers { requests[id] = nil } }
    func removeDelivered(_ identifiers: [String]) {}
}

@MainActor
private final class FakeRemoteTransport: RemoteNotificationTransport {
    var ready = true
    var enrollmentCount = 0
    var snapshots: [RemoteNotificationSnapshot] = []
    var onReplace: (() -> Void)?
    var onReplaceAsync: (() async -> Void)?
    var revision: Int64 = 0
    func enroll(token: String, environment: String) async throws -> RemoteNotificationEnrollment {
        enrollmentCount += 1
        return RemoteNotificationEnrollment(ready: ready, revision: revision)
    }
    func replace(_ snapshot: RemoteNotificationSnapshot) async throws -> Bool {
        snapshots.append(snapshot)
        let callback = onReplace
        onReplace = nil
        callback?()
        let asyncCallback = onReplaceAsync
        onReplaceAsync = nil
        await asyncCallback?()
        return true
    }
}

private extension UNNotificationRequest {
    var fireDate: Date? {
        (trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ??
        (trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
    }
}
