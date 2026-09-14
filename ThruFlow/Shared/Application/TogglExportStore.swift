#if os(macOS) || os(iOS)
import Combine
import Foundation
import SwiftData

@MainActor final class TogglExportStore: ObservableObject {
    @Published private(set) var state = TogglExportState()
    @Published private(set) var workspaces: [TogglWorkspace] = []
    @Published private(set) var projects: [TogglProject] = []
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?
    private let credentials: any ConnectorCredentialStorage
    private let storage: any TogglExportStorage
    private let factory: (String) -> any TogglTrackClientProtocol
    private let deviceID: String?
    private let automaticDisabled: Bool
    private var storageFailed = false
    private var nextAutomaticSync = Date.distantPast

    var configuration: TogglConfiguration? { state.configuration }
    var pendingJobs: [TogglExportJob] {
        state.jobs.filter { $0.accountID == configuration?.account.id && $0.deviceID == deviceID && $0.remoteID == nil && !$0.isCancelled }
    }

    init(credentials: (any ConnectorCredentialStorage)? = nil, storage: (any TogglExportStorage)? = nil,
         deviceID: String? = FlowRecordingDevice.id, factory: ((String) -> any TogglTrackClientProtocol)? = nil) {
        let process = ProcessInfo.processInfo
        let isolated = process.arguments.contains("--uitesting") || process.arguments.contains("--demo-data") ||
            process.arguments.contains("--onboarding-preview") || process.environment["XCTestConfigurationFilePath"] != nil ||
            process.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        self.credentials = credentials ?? (isolated ? InMemoryConnectorCredentials() : ConnectorKeychain())
        self.storage = storage ?? (isolated ? TogglMemoryStorage() : TogglFileStorage())
        self.factory = factory ?? { TogglTrackClient(token: $0) }
        self.deviceID = deviceID
        automaticDisabled = isolated
        do { state = try self.storage.load() }
        catch { storageFailed = true; errorMessage = TogglError.storage.localizedDescription }
    }

    func connect(token: String) async {
        guard begin() else { return }
        defer { isBusy = false }
        do {
            let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty, !token.hasPrefix("toggl_sk_") else { throw TogglError.credentials }
            let client = factory(token)
            let account = try await client.account()
            let spaces = try await client.workspaces()
            let projects = try await client.projects()
            try Task.checkCancellation()
            let oldCredentials = try credentials.read(for: .toggl)
            try credentials.save(ConnectorCredentials(accessToken: token), for: .toggl)
            var updated = state
            if updated.configuration?.account.id != account.id {
                updated.configuration = TogglConfiguration(account: account)
            }
            do { try persist(updated) }
            catch {
                if let oldCredentials { try? credentials.save(oldCredentials, for: .toggl) }
                else { try? credentials.remove(for: .toggl) }
                throw error
            }
            workspaces = spaces
            self.projects = projects
        } catch { present(error) }
    }

    func loadOptions() async {
        guard begin() else { return }
        defer { isBusy = false }
        do {
            let client = try client()
            try await checkAccount(client)
            workspaces = try await client.workspaces()
            projects = try await client.projects()
        } catch { present(error) }
    }

    func configure(workspaceID: Int64, areaProjects: [String: Int64], enabled: Bool, now: Date = .now) throws {
        guard !isBusy, !storageFailed, deviceID != nil, var config = configuration else { throw TogglError.configuration }
        guard workspaces.contains(where: { $0.id == workspaceID }), !areaProjects.isEmpty,
              areaProjects.values.allSatisfy({ id in projects.contains { $0.id == id && $0.workspace_id == workspaceID && $0.active && $0.can_track_time != false } }) else {
            throw TogglError.configuration
        }
        if enabled && !config.isEnabled { config.enabledAt = now }
        config.workspaceID = workspaceID
        config.areaProjects = areaProjects
        config.isEnabled = enabled
        var updated = state
        updated.configuration = config
        try persist(updated)
        nextAutomaticSync = .distantPast
    }

    func disconnect() throws {
        guard !isBusy, !storageFailed else { throw ConnectorStoreError.busy }
        // Disable export durably before removing the token. Keep pending receipts for a same-account reconnect.
        var updated = state
        updated.configuration = nil
        try persist(updated)
        try credentials.remove(for: .toggl)
        workspaces = []
        projects = []
        errorMessage = nil
    }

    func allowRetry(jobID: String) throws {
        guard !isBusy, !storageFailed,
              let index = state.jobs.firstIndex(where: { $0.id == jobID && $0.accountID == configuration?.account.id && $0.deviceID == deviceID && $0.remoteID == nil && !$0.isCancelled }) else { return }
        var updated = state
        updated.jobs[index].uncertain = false
        try persist(updated)
    }

