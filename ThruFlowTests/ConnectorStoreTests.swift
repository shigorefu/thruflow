import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@Suite(.serialized)
@MainActor
struct ConnectorStoreTests {
    @Test func legacySourceSelectionResolvesWithoutLosingLists() throws {
        let areaID = UUID()
        let legacy: [String: Any] = [
            "provider": "reminders", "account": ["id": "local", "name": "Reminders"],
            "selectedSourceIDs": ["work", "home"], "areaID": areaID.uuidString,
            "lastImportedCount": 0
        ]
        let connection = try JSONDecoder().decode(ConnectorConnection.self,
            from: JSONSerialization.data(withJSONObject: legacy))
        #expect(connection.sourceAreaIDs == nil)
        #expect(connection.resolvedSourceAreaIDs == ["work": areaID, "home": areaID])
    }

    @Test func mappedSourcesRouteNewTasksAndPreserveExistingLocalArea() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        fixture.client.currentSources.append(ConnectorSource(id: "list-b", name: "家"))
        await fixture.store.connectTodoist(apiToken: "token")
        let container = try makeContainer()
        let context = container.mainContext
        let work = Area(name: "Work", type: .neutral)
        let home = Area(name: "Home", type: .nice)
        context.insert(work)
        context.insert(home)
        try context.save()
        let mappings = ["list-a": work.id, "list-b": home.id]
        try fixture.store.configure(provider: .todoist, sourceAreaIDs: mappings)
        let restored = restoredStore(from: fixture, authorization: MockAuthorization())
        #expect(restored.connection(for: .todoist)?.resolvedSourceAreaIDs == mappings)
        fixture.client.currentTasks = [
            ConnectorTask(id: "a", sourceID: "list-a", title: "Work task"),
            ConnectorTask(id: "b", sourceID: "list-b", title: "Home task")
        ]
        await restored.synchronize(provider: .todoist, modelContext: context)
        #expect(restored.errorMessage == nil)
        var saved = try ModelContext(container).fetch(FetchDescriptor<Todo>())
        #expect(saved.first { $0.externalTaskLink?.taskID == "a" }?.area?.id == work.id)
        #expect(saved.first { $0.externalTaskLink?.taskID == "b" }?.area?.id == home.id)
        #expect(restored.connection(for: .todoist)?.lastImportedCount == 2)

