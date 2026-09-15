import Foundation

nonisolated enum ConnectorStoreError: LocalizedError {
    case keychain, configuration, missingConnection, chooseSources, missingArea, busy
    var errorDescription: String? {
        switch self {
        case .keychain: String(localized: "アクセスキーを保存または読み込めませんでした。端末のロックを解除して再試行してください。")
        case .configuration: String(localized: "接続設定を読み込めませんでした。接続を設定し直してください。")
        case .missingConnection: String(localized: "サービスに接続してください。")
        case .chooseSources: String(localized: "読み込むリストを選択してください。")
        case .missingArea: String(localized: "読み込み先の分野を選択してください。")
        case .busy: String(localized: "接続処理が終わるまでお待ちください。")
        }
    }
}

nonisolated struct ConnectorConnection: Codable, Equatable, Identifiable {
    var provider: ConnectorProviderID
    var account: ConnectorAccount
    var selectedSourceIDs: Set<String> = []
    var areaID: UUID?
    var lastSyncedAt: Date?
    var lastImportedCount: Int = 0
    var id: ConnectorProviderID { provider }
}

#if os(macOS) || os(iOS)
import Combine
import SwiftData

@MainActor
protocol ConnectorAuthorizing {
    func authorize(using browser: any ConnectorWebAuthenticating) async throws -> ConnectorCredentials
    func refresh(_ credentials: ConnectorCredentials) async throws -> ConnectorCredentials
}

extension TodoistAuthorization: ConnectorAuthorizing {}

@MainActor
final class ConnectorStore: ObservableObject {
    let toggl = TogglExportStore()
    @Published private(set) var connections: [ConnectorConnection] = []
    @Published private(set) var sources: [ConnectorProviderID: [ConnectorSource]] = [:]
    @Published private(set) var busyProvider: ConnectorProviderID?
    @Published var errorMessage: String?

    private let defaults: UserDefaults
    private let credentials: any ConnectorCredentialStorage
    private let authorization: any ConnectorAuthorizing
    private let browser: any ConnectorWebAuthenticating
    private let clientFactory: ((ConnectorProviderID, String?) -> any ConnectorClient)?
    private let disablesAutomaticSync: Bool
    private var lastAutomaticSync: Date?
    private var lastAutomaticOutbox: [UUID] = []
    private static let settingsKey = "connectors.connections.v1"

    init(
        defaults: UserDefaults? = nil,
        credentials: (any ConnectorCredentialStorage)? = nil,
        browser: (any ConnectorWebAuthenticating)? = nil,
        authorization: (any ConnectorAuthorizing)? = nil,
        clientFactory: ((ConnectorProviderID, String?) -> any ConnectorClient)? = nil
    ) {
        let process = ProcessInfo.processInfo
        let isolated = process.arguments.contains("--uitesting") ||
            process.arguments.contains("--onboarding-preview") ||
            process.environment["XCTestConfigurationFilePath"] != nil ||
            process.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        self.defaults = defaults ?? (isolated ? UserDefaults(suiteName: "connectors.preview.\(UUID())")! : .standard)
        self.credentials = credentials ?? (isolated ? InMemoryConnectorCredentials() : ConnectorKeychain())
        self.authorization = authorization ?? TodoistAuthorization()
        self.browser = browser ?? ConnectorWebAuthenticationFactory.make()
        self.clientFactory = clientFactory
        self.disablesAutomaticSync = isolated
        if let data = self.defaults.data(forKey: Self.settingsKey) {
            do {
                let decoded = try JSONDecoder().decode([ConnectorConnection].self, from: data)
                guard Set(decoded.map(\.provider)).count == decoded.count else { throw ConnectorStoreError.configuration }
                connections = decoded
            } catch { errorMessage = ConnectorStoreError.configuration.localizedDescription }
        }
    }

    func connection(for provider: ConnectorProviderID) -> ConnectorConnection? {
        connections.first { $0.provider == provider }
    }

    func connectReminders() async {
        await connect(provider: .reminders, newCredentials: nil)
    }