    func automaticSync(modelContext: ModelContext) async {
        guard !automaticDisabled, Date.now >= nextAutomaticSync, configuration?.isEnabled == true else { return }
        nextAutomaticSync = Date.now.addingTimeInterval(30)
        await synchronize(modelContext: modelContext)
    }

    func synchronize(modelContext: ModelContext, now: Date = .now) async {
        guard configuration?.isEnabled == true, let config = configuration, let deviceID, begin() else { return }
        defer { isBusy = false }
        do {
            // Never save/roll back an editor's context or retain model objects across network awaits.
            guard !modelContext.hasChanges else { throw ConnectorStoreError.busy }
            let context = ModelContext(modelContext.container)
            let since = config.enabledAt ?? now
            let descriptor = FetchDescriptor<FlowSession>(predicate: #Predicate {
                $0.recordingDeviceID == deviceID && $0.createdAt >= since
            })
            let candidates = TogglExportBuilder().jobs(sessions: try context.fetch(descriptor), configuration: config, deviceID: deviceID, now: now)
            var updated = state
            let capturedSessions = Set(updated.jobs.filter { $0.accountID == config.account.id }.map(\.sessionID))
            updated.jobs += candidates.filter { !capturedSessions.contains($0.sessionID) }
            try persist(updated) // Durable outbox is written before any network operation.
            guard !pendingJobs.isEmpty else { return }
            let client = try client()
            try await checkAccount(client)
            for job in pendingJobs {
                try Task.checkCancellation()
                guard let index = state.jobs.firstIndex(where: { $0.id == job.id }) else { continue }
                if job.uncertain {
                    if let remoteID = try await client.find(job.payload) {
                        try acknowledge(index: index, remoteID: remoteID)
                        continue
                    }
                    throw TogglError.uncertain // No blind retry after an ambiguous POST.
                }
                let currentStatus = try savedStatus(sessionID: job.sessionID, container: modelContext.container)
                guard currentStatus != nil else {
                    var cancelled = state
                    cancelled.jobs[index].isCancelled = true
                    try persist(cancelled)
                    continue
                }
                guard currentStatus == .completed else { continue }
                var dispatching = state
                dispatching.jobs[index].uncertain = true
                try persist(dispatching)
                do {
                    let remoteID = try await client.create(job.payload)
                    try acknowledge(index: index, remoteID: remoteID)
                } catch {
                    if Self.definitelyNotCreated(error) {
                        var retryable = state
                        retryable.jobs[index].uncertain = false
                        try persist(retryable)
                    }
                    throw error
                }
            }
            var finished = state
            finished.configuration?.lastSyncedAt = now
            try persist(finished)
        } catch { present(error) }
    }

    private func savedStatus(sessionID: UUID, container: ModelContainer) throws -> FlowSessionStatus? {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<FlowSession>(predicate: #Predicate { $0.id == sessionID })).first?.status
    }

    private func acknowledge(index: Int, remoteID: Int64) throws {
        guard remoteID > 0 else { throw ConnectorProviderError.invalidResponse }
        var updated = state
        updated.jobs[index].remoteID = remoteID
        updated.jobs[index].uncertain = false
        try persist(updated)
    }

    private func client() throws -> any TogglTrackClientProtocol {
        guard let token = try credentials.read(for: .toggl)?.accessToken else { throw TogglError.credentials }
        return factory(token)
    }

    private func checkAccount(_ client: any TogglTrackClientProtocol) async throws {
        guard try await client.account().id == configuration?.account.id else { throw TogglError.credentials }
    }

    private func persist(_ value: TogglExportState) throws {
        do { try storage.save(value); state = value }
        catch { throw TogglError.storage }
    }

    private func begin() -> Bool {
        guard !isBusy, !storageFailed else { return false }
        errorMessage = nil
        isBusy = true
        return true
    }

    private func present(_ error: any Error) {
        if case TogglError.rateLimited(let seconds) = error {
            nextAutomaticSync = .now.addingTimeInterval(seconds)
        }
        if error is CancellationError { return }
        errorMessage = error.localizedDescription
    }

    private static func definitelyNotCreated(_ error: any Error) -> Bool {
        if let error = error as? TogglError {
            switch error {
            case .credentials, .rejected, .rateLimited: return true
            default: return false
            }
        }
        if let error = error as? URLError {
            return [.notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed].contains(error.code)
        }
        return false
    }
}
#endif