        try fixture.store.configure(provider: .todoist, sourceAreaIDs: ["list-a": home.id, "list-b": home.id])
        fixture.client.currentTasks.append(ConnectorTask(id: "c", sourceID: "list-a", title: "New home task"))
        await fixture.store.synchronize(provider: .todoist, modelContext: context)
        saved = try ModelContext(container).fetch(FetchDescriptor<Todo>())
        #expect(saved.count == 3)
        #expect(saved.first { $0.externalTaskLink?.taskID == "a" }?.area?.id == work.id)
        #expect(saved.first { $0.externalTaskLink?.taskID == "c" }?.area?.id == home.id)
        try fixture.store.configure(provider: .todoist, sourceAreaIDs: [:])
        let cleared = restoredStore(from: fixture, authorization: MockAuthorization())
        #expect(cleared.connection(for: .todoist)?.resolvedSourceAreaIDs.isEmpty == true)
        #expect(cleared.connection(for: .todoist)?.selectedSourceIDs.isEmpty == true)
    }

    @Test func mappingRejectsUnknownSourcesWithoutReplacingSavedSelection() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        await fixture.store.connectTodoist(apiToken: "token")
        let mappings = ["list-a": UUID()]
        try fixture.store.configure(provider: .todoist, sourceAreaIDs: mappings)
        #expect(throws: ConnectorProviderError.self) {
            try fixture.store.configure(provider: .todoist, sourceAreaIDs: ["missing": UUID()])
        }
        #expect(fixture.store.connection(for: .todoist)?.resolvedSourceAreaIDs == mappings)
    }

    @Test func completionOutboxSurvivesFailureAndRetriesTheSameCommand() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "Work", type: .neutral)
        context.insert(area)
        try context.save()
        await fixture.store.connectTodoist(apiToken: "token")
        try fixture.store.configure(provider: .todoist, sourceIDs: ["list-a"], areaID: area.id)
        fixture.client.currentTasks = [ConnectorTask(id: "task-a", sourceID: "list-a", title: "Imported")]
        await fixture.store.synchronize(provider: .todoist, modelContext: context)
        let todo = try #require(context.fetch(FetchDescriptor<Todo>()).first)
        todo.setCompleted(true)
        try context.save()
        let change = try #require(todo.externalTaskLink?.completionChanges?.first)
        fixture.client.completionError = .networkUnavailable
        await fixture.store.synchronize(provider: .todoist, modelContext: context)
        let afterFailure = try #require(ModelContext(container).fetch(FetchDescriptor<Todo>()).first)
        #expect(afterFailure.externalTaskLink?.completionChanges == [change])
        #expect(fixture.store.errorMessage != nil)
        fixture.client.completionError = nil
        await fixture.store.synchronize(provider: .todoist, modelContext: context)
        let afterSuccess = try #require(ModelContext(container).fetch(FetchDescriptor<Todo>()).first)
        #expect(afterSuccess.isCompleted)
        #expect(afterSuccess.externalTaskLink?.completionChanges?.isEmpty == true)
        #expect(fixture.client.sentChanges.map(\.id) == [change.id, change.id])
        #expect(fixture.store.errorMessage == nil)
    }

    @Test func anInFlightCompletionDoesNotEraseANewerReopening() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "Work", type: .neutral)
        context.insert(area)
        try context.save()
        await fixture.store.connectTodoist(apiToken: "token")
        try fixture.store.configure(provider: .todoist, sourceIDs: ["list-a"], areaID: area.id)
        fixture.client.currentTasks = [ConnectorTask(id: "task-a", sourceID: "list-a", title: "Imported")]
        await fixture.store.synchronize(provider: .todoist, modelContext: context)
        let todo = try #require(context.fetch(FetchDescriptor<Todo>()).first)
        todo.setCompleted(true)
        try context.save()
        fixture.client.onCompletion = {
            todo.setCompleted(false)
            try context.save()
        }
        await fixture.store.synchronize(provider: .todoist, modelContext: context)
        let pending = try #require(ModelContext(container).fetch(FetchDescriptor<Todo>()).first)
        #expect(!pending.isCompleted)
        #expect(pending.externalTaskLink?.completionChanges?.map(\.isCompleted) == [false])
        fixture.client.onCompletion = nil
        await fixture.store.synchronize(provider: .todoist, modelContext: context)
        let finished = try #require(ModelContext(container).fetch(FetchDescriptor<Todo>()).first)
        #expect(!finished.isCompleted)
        #expect(finished.externalTaskLink?.completionChanges?.isEmpty == true)
        #expect(fixture.client.sentChanges.map(\.isCompleted) == [true, false])
    }

    @Test func anOldReadOnlyCredentialCannotSendQueuedCompletion() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "Work", type: .neutral)
        context.insert(area)
        try context.save()
        await fixture.store.connectTodoist(apiToken: "token")
        try fixture.store.configure(provider: .todoist, sourceIDs: ["list-a"], areaID: area.id)
        fixture.client.currentTasks = [ConnectorTask(id: "task-a", sourceID: "list-a", title: "Imported")]
        await fixture.store.synchronize(provider: .todoist, modelContext: context)
        let todo = try #require(context.fetch(FetchDescriptor<Todo>()).first)
        todo.setCompleted(true)
        try context.save()
        fixture.vault.values[.todoist]?.completionWriteAccess = nil
        await fixture.store.synchronize(provider: .todoist, modelContext: context)
        #expect(fixture.client.sentChanges.isEmpty)
        #expect(fixture.store.errorMessage == TodoistAuthorizationError.reconnect.localizedDescription)
    }

    @Test func changedProviderAccountCannotReceiveAnotherAccountsOutbox() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "Work", type: .neutral)
        context.insert(area)
        try context.save()
        await fixture.store.connectTodoist(apiToken: "token")
        try fixture.store.configure(provider: .todoist, sourceIDs: ["list-a"], areaID: area.id)
        fixture.client.currentTasks = [ConnectorTask(id: "task-a", sourceID: "list-a", title: "Imported")]
        await fixture.store.synchronize(provider: .todoist, modelContext: context)
        let todo = try #require(context.fetch(FetchDescriptor<Todo>()).first)
        todo.setCompleted(true)
        try context.save()
        fixture.client.currentAccount = ConnectorAccount(id: "different-account", name: "Other")
        await fixture.store.synchronize(provider: .todoist, modelContext: context)
        #expect(fixture.client.sentChanges.isEmpty)
        #expect(fixture.store.errorMessage == ConnectorProviderError.invalidCredential.localizedDescription)
        let persisted = try #require(ModelContext(container).fetch(FetchDescriptor<Todo>()).first)
        #expect(persisted.externalTaskLink?.completionChanges?.count == 1)
    }

    @Test func connectionPersistsOnlyMetadataWhileCredentialsStayInInjectedVault() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        await fixture.store.connectTodoist(apiToken: "  test-secret-token  ")

        let connection = try #require(fixture.store.connection(for: .todoist))
        let data = try #require(fixture.defaults.data(forKey: settingsKey))
        let settingsText = String(decoding: data, as: UTF8.self)
        #expect(connection.account.id == "account-a")
        #expect(fixture.vault.values[.todoist]?.accessToken == "test-secret-token")
        #expect(settingsText.contains("account-a"))
        #expect(!settingsText.contains("test-secret-token"))
        #expect(!settingsText.contains("accessToken"))
        #expect(fixture.store.errorMessage == nil)
        #expect(fixture.store.busyProvider == nil)
    }

    @Test func failedAccountLookupPreservesExistingAccountSettingsAndCredential() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        await fixture.store.connectTodoist(apiToken: "original-token")
        let areaID = UUID()
        try fixture.store.configure(provider: .todoist, sourceIDs: ["list-a"], areaID: areaID)
        let original = fixture.store.connection(for: .todoist)
        let originalData = fixture.defaults.data(forKey: settingsKey)
        fixture.client.accountError = ConnectorProviderError.invalidCredential

        await fixture.store.connectTodoist(apiToken: "rejected-token")

        #expect(fixture.store.connection(for: .todoist) == original)
        #expect(fixture.defaults.data(forKey: settingsKey) == originalData)
        #expect(fixture.vault.values[.todoist]?.accessToken == "original-token")
        #expect(fixture.store.errorMessage != nil)
        #expect(fixture.store.errorMessage?.contains("rejected-token") == false)
        #expect(fixture.store.busyProvider == nil)
    }

    @Test func failedSourceLookupDoesNotReplaceWorkingAccountOrCredential() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        await fixture.store.connectTodoist(apiToken: "original-token")
        let original = fixture.store.connection(for: .todoist)
        fixture.client.currentAccount = ConnectorAccount(id: "account-b", name: "Second account")
        fixture.client.sourcesError = ConnectorProviderError.serviceUnavailable

        await fixture.store.connectTodoist(apiToken: "new-token")

        #expect(fixture.store.connection(for: .todoist) == original)
        #expect(fixture.vault.values[.todoist]?.accessToken == "original-token")
        #expect(fixture.store.sources[.todoist] == [ConnectorSource(id: "list-a", name: "仕事")])
        #expect(fixture.store.errorMessage != nil)
    }

    @Test func rejectedKeychainWriteDoesNotPublishNewConnection() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        fixture.vault.saveError = ConnectorStoreError.keychain

        await fixture.store.connectTodoist(apiToken: "unsaved-token")

        #expect(fixture.store.connections.isEmpty)
        #expect(fixture.vault.values.isEmpty)
        #expect(fixture.defaults.data(forKey: settingsKey) == nil)
        #expect(fixture.store.errorMessage == ConnectorStoreError.keychain.localizedDescription)
        #expect(fixture.store.busyProvider == nil)
    }

    @Test func reconnectingSameAccountRetainsMappingWhileSwitchingAccountResetsIt() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        await fixture.store.connectTodoist(apiToken: "first-token")
        let areaID = UUID()
        try fixture.store.configure(provider: .todoist, sourceIDs: ["list-a"], areaID: areaID)
        fixture.client.currentAccount = ConnectorAccount(id: "account-a", name: "Renamed account")

        await fixture.store.connectTodoist(apiToken: "replacement-token")
        #expect(fixture.store.connection(for: .todoist)?.areaID == areaID)
        #expect(fixture.store.connection(for: .todoist)?.selectedSourceIDs == ["list-a"])
        #expect(fixture.store.connection(for: .todoist)?.account.name == "Renamed account")

        fixture.client.currentAccount = ConnectorAccount(id: "account-b", name: "Second account")
        await fixture.store.connectTodoist(apiToken: "second-account-token")
        let second = try #require(fixture.store.connection(for: .todoist))
        #expect(second.account.id == "account-b")
        #expect(second.areaID == nil)
        #expect(second.selectedSourceIDs.isEmpty)
        #expect(second.lastSyncedAt == nil)
        #expect(second.lastImportedCount == 0)
        #expect(fixture.vault.values[.todoist]?.accessToken == "second-account-token")
    }

    @Test func failedImportKeepsLastSuccessAndDoesNotRollbackOpenEditor() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "仕事", type: .neutral)
        context.insert(area)
        try context.save()
        await fixture.store.connectTodoist(apiToken: "token")
        try fixture.store.configure(provider: .todoist, sourceIDs: ["list-a"], areaID: area.id)
        fixture.client.currentTasks = [ConnectorTask(id: "task-a", sourceID: "list-a", title: "外部タスク")]
        await fixture.store.synchronize(provider: .todoist, modelContext: context)
        let successful = try #require(fixture.store.connection(for: .todoist))
        #expect(successful.lastSyncedAt != nil)
        #expect(successful.lastImportedCount == 1)
        #expect(fixture.store.errorMessage == nil)

        let malformed = Todo(title: "壊れた識別情報", area: area)
        malformed.externalTaskLinkRawValue = "broken-json"
        context.insert(malformed)
        let draft = Todo(title: "編集前", area: area)
        context.insert(draft)
        try context.save()
        draft.title = "保存前の編集中テキスト"
        fixture.client.currentTasks = [ConnectorTask(id: "task-b", sourceID: "list-a", title: "新しい外部タスク")]

        await fixture.store.synchronize(provider: .todoist, modelContext: context)

        #expect(fixture.store.connection(for: .todoist)?.lastSyncedAt == successful.lastSyncedAt)
        #expect(fixture.store.connection(for: .todoist)?.lastImportedCount == 1)
        #expect(fixture.store.errorMessage != nil)
        #expect(draft.title == "保存前の編集中テキスト")
        #expect(context.hasChanges)
        let persisted = try ModelContext(container).fetch(FetchDescriptor<Todo>())
        #expect(persisted.count == 3)
        #expect(!persisted.contains { $0.externalTaskLink?.taskID == "task-b" })
    }

    @Test func failedProviderReadDoesNotSetSuccessfulImportTimestamp() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "仕事", type: .neutral)
        context.insert(area)
        try context.save()
        await fixture.store.connectTodoist(apiToken: "token")
        try fixture.store.configure(provider: .todoist, sourceIDs: ["list-a"], areaID: area.id)
        fixture.client.tasksError = ConnectorProviderError.networkUnavailable

        await fixture.store.synchronize(provider: .todoist, modelContext: context)

        #expect(fixture.store.connection(for: .todoist)?.lastSyncedAt == nil)
        #expect(fixture.store.connection(for: .todoist)?.lastImportedCount == 0)
        #expect(try context.fetchCount(FetchDescriptor<Todo>()) == 0)
        #expect(fixture.store.errorMessage == ConnectorProviderError.networkUnavailable.localizedDescription)
    }

    @Test func disconnectClearsLocalConnectionAndCredentialButPreservesTaskAndFlow() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "仕事", type: .neutral)
        context.insert(area)
        try context.save()
        await fixture.store.connectTodoist(apiToken: "token")
        try fixture.store.configure(provider: .todoist, sourceIDs: ["list-a"], areaID: area.id)
        fixture.client.currentTasks = [ConnectorTask(id: "task-a", sourceID: "list-a", title: "外部タスク")]
        await fixture.store.synchronize(provider: .todoist, modelContext: context)
        let todo = try #require(context.fetch(FetchDescriptor<Todo>()).first)
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let session = FlowSession(
            area: area, todo: todo, mode: .twentyFiveFive,
            phase: .completed, status: .completed, startedAt: startedAt,
            plannedEndAt: startedAt.addingTimeInterval(1500),
            endedAt: startedAt.addingTimeInterval(1500),
            plannedFocusDurationSeconds: 1500, actualFocusDurationSeconds: 1500,
            plannedBreakDurationSeconds: 300
        )
        context.insert(session)
        try context.save()

        try fixture.store.disconnect(provider: .todoist)

        #expect(fixture.store.connection(for: .todoist) == nil)
        #expect(fixture.store.sources[.todoist] == nil)
        #expect(fixture.vault.values[.todoist] == nil)
        #expect(try context.fetchCount(FetchDescriptor<Todo>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<FlowSession>()) == 1)
        #expect(!todo.isDeleted)
        #expect(todo.externalTaskLink?.taskID == "task-a")
        #expect(session.todo?.id == todo.id)
        #expect(session.resolvedActualFocusDurationSeconds == 1500)
    }

    @Test func failedCredentialRemovalLeavesConnectionReviewable() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        await fixture.store.connectTodoist(apiToken: "token")
        let original = fixture.store.connection(for: .todoist)
        fixture.vault.removeError = ConnectorStoreError.keychain

        #expect(throws: ConnectorStoreError.self) {
            try fixture.store.disconnect(provider: .todoist)
        }

        #expect(fixture.store.connection(for: .todoist) == original)
        #expect(fixture.vault.values[.todoist]?.accessToken == "token")
    }

    @Test func restoredMetadataWithoutDeviceCredentialRequiresReconnect() async throws {
        let connection = ConnectorConnection(provider: .todoist, account: ConnectorAccount(id: "account-a", name: "Account"))
        let fixture = try makeFixture(connections: [connection])
        defer { fixture.cleanUp() }

        await fixture.store.loadSources(for: .todoist)

        #expect(fixture.store.connection(for: .todoist) == connection)
        #expect(fixture.store.sources[.todoist] == nil)
        #expect(fixture.store.errorMessage == TodoistAuthorizationError.reconnect.localizedDescription)
        #expect(fixture.client.sourceReadCount == 0)
    }

    @Test func remindersConnectionNeverRequestsOrStoresAnAPIToken() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        fixture.client.currentAccount = ConnectorAccount(id: "eventkit", name: "Apple Reminders")

        await fixture.store.connectReminders()

        #expect(fixture.store.connection(for: .reminders)?.account.id == "eventkit")
        #expect(fixture.vault.values.isEmpty)
        #expect(fixture.store.errorMessage == nil)
    }

    @Test func cancelledBrowserAuthorizationLeavesExistingConnectionUntouched() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        await fixture.store.connectTodoist(apiToken: "existing-token")
        let original = fixture.store.connection(for: .todoist)

        await fixture.store.authorizeTodoist()

        #expect(fixture.browser.requestCount == 1)
        #expect(fixture.store.connection(for: .todoist) == original)
        #expect(fixture.vault.values[.todoist]?.accessToken == "existing-token")
        #expect(fixture.store.errorMessage == nil)
        #expect(fixture.store.busyProvider == nil)
    }

    @Test func configurationRejectsUnselectedOrUnavailableLists() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        await fixture.store.connectTodoist(apiToken: "token")
        let areaID = UUID()

        #expect(throws: ConnectorStoreError.self) {
            try fixture.store.configure(provider: .todoist, sourceIDs: [], areaID: areaID)
        }
        #expect(throws: ConnectorProviderError.self) {
            try fixture.store.configure(provider: .todoist, sourceIDs: ["missing"], areaID: areaID)
        }
        #expect(fixture.store.connection(for: .todoist)?.selectedSourceIDs.isEmpty == true)
        #expect(fixture.store.connection(for: .todoist)?.areaID == nil)
    }

    @Test func refreshReservesTokenBeforeDispatchAndSavesReplacementBeforeProviderRead() async throws {
        let authorization = MockAuthorization()
        let fixture = try makeRefreshFixture(authorization: authorization)
        defer { authorization.onRefresh = nil; fixture.cleanUp() }
        var order: [String] = []
        fixture.vault.onSaved = { credentials in
            order.append(credentials.refreshToken == nil ? "reserve" : "replace")
        }
        authorization.onRefresh = { original in
            order.append("refresh")
            #expect(original.refreshToken == "old-refresh")
            #expect(fixture.vault.values[.todoist]?.refreshToken == nil)
            #expect(fixture.vault.values[.todoist]?.accessToken == "old-access")
        }
        fixture.client.onSourceRead = {
            order.append("read")
            #expect(fixture.vault.values[.todoist]?.refreshToken == "rotated-refresh")
        }

        await fixture.store.loadSources(for: .todoist)

        #expect(order == ["reserve", "refresh", "replace", "read"])
        #expect(authorization.refreshCount == 1)
        #expect(fixture.vault.values[.todoist]?.accessToken == "new-access")
        #expect(fixture.vault.values[.todoist]?.refreshToken == "rotated-refresh")
        #expect(fixture.client.accessTokens == ["new-access"])
        #expect(fixture.store.errorMessage == nil)
    }

    @Test func failedRefreshReservationNeverDispatchesOrConsumesCredential() async throws {
        let authorization = MockAuthorization()
        let fixture = try makeRefreshFixture(authorization: authorization)
        defer { authorization.onRefresh = nil; fixture.cleanUp() }
        let original = fixture.vault.values[.todoist]
        fixture.vault.saveError = ConnectorStoreError.keychain

        await fixture.store.loadSources(for: .todoist)

        #expect(authorization.refreshCount == 0)
        #expect(fixture.vault.values[.todoist] == original)
        #expect(fixture.client.sourceReadCount == 0)
        #expect(fixture.store.errorMessage == ConnectorStoreError.keychain.localizedDescription)
    }

    @Test func lostRefreshResponseCannotReplayTokenAfterStoreRestoration() async throws {
        let authorization = MockAuthorization()
        authorization.refreshError = URLError(.networkConnectionLost)
        let fixture = try makeRefreshFixture(authorization: authorization)
        defer { authorization.onRefresh = nil; fixture.cleanUp() }

        await fixture.store.loadSources(for: .todoist)

        #expect(authorization.refreshCount == 1)
        #expect(fixture.vault.values[.todoist]?.refreshToken == nil)
        #expect(fixture.client.sourceReadCount == 0)
        #expect(fixture.store.errorMessage != nil)
        let restored = restoredStore(from: fixture, authorization: authorization)
        await restored.loadSources(for: .todoist)
        #expect(authorization.refreshCount == 1)
        #expect(restored.errorMessage == TodoistAuthorizationError.reconnect.localizedDescription)
        #expect(restored.connection(for: .todoist) == fixture.store.connection(for: .todoist))
    }

    @Test func cancelledRefreshCannotReplayTokenAfterStoreRestoration() async throws {
        let authorization = MockAuthorization()
        let fixture = try makeRefreshFixture(authorization: authorization)
        defer { authorization.onRefresh = nil; fixture.cleanUp() }
        authorization.onRefresh = { _ in
            #expect(fixture.vault.values[.todoist]?.refreshToken == nil)
            withUnsafeCurrentTask { $0?.cancel() }
            try Task.checkCancellation()
        }

        let operation = Task { @MainActor in
            await fixture.store.loadSources(for: .todoist)
        }
        await operation.value

        #expect(operation.isCancelled)
        #expect(authorization.refreshCount == 1)
        #expect(fixture.vault.values[.todoist]?.refreshToken == nil)
        #expect(fixture.client.sourceReadCount == 0)
        #expect(fixture.store.busyProvider == nil)
        #expect(fixture.store.errorMessage == nil)
        let restored = restoredStore(from: fixture, authorization: authorization)
        await restored.loadSources(for: .todoist)
        #expect(authorization.refreshCount == 1)
        #expect(restored.errorMessage == TodoistAuthorizationError.reconnect.localizedDescription)
    }

    @Test func failedReplacementSaveCannotReplayConsumedRefreshToken() async throws {
        let authorization = MockAuthorization()
        let fixture = try makeRefreshFixture(authorization: authorization)
        defer { authorization.onRefresh = nil; fixture.cleanUp() }
        fixture.vault.failOnSaveAttempt = 2

        await fixture.store.loadSources(for: .todoist)

        #expect(fixture.vault.saveAttemptCount == 2)
        #expect(authorization.refreshCount == 1)
        #expect(fixture.vault.values[.todoist]?.refreshToken == nil)
        #expect(fixture.vault.values[.todoist]?.accessToken == "old-access")
        #expect(fixture.client.sourceReadCount == 0)
        #expect(fixture.store.errorMessage == ConnectorStoreError.keychain.localizedDescription)
        let restored = restoredStore(from: fixture, authorization: authorization)
        await restored.loadSources(for: .todoist)
        #expect(authorization.refreshCount == 1)
        #expect(restored.errorMessage == TodoistAuthorizationError.reconnect.localizedDescription)
    }

    @Test func cancellationBeforeRefreshKeepsUnusedTokenAndDoesNotDispatch() async throws {
        let authorization = MockAuthorization()
        let fixture = try makeRefreshFixture(authorization: authorization)
        defer { authorization.onRefresh = nil; fixture.cleanUp() }
        let original = fixture.vault.values[.todoist]

        let operation = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            await fixture.store.loadSources(for: .todoist)
        }
        await operation.value

        #expect(authorization.refreshCount == 0)
        #expect(fixture.vault.saveAttemptCount == 0)
        #expect(fixture.vault.values[.todoist] == original)
        #expect(fixture.client.sourceReadCount == 0)
        #expect(fixture.store.errorMessage == nil)
    }

    private func makeRefreshFixture(authorization: MockAuthorization) throws -> Fixture {
        let connection = ConnectorConnection(
            provider: .todoist,
            account: ConnectorAccount(id: "account-a", name: "Account")
        )
        let fixture = try makeFixture(connections: [connection], authorization: authorization)
        fixture.vault.values[.todoist] = ConnectorCredentials(
            accessToken: "old-access", refreshToken: "old-refresh", expiresAt: .distantPast
        )
        return fixture
    }

    private func restoredStore(from fixture: Fixture, authorization: MockAuthorization) -> ConnectorStore {
        ConnectorStore(
            defaults: fixture.defaults, credentials: fixture.vault,
            browser: fixture.browser, authorization: authorization,
            clientFactory: { _, token in
                fixture.client.accessTokens.append(token)
                return fixture.client
            }
        )
    }

    private let settingsKey = "connectors.connections.v1"

    private func makeFixture(connections: [ConnectorConnection] = [], authorization: (any ConnectorAuthorizing)? = nil) throws -> Fixture {
        let suiteName = "ConnectorStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        if !connections.isEmpty {
            defaults.set(try JSONEncoder().encode(connections), forKey: settingsKey)
        }
        let vault = MockCredentialStorage()
        let client = MockConnectorClient()
        let browser = CancelledBrowser()
        let store = ConnectorStore(
            defaults: defaults, credentials: vault, browser: browser, authorization: authorization,
            clientFactory: { _, token in
                client.accessTokens.append(token)
                return client
            }
        )
        return Fixture(suiteName: suiteName, defaults: defaults, vault: vault, client: client, browser: browser, store: store)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = AppModelContainerFactory.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        container.mainContext.autosaveEnabled = false
        return container
    }

    @MainActor
    private struct Fixture {
        let suiteName: String
        let defaults: UserDefaults
        let vault: MockCredentialStorage
        let client: MockConnectorClient
        let browser: CancelledBrowser
        let store: ConnectorStore

        func cleanUp() {
            vault.onSaved = nil
            client.onSourceRead = nil
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    @MainActor
    private final class MockConnectorClient: ConnectorClient {
        var currentAccount = ConnectorAccount(id: "account-a", name: "Account")
        var currentSources = [ConnectorSource(id: "list-a", name: "仕事")]
        var currentTasks: [ConnectorTask] = []
        var accountError: (any Error)?
        var sourcesError: (any Error)?
        var tasksError: (any Error)?
        var sourceReadCount = 0
        var accessTokens: [String?] = []
        var onSourceRead: (() -> Void)?

        func account() async throws -> ConnectorAccount {
            if let accountError { throw accountError }
            return currentAccount
        }
        func sources() async throws -> [ConnectorSource] {
            sourceReadCount += 1
            onSourceRead?()
            if let sourcesError { throw sourcesError }
            return currentSources
        }
        var sentChanges: [ConnectorCompletionChange] = []
        var completionError: ConnectorProviderError?
        var onCompletion: (() throws -> Void)?
        func setCompletion(taskID: String, sourceIDs: Set<String>, change: ConnectorCompletionChange) async throws {
            sentChanges.append(change)
            try onCompletion?()
            if let completionError { throw completionError }
            if let index = currentTasks.firstIndex(where: { $0.id == taskID }) {
                currentTasks[index].isCompleted = change.isCompleted
                currentTasks[index].completedAt = change.isCompleted ? change.createdAt : nil
            }
        }
        func tasks(sourceIDs: Set<String>) async throws -> [ConnectorTask] {
            if let tasksError { throw tasksError }
            return currentTasks.filter { sourceIDs.contains($0.sourceID) }
        }
    }

    @MainActor
    private final class MockCredentialStorage: ConnectorCredentialStorage {
        var values: [ConnectorProviderID: ConnectorCredentials] = [:]
        var saveError: (any Error)?
        var removeError: (any Error)?
        var failOnSaveAttempt: Int?
        var saveAttemptCount = 0
        var onSaved: ((ConnectorCredentials) -> Void)?

        func read(for provider: ConnectorProviderID) throws -> ConnectorCredentials? { values[provider] }
        func save(_ credentials: ConnectorCredentials, for provider: ConnectorProviderID) throws {
            saveAttemptCount += 1
            if let saveError { throw saveError }
            if saveAttemptCount == failOnSaveAttempt { throw ConnectorStoreError.keychain }
            values[provider] = credentials
            onSaved?(credentials)
        }
        func remove(for provider: ConnectorProviderID) throws {
            if let removeError { throw removeError }
            values.removeValue(forKey: provider)
        }
    }

    @MainActor
    private final class MockAuthorization: ConnectorAuthorizing {
        var refreshCount = 0
        var refreshError: (any Error)?
        var onRefresh: ((ConnectorCredentials) throws -> Void)?

        func authorize(using browser: any ConnectorWebAuthenticating) async throws -> ConnectorCredentials {
            throw CancellationError()
        }

        func refresh(_ credentials: ConnectorCredentials) async throws -> ConnectorCredentials {
            refreshCount += 1
            try onRefresh?(credentials)
            if let refreshError { throw refreshError }
            return ConnectorCredentials(
                accessToken: "new-access", refreshToken: "rotated-refresh",
                expiresAt: Date.now.addingTimeInterval(3600)
            )
        }
    }

    @MainActor
    private final class CancelledBrowser: ConnectorWebAuthenticating {
        var requestCount = 0
        func authenticate(url: URL) async throws -> URL {
            requestCount += 1
            throw CancellationError()
        }
    }
}