    // Also useful for local integration tests. Production UI uses OAuth.
    func connectTodoist(apiToken: String) async {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { errorMessage = ConnectorProviderError.invalidCredential.localizedDescription; return }
        await connect(provider: .todoist, newCredentials: ConnectorCredentials(accessToken: token, completionWriteAccess: true))
    }

    func authorizeTodoist() async {
        guard begin(.todoist) else { return }
        defer { busyProvider = nil }
        do {
            let token = try await authorization.authorize(using: browser)
            try Task.checkCancellation()
            try await finishConnection(provider: .todoist, newCredentials: token)
        } catch is CancellationError { }
        catch { present(error) }
    }

    func loadSources(for provider: ConnectorProviderID) async {
        guard begin(provider) else { return }
        defer { busyProvider = nil }
        do {
            let client = try await client(for: provider)
            let available = try await client.sources()
            try Task.checkCancellation()
            sources[provider] = available
        } catch is CancellationError { }
        catch { present(error) }
    }

    func configure(provider: ConnectorProviderID, sourceIDs: Set<String>, areaID: UUID) throws {
        guard busyProvider == nil else { throw ConnectorStoreError.busy }
        guard var connection = connection(for: provider) else { throw ConnectorStoreError.missingConnection }
        guard !sourceIDs.isEmpty else { throw ConnectorStoreError.chooseSources }
        guard let available = sources[provider], sourceIDs.isSubset(of: Set(available.map(\.id))) else {
            throw ConnectorProviderError.sourceUnavailable
        }
        connection.selectedSourceIDs = sourceIDs
        connection.areaID = areaID
        try replace(connection)
    }

    func disconnect(provider: ConnectorProviderID) throws {
        guard busyProvider == nil else { throw ConnectorStoreError.busy }
        try credentials.remove(for: provider)
        try persist(connections.filter { $0.provider != provider })
        sources.removeValue(forKey: provider)
        errorMessage = nil
    }

