import Foundation
import LocalAuthentication
import SwiftData
import Testing
@testable import ThruFlow

@MainActor struct TogglExportTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func setup() throws -> (ModelContainer, Area, FlowSession) {
        let schema = AppModelContainerFactory.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let area = Area(name: "Work", type: .neutral)
        let session = FlowSession(area: area, mode: .twentyFiveFive, status: .completed,
            startedAt: start, plannedEndAt: start.addingTimeInterval(1500), endedAt: start.addingTimeInterval(900),
            plannedFocusDurationSeconds: 1500, actualFocusDurationSeconds: 600, plannedBreakDurationSeconds: 300,
            accumulatedPauseDurationSeconds: 300, createdAt: start)
        session.recordingDeviceID = "device-a"
        container.mainContext.insert(area)
        container.mainContext.insert(session)
        let segment = FlowSegment(session: session, area: area, todo: nil, startedAt: start, startFocusSeconds: 0)
        segment.close(at: start.addingTimeInterval(900), totalFocusSeconds: 600)
        container.mainContext.insert(segment)
        session.segments = [segment]
        try container.mainContext.save()
        return (container, area, session)
    }

    private func config(_ area: Area) -> TogglConfiguration {
        TogglConfiguration(account: ConnectorAccount(id: "1", name: "Test"), workspaceID: 10,
                           areaProjects: [area.id.uuidString: 20], enabledAt: start.addingTimeInterval(-1), isEnabled: true)
    }

    @Test func initializationDoesNotResolveRecordingIdentity() {
        var reads = 0
        func resolve() -> String? { reads += 1; return "device-a" }
        let store = TogglExportStore(credentials: InMemoryConnectorCredentials(), storage: TogglMemoryStorage(),
                                    deviceID: resolve(), factory: { _ in FakeTogglClient() })
        #expect(reads == 0)
        #expect(store.configuration == nil)
        #expect(store.pendingJobs.isEmpty)
        #expect(reads == 0)
    }

    @Test func automaticKeychainPolicyIsScopedToItsTask() async {
        #expect(ConnectorKeychainInteraction.allowed)
        await ConnectorKeychainInteraction.$allowed.withValue(false) {
            #expect(!ConnectorKeychainInteraction.allowed)
            #expect(ConnectorKeychainInteraction.context(allowed: ConnectorKeychainInteraction.allowed).interactionNotAllowed)
            await Task.yield()
            #expect(!ConnectorKeychainInteraction.allowed)
        }
        #expect(ConnectorKeychainInteraction.allowed)
        #expect(!ConnectorKeychainInteraction.context(allowed: true).interactionNotAllowed)
    }

    @Test func projectionExcludesPausesAndDoesNotRoundFocusedSeconds() throws {
        let (container, area, session) = try setup()
        defer { withExtendedLifetime(container) {} }
        session.actualFocusDurationSeconds = 617
        session.resolvedSegments.first?.endFocusSeconds = 617
        let jobs = TogglExportBuilder().jobs(sessions: [session], configuration: config(area), deviceID: "device-a", now: start.addingTimeInterval(1000))
        #expect(jobs.count == 1)
        #expect(jobs.first?.payload.duration == 617)
        #expect(jobs.first?.payload.project_id == 20)
        #expect(jobs.first?.payload.start == ISO8601DateFormatter().string(from: start))
    }

    @Test func projectionSplitsAreaAndTaskSwitchesAndWaitsForCompleteSegments() throws {
        let (container, area, session) = try setup()
        let other = Area(name: "Study", type: .habit)
        let todo = Todo(title: "Read", area: other)
        container.mainContext.insert(other)
        container.mainContext.insert(todo)
        let first = FlowSegment(session: session, area: area, todo: nil, startedAt: start, startFocusSeconds: 0)
        first.close(at: start.addingTimeInterval(300), totalFocusSeconds: 300)
        let second = FlowSegment(session: session, area: other, todo: todo, startedAt: start.addingTimeInterval(300), startFocusSeconds: 300)
        second.close(at: start.addingTimeInterval(900), totalFocusSeconds: 600)
        session.segments = [first, second]
        var config = config(area)
        config.areaProjects[other.id.uuidString] = 21
        let jobs = TogglExportBuilder().jobs(sessions: [session], configuration: config, deviceID: "device-a", now: start.addingTimeInterval(1000))
        #expect(jobs.map(\.payload.duration) == [300, 300])
        #expect(jobs.map(\.payload.project_id) == [20, 21])
        #expect(jobs.last?.payload.description == "Read")
        session.segments = [first]
        #expect(TogglExportBuilder().jobs(sessions: [session], configuration: config, deviceID: "device-a", now: start.addingTimeInterval(1000)).isEmpty)
    }

    @Test func legacyOtherDeviceOldAndProvisionalRecordsAreNotExported() throws {
        let (container, area, session) = try setup()
        defer { withExtendedLifetime(container) {} }
        let builder = TogglExportBuilder()
        func jobs(_ config: TogglConfiguration) -> [TogglExportJob] {
            builder.jobs(sessions: [session], configuration: config, deviceID: "device-a", now: start.addingTimeInterval(1000))
        }
        session.recordingDeviceID = nil
        #expect(jobs(config(area)).isEmpty)
        session.recordingDeviceID = "device-b"
        #expect(jobs(config(area)).isEmpty)
        session.recordingDeviceID = "device-a"
        session.status = .awaitingResult
        #expect(jobs(config(area)).isEmpty)
        session.status = .completed
        var config = config(area)
        config.enabledAt = start.addingTimeInterval(1)
        #expect(jobs(config).isEmpty)
    }

    @Test func successfulExportSurvivesRelaunchAndDoesNotRepeat() async throws {
        let (container, area, _) = try setup()
        let memory = TogglMemoryStorage()
        memory.state.configuration = config(area)
        let credentials = InMemoryConnectorCredentials()
        try credentials.save(ConnectorCredentials(accessToken: "test"), for: .toggl)
        let client = FakeTogglClient()
        let store = TogglExportStore(credentials: credentials, storage: memory, deviceID: "device-a", factory: { _ in client })
        await store.synchronize(modelContext: container.mainContext, now: start.addingTimeInterval(1000))
        #expect(store.errorMessage == nil)
        #expect(memory.state.jobs.first?.remoteID == 42)
        let restored = TogglExportStore(credentials: credentials, storage: memory, deviceID: "device-a", factory: { _ in client })
        await restored.synchronize(modelContext: container.mainContext, now: start.addingTimeInterval(1000))
        #expect(client.created.count == 1)
    }

    @Test func missingSegmentsWaitAndLaterEditsDoNotExportAgain() async throws {
        let (container, area, session) = try setup()
        let original = session.resolvedSegments
        session.segments = []
        #expect(TogglExportBuilder().jobs(sessions: [session], configuration: config(area), deviceID: "device-a", now: start.addingTimeInterval(1000)).isEmpty)
        session.segments = original
        try container.mainContext.save()
        let storage = TogglMemoryStorage()
        storage.state.configuration = config(area)
        let credentials = InMemoryConnectorCredentials()
        try credentials.save(ConnectorCredentials(accessToken: "test"), for: .toggl)
        let client = FakeTogglClient()
        let store = TogglExportStore(credentials: credentials, storage: storage, deviceID: "device-a", factory: { _ in client })
        await store.synchronize(modelContext: container.mainContext, now: start.addingTimeInterval(1000))
        let replacement = FlowSegment(session: session, area: area, todo: nil, startedAt: start, startFocusSeconds: 0)
        replacement.close(at: start.addingTimeInterval(900), totalFocusSeconds: 600)
        container.mainContext.insert(replacement)
        session.segments = [replacement]
        try container.mainContext.save()
        await store.synchronize(modelContext: container.mainContext, now: start.addingTimeInterval(1000))
        #expect(client.created.count == 1)
        #expect(storage.state.jobs.count == 1)
        #expect(FlowSession(area: area, mode: .twentyFiveFive, startedAt: start, plannedEndAt: start.addingTimeInterval(1500), plannedFocusDurationSeconds: 1500, plannedBreakDurationSeconds: 300).recordingDeviceID == nil)
    }

    @Test func lostResponseReconcilesWithoutAnotherPost() async throws {
        let (container, area, _) = try setup()
        let memory = TogglMemoryStorage()
        memory.state.configuration = config(area)
        let credentials = InMemoryConnectorCredentials()
        try credentials.save(ConnectorCredentials(accessToken: "test"), for: .toggl)
        let client = FakeTogglClient()
        client.createError = URLError(.timedOut)
        let store = TogglExportStore(credentials: credentials, storage: memory, deviceID: "device-a", factory: { _ in client })
        await store.synchronize(modelContext: container.mainContext, now: start.addingTimeInterval(1000))
        #expect(memory.state.jobs.first?.uncertain == true)
        client.createError = nil
        client.foundID = 42
        let restored = TogglExportStore(credentials: credentials, storage: memory, deviceID: "device-a", factory: { _ in client })
        await restored.synchronize(modelContext: container.mainContext, now: start.addingTimeInterval(1000))
        #expect(client.created.count == 1)
        #expect(memory.state.jobs.first?.remoteID == 42)
    }

    @Test func ambiguousPostIsNotAutomaticallyRetriedWhenLookupIsEmpty() async throws {
        let (container, area, _) = try setup()
        let memory = TogglMemoryStorage()
        memory.state.configuration = config(area)
        let credentials = InMemoryConnectorCredentials()
        try credentials.save(ConnectorCredentials(accessToken: "test"), for: .toggl)
        let client = FakeTogglClient()
        client.createError = URLError(.timedOut)
        let store = TogglExportStore(credentials: credentials, storage: memory, deviceID: "device-a", factory: { _ in client })
        await store.synchronize(modelContext: container.mainContext, now: start.addingTimeInterval(1000))
        client.createError = nil
        await store.synchronize(modelContext: container.mainContext, now: start.addingTimeInterval(1000))
        #expect(client.created.count == 1)
        #expect(store.pendingJobs.first?.uncertain == true)
        try store.allowRetry(jobID: try #require(store.pendingJobs.first?.id))
        await store.synchronize(modelContext: container.mainContext, now: start.addingTimeInterval(1000))
        #expect(client.created.count == 2)
        #expect(store.pendingJobs.isEmpty)
    }

    @Test func offlineBeforeConnectionRetriesAndAnotherDeviceCannotDrainQueue() async throws {
        let (container, area, _) = try setup()
        let memory = TogglMemoryStorage()
        memory.state.configuration = config(area)
        let credentials = InMemoryConnectorCredentials()
        try credentials.save(ConnectorCredentials(accessToken: "test"), for: .toggl)
        let client = FakeTogglClient()
        client.createError = URLError(.notConnectedToInternet)
        let store = TogglExportStore(credentials: credentials, storage: memory, deviceID: "device-a", factory: { _ in client })
        await store.synchronize(modelContext: container.mainContext, now: start.addingTimeInterval(1000))
        #expect(memory.state.jobs.first?.uncertain == false)
        let other = TogglExportStore(credentials: credentials, storage: memory, deviceID: "device-b", factory: { _ in client })
        client.createError = nil
        await other.synchronize(modelContext: container.mainContext, now: start.addingTimeInterval(1000))
        #expect(client.created.count == 1)
        await store.synchronize(modelContext: container.mainContext, now: start.addingTimeInterval(1000))
        #expect(client.created.count == 2)
    }

    @Test func storageFailureAndAccountMismatchPreventWrites() async throws {
        let (container, area, _) = try setup()
        let storage = FailingTogglStorage(state: TogglExportState(configuration: config(area)))
        let credentials = InMemoryConnectorCredentials()
        try credentials.save(ConnectorCredentials(accessToken: "test"), for: .toggl)
        let client = FakeTogglClient()
        let store = TogglExportStore(credentials: credentials, storage: storage, deviceID: "device-a", factory: { _ in client })
        await store.synchronize(modelContext: container.mainContext, now: start.addingTimeInterval(1000))
        #expect(client.created.isEmpty)
        let memory = TogglMemoryStorage()
        memory.state.configuration = config(area)
        client.accountID = "other-account"
        let other = TogglExportStore(credentials: credentials, storage: memory, deviceID: "device-a", factory: { _ in client })
        await other.synchronize(modelContext: container.mainContext, now: start.addingTimeInterval(1000))
        #expect(client.created.isEmpty)
        #expect(other.pendingJobs.count == 1)
    }

    @Test func tokenStaysOutOfQueueAndDisconnectPreservesHistory() async throws {
        let (container, _, _) = try setup()
        let memory = TogglMemoryStorage()
        let credentials = InMemoryConnectorCredentials()
        let client = FakeTogglClient()
        let store = TogglExportStore(credentials: credentials, storage: memory, deviceID: "device-a", factory: { _ in client })
        await store.connect(token: "private-token-for-test")
        #expect(try credentials.read(for: .toggl)?.accessToken == "private-token-for-test")
        #expect(!String(data: try JSONEncoder().encode(memory.state), encoding: .utf8)!.contains("private-token-for-test"))
        try store.disconnect()
        #expect(try credentials.read(for: .toggl) == nil)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<FlowSession>()) == 1)
    }

    @Test func deletingAnUnsentFlowCancelsItsQueuedExport() async throws {
        let (container, area, session) = try setup()
        let memory = TogglMemoryStorage()
        memory.state.configuration = config(area)
        let credentials = InMemoryConnectorCredentials()
        try credentials.save(ConnectorCredentials(accessToken: "test"), for: .toggl)
        let client = FakeTogglClient()
        client.createError = URLError(.notConnectedToInternet)
        let store = TogglExportStore(credentials: credentials, storage: memory, deviceID: "device-a", factory: { _ in client })
        await store.synchronize(modelContext: container.mainContext, now: start.addingTimeInterval(1000))
        container.mainContext.delete(session)
        try container.mainContext.save()
        client.createError = nil
        await store.synchronize(modelContext: container.mainContext, now: start.addingTimeInterval(1000))
        #expect(client.created.count == 1)
        #expect(store.pendingJobs.isEmpty)
        #expect(memory.state.jobs.first?.isCancelled == true)
    }

    @Test func mappingMustBelongToWorkspaceAndActivationDoesNotBackfill() async throws {
        let (container, area, _) = try setup()
        defer { withExtendedLifetime(container) {} }
        let storage = TogglMemoryStorage()
        let client = FakeTogglClient()
        let store = TogglExportStore(credentials: InMemoryConnectorCredentials(), storage: storage, deviceID: "device-a", factory: { _ in client })
        await store.connect(token: "test")
        #expect(throws: (any Error).self) {
            try store.configure(workspaceID: 999, areaProjects: [area.id.uuidString: 20], enabled: true)
        }
        try store.configure(workspaceID: 10, areaProjects: [area.id.uuidString: 20], enabled: true, now: start)
        #expect(store.configuration?.enabledAt == start)
        try store.configure(workspaceID: 10, areaProjects: [area.id.uuidString: 20], enabled: false, now: start)
        let later = start.addingTimeInterval(100)
        try store.configure(workspaceID: 10, areaProjects: [area.id.uuidString: 20], enabled: true, now: later)
        #expect(store.configuration?.enabledAt == later)
    }

    @Test func mappingAcceptsActiveProjectWithFalseTrackTimeHintButRejectsArchivedAndForeignProjects() async throws {
        let client = FakeTogglClient()
        client.availableProjects = [
            TogglProject(id: 20, workspace_id: 10, name: "Study", can_track_time: false),
            TogglProject(id: 21, workspace_id: 10, name: "Archived", active: false),
            TogglProject(id: 22, workspace_id: 11, name: "Other workspace")
        ]
        let store = TogglExportStore(credentials: InMemoryConnectorCredentials(), storage: TogglMemoryStorage(),
                                    deviceID: "device-a", factory: { _ in client })
        await store.connect(token: "test")
        let areaID = UUID().uuidString
        try store.configure(workspaceID: 10, areaProjects: [areaID: 20], enabled: true)
        #expect(store.configuration?.areaProjects[areaID] == 20)
        for invalidProject in [Int64(21), 22, 999] {
            #expect(throws: (any Error).self) {
                try store.configure(workspaceID: 10, areaProjects: [areaID: invalidProject], enabled: true)
            }
        }
        #expect(store.configuration?.areaProjects[areaID] == 20)
    }

    @Test func fileStorageRoundTripAndCorruptionFailsClosed() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("queue.json")
        let storage = TogglFileStorage(url: url)
        let state = TogglExportState(configuration: TogglConfiguration(account: ConnectorAccount(id: "1", name: "Test")))
        try storage.save(state)
        #expect(try storage.load().configuration == state.configuration)
        try Data("broken".utf8).write(to: url)
        #expect(throws: (any Error).self) { try storage.load() }
    }
}

@MainActor private final class FakeTogglClient: TogglTrackClientProtocol {
    var accountID = "1"
    var created: [TogglTimePayload] = []
    var createError: (any Error)?
    var foundID: Int64?
    func account() async throws -> ConnectorAccount { ConnectorAccount(id: accountID, name: "Test") }
    func workspaces() async throws -> [TogglWorkspace] { [TogglWorkspace(id: 10, name: "Workspace")] }
    var availableProjects = [TogglProject(id: 20, workspace_id: 10, name: "Project")]
    func projects() async throws -> [TogglProject] { availableProjects }
    func create(_ payload: TogglTimePayload) async throws -> Int64 {
        created.append(payload)
        if let createError { throw createError }
        return 42
    }
    func find(_ payload: TogglTimePayload) async throws -> Int64? { foundID }
}

@MainActor private final class FailingTogglStorage: TogglExportStorage {
    var state: TogglExportState
    init(state: TogglExportState) { self.state = state }
    func load() throws -> TogglExportState { state }
    func save(_ state: TogglExportState) throws { throw TogglError.storage }
}