    func synchronize(provider: ConnectorProviderID, modelContext: ModelContext) async {
        guard begin(provider) else { return }
        defer { busyProvider = nil }
        do {
            guard var connection = connection(for: provider) else { throw ConnectorStoreError.missingConnection }
            guard !connection.selectedSourceIDs.isEmpty else { throw ConnectorStoreError.chooseSources }
            guard let areaID = connection.areaID else { throw ConnectorStoreError.missingArea }
            guard !modelContext.hasChanges else { throw ConnectorStoreError.busy }
            let client = try await client(for: provider)
            guard try await client.account().id == connection.account.id else {
                throw ConnectorProviderError.invalidCredential
            }
            let lookup = ModelContext(modelContext.container)
            let linked = try lookup.fetch(FetchDescriptor<Todo>()).filter {
                !$0.isDeleted && !$0.isArchived &&
                    $0.externalTaskLink?.provider == provider &&
                    $0.externalTaskLink?.accountID == connection.account.id &&
                    $0.externalTaskLink?.supersededByTodoID == nil
            }
            try await sendPendingCompletions(
                client: client, connection: connection, todos: linked,
                modelContext: modelContext
            )
            let refreshStartedAt = Date.now
            let activeTasks = try await client.tasks(sourceIDs: connection.selectedSourceIDs)
            let completedSince = connection.lastSyncedAt
                ?? linked.compactMap { $0.externalTaskLink?.lastSyncedAt }.min()
            let completedTasks: [ConnectorTask]
            if let completedSince {
                completedTasks = try await client.completedTasks(
                    sourceIDs: connection.selectedSourceIDs,
                    since: completedSince.addingTimeInterval(-60), until: refreshStartedAt
                )
            } else { completedTasks = [] }
            // A reopened/recurring active item wins over its older completion record.
            let tasks = activeTasks + completedTasks
            try Task.checkCancellation()
            guard !modelContext.hasChanges else { throw ConnectorStoreError.busy }
            // Keep importer rollback isolated from an open Task/Flow editor.
            let context = ModelContext(modelContext.container)
            let descriptor = FetchDescriptor<Area>(predicate: #Predicate { $0.id == areaID })
            guard let area = try context.fetch(descriptor).first else { throw ConnectorStoreError.missingArea }
            let now = Date.now
            let result = try ConnectorTaskImporter().importTasks(
                tasks, provider: provider, accountID: connection.account.id,
                area: area, modelContext: context, now: now
            )
            connection.lastSyncedAt = refreshStartedAt
            connection.lastImportedCount = result.inserted
            try replace(connection)
        } catch is CancellationError { }
        catch { present(error) }
    }

    func synchronizeConfigured(modelContext: ModelContext) async {
        await ConnectorKeychainInteraction.$allowed.withValue(false) {
            await synchronizeConfiguredWithoutInteraction(modelContext: modelContext)
        }
    }

    private func synchronizeConfiguredWithoutInteraction(modelContext: ModelContext) async {
        guard !disablesAutomaticSync, busyProvider == nil, !modelContext.hasChanges else { return }
        let readContext = ModelContext(modelContext.container)
        let outbox = (try? readContext.fetch(FetchDescriptor<Todo>()))?.filter {
            !$0.isDeleted && !$0.isArchived && $0.measurement == .checkbox
        }.flatMap { $0.externalTaskLink?.completionChanges ?? [] }
            .map(\.id).sorted { $0.uuidString < $1.uuidString } ?? []
        guard outbox != lastAutomaticOutbox ||
                (lastAutomaticSync.map({ Date.now.timeIntervalSince($0) >= 60 }) ?? true) else { return }
        lastAutomaticSync = .now
        lastAutomaticOutbox = outbox
        let configured = connections.filter { $0.areaID != nil && !$0.selectedSourceIDs.isEmpty }
        // Foreground refresh keeps failures on the connection screen rather than interrupting Flow.
        var firstError: String?
        for connection in configured {
            guard !Task.isCancelled else { break }
            await synchronize(provider: connection.provider, modelContext: modelContext)
            if firstError == nil { firstError = errorMessage }
        }
        if let firstError { errorMessage = firstError }
    }

    /// Scene-scoped polling drains newly saved checkbox changes promptly and
    /// stops on background/cancellation. Read-only refresh remains throttled.
    func runForegroundSync(modelContext: ModelContext) async {
        guard !disablesAutomaticSync else { return }
        while !Task.isCancelled {
            await synchronizeConfigured(modelContext: modelContext)
            await toggl.automaticSync(modelContext: modelContext)
            do { try await Task.sleep(for: .seconds(5)) }
            catch { return }
        }
    }

    private func sendPendingCompletions(
        client: any ConnectorClient, connection: ConnectorConnection,
        todos: [Todo], modelContext: ModelContext
    ) async throws {
        for todo in todos where todo.measurement == .checkbox {
            guard let link = todo.externalTaskLink,
                  connection.selectedSourceIDs.contains(link.sourceID) else { continue }
            for change in link.completionChanges ?? [] {
                try Task.checkCancellation()
                guard !modelContext.hasChanges else { throw ConnectorStoreError.busy }
                let pendingContext = ModelContext(modelContext.container)
                let pendingID = todo.id
                let pendingDescriptor = FetchDescriptor<Todo>(predicate: #Predicate { $0.id == pendingID })
                guard let pending = try pendingContext.fetch(pendingDescriptor).first,
                      !pending.isDeleted, !pending.isArchived, pending.measurement == .checkbox,
                      let pendingLink = pending.externalTaskLink,
                      pendingLink.identity == link.identity,
                      pendingLink.supersededByTodoID == nil,
                      pendingLink.completionChanges?.contains(where: { $0.id == change.id }) == true,
                      pendingLink.acknowledgedCompletionIDs?.contains(change.id) != true else { continue }
                if connection.provider == .todoist,
                   try credentials.read(for: .todoist)?.completionWriteAccess != true {
                    throw TodoistAuthorizationError.reconnect
                }
                try await client.setCompletion(
                    taskID: link.taskID, sourceIDs: connection.selectedSourceIDs, change: change
                )
                try Task.checkCancellation()
                guard !modelContext.hasChanges else { throw ConnectorStoreError.busy }
                // Re-read after await: a user may have queued a newer toggle.
                let acknowledgement = ModelContext(modelContext.container)
                let id = todo.id
                let descriptor = FetchDescriptor<Todo>(predicate: #Predicate { $0.id == id })
                guard let current = try acknowledgement.fetch(descriptor).first,
                      var currentLink = current.externalTaskLink,
                      currentLink.identity == link.identity else { continue }
                currentLink.completionChanges = (currentLink.completionChanges ?? []).filter { $0.id != change.id }
                var acknowledged = currentLink.acknowledgedCompletionIDs ?? []
                if !acknowledged.contains(change.id) { acknowledged.append(change.id) }
                currentLink.acknowledgedCompletionIDs = acknowledged
                currentLink.remoteCompletion = change.isCompleted
                current.externalTaskLinkRawValue = try currentLink.encoded()
                current.updatedAt = .now
                try acknowledgement.save()
            }
        }
    }

    private func connect(provider: ConnectorProviderID, newCredentials: ConnectorCredentials?) async {
        guard begin(provider) else { return }
        defer { busyProvider = nil }
        do { try await finishConnection(provider: provider, newCredentials: newCredentials) }
        catch is CancellationError { }
        catch { present(error) }
    }

    private func finishConnection(provider: ConnectorProviderID, newCredentials: ConnectorCredentials?) async throws {
        let client = try makeClient(provider: provider, accessToken: newCredentials?.accessToken)
        let account = try await client.account()
        let available = try await client.sources()
        try Task.checkCancellation()
        if let newCredentials { try credentials.save(newCredentials, for: provider) }
        var connection = connection(for: provider).flatMap { $0.account.id == account.id ? $0 : nil }
            ?? ConnectorConnection(provider: provider, account: account)
        connection.account = account
        try replace(connection)
        sources[provider] = available
    }

    private func client(for provider: ConnectorProviderID) async throws -> any ConnectorClient {
        guard connection(for: provider) != nil else { throw ConnectorStoreError.missingConnection }
        if provider == .reminders { return try makeClient(provider: provider, accessToken: nil) }
        guard var token = try credentials.read(for: provider) else { throw TodoistAuthorizationError.reconnect }
        if token.needsRefresh(at: .now) {
            guard token.refreshToken?.isEmpty == false else { throw TodoistAuthorizationError.reconnect }
            try Task.checkCancellation()
            // Todoist consumes the refresh token on successful rotation. Reserve it
            // before dispatch so a lost response, process exit, cancellation, or
            // failed replacement save can never replay it after the grace window.
            var pending = token
            pending.refreshToken = nil
            try credentials.save(pending, for: provider)
            let previousWriteAccess = token.completionWriteAccess
            token = try await authorization.refresh(token)
            token.completionWriteAccess = previousWriteAccess
            // Persist the replacement before any provider API read.
            try credentials.save(token, for: provider)
        }
        return try makeClient(provider: provider, accessToken: token.accessToken)
    }

    private func makeClient(provider: ConnectorProviderID, accessToken: String?) throws -> any ConnectorClient {
        if let clientFactory { return clientFactory(provider, accessToken) }
        switch provider {
        case .reminders: return RemindersConnectorClient()
        case .todoist: return TodoistConnectorClient(accessToken: accessToken ?? "")
        case .toggl: throw ConnectorStoreError.configuration // Time export uses TogglExportStore.
        }
    }

    private func begin(_ provider: ConnectorProviderID) -> Bool {
        guard busyProvider == nil else { return false }
        errorMessage = nil
        busyProvider = provider
        return true
    }

    private func replace(_ connection: ConnectorConnection) throws {
        var updated = connections.filter { $0.provider != connection.provider }
        updated.append(connection)
        updated.sort { $0.provider.rawValue < $1.provider.rawValue }
        try persist(updated)
    }

    private func persist(_ updated: [ConnectorConnection]) throws {
        let data = try JSONEncoder().encode(updated)
        defaults.set(data, forKey: Self.settingsKey)
        connections = updated
    }

    private func present(_ error: any Error) {
        // Provider/authorization errors are sanitized and never contain request bodies or tokens.
        if error is ConnectorProviderError || error is ConnectorStoreError || error is TodoistAuthorizationError || error is ConnectorImportError {
            errorMessage = error.localizedDescription
        } else {
            errorMessage = String(localized: "接続を更新できませんでした。通信状態と接続設定を確認してください。")
        }
    }
}
#endif
