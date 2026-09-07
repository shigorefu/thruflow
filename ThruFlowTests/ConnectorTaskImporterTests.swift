import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct ConnectorTaskImporterTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func firstImportCreatesOnlyActiveCheckboxTasksWithExternalDeadline() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = try makeArea(context)
        let due = now.addingTimeInterval(86_400)
        let active = task(notes: "外部メモ", dueDate: due)
        let completed = task(id: "completed", isCompleted: true)

        let result = try run([active, completed], area: area, context: context)
        let todo = try #require(context.fetch(FetchDescriptor<Todo>()).first)

        #expect(result == ConnectorImportResult(inserted: 1, updated: 0, skipped: 1))
        #expect(todo.measurement == .checkbox)
        #expect(todo.status == .active)
        #expect(todo.scheduledDate == nil)
        #expect(todo.deadline == due)
        #expect(todo.notes == "外部メモ")
        #expect(todo.area?.id == area.id)
        #expect(todo.externalTaskLink?.originalURL == active.url)
        #expect(todo.externalTaskLink?.lastSyncedAt == now)
    }

    @Test func repeatedImportAndSourceMoveKeepOneTodoIdentity() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = try makeArea(context)
        _ = try run([task()], area: area, context: context)
        let first = try #require(context.fetch(FetchDescriptor<Todo>()).first)
        let originalID = first.id
        let updateDate = now.addingTimeInterval(60)

        let result = try run(
            [task(sourceID: "moved-list", title: "更新したタスク"), task()],
            area: area,
            context: context,
            date: updateDate
        )
        let todos = try context.fetch(FetchDescriptor<Todo>())

        #expect(result == ConnectorImportResult(inserted: 0, updated: 1, skipped: 1))
        #expect(todos.count == 1)
        #expect(todos.first?.id == originalID)
        #expect(first.title == "更新したタスク")
        #expect(first.externalTaskLink?.sourceID == "moved-list")
        #expect(first.externalTaskLink?.lastSyncedAt == updateDate)
    }

    @Test func taskIdentityIncludesAccountAndProvider() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = try makeArea(context)
        _ = try run([task()], area: area, context: context, accountID: "first-account")
        _ = try run([task()], area: area, context: context, accountID: "second-account")
        _ = try run([task()], area: area, context: context, provider: .reminders, accountID: "first-account")

        let todos = try context.fetch(FetchDescriptor<Todo>())
        #expect(todos.count == 3)
        #expect(Set(todos.compactMap { $0.externalTaskLink?.identity }).count == 3)
    }

    @Test func refreshPreservesLocalCompletionPlanningMemoAndHistory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = try makeArea(context)
        _ = try run([task(notes: "初回メモ", dueDate: now)], area: area, context: context)
        let todo = try #require(context.fetch(FetchDescriptor<Todo>()).first)
        let locallySelectedArea = Area(name: "個人", type: .nice)
        context.insert(locallySelectedArea)
        todo.area = locallySelectedArea
        todo.setMemo("自分の振り返り", now: now)
        todo.hashtags = ["local"]
        todo.priority = .high
        todo.scheduledDate = now.addingTimeInterval(3 * 86_400)
        todo.setManuallyCompleted(true, now: now)
        todo.recordedFocusSeconds = 720
        let (session, segment) = addHistory(for: todo, area: area, seconds: 720, context: context)
        try context.save()
        let originalID = todo.id
        let originalScheduledDate = todo.scheduledDate

        _ = try run([task(title: "外部の更新", notes: "上書きしない", dueDate: nil)], area: area, context: context)

        #expect(todo.id == originalID)
        #expect(todo.title == "外部の更新")
        #expect(todo.deadline == nil)
        #expect(todo.notes == "自分の振り返り")
        #expect(todo.hashtags == ["local"])
        #expect(todo.priority == .high)
        #expect(todo.scheduledDate == originalScheduledDate)
        #expect(todo.area?.id == locallySelectedArea.id)
        #expect(todo.status == .completed)
        #expect(todo.completedAt == now)
        #expect(todo.actualProgress == 1)
        #expect(todo.recordedFocusSeconds == 720)
        #expect(session.todo?.id == originalID)
        #expect(segment.todo?.id == originalID)
        #expect(session.result == "保存された結果")
        #expect(session.area?.id == area.id)
    }

    @Test func refreshPreservesMeasuredProgressAndDoesNotAdoptRemoteCompletion() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = try makeArea(context)
        _ = try run([task()], area: area, context: context)
        let todo = try #require(context.fetch(FetchDescriptor<Todo>()).first)
        todo.measurement = .minutes
        todo.plannedAmount = 30
        todo.actualProgress = 12
        todo.recordedFocusSeconds = 720
        try context.save()

        _ = try run([task(isCompleted: true)], area: area, context: context)

        #expect(todo.measurement == .minutes)
        #expect(todo.plannedAmount == 30)
        #expect(todo.actualProgress == 12)
        #expect(todo.recordedFocusSeconds == 720)
        #expect(todo.status == .active)
        #expect(todo.completedAt == nil)
    }

    @Test func deletedAndArchivedTasksNeverResurrectOnRefresh() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = try makeArea(context)
        _ = try run([task(id: "deleted"), task(id: "archived")], area: area, context: context)
        let todos = try context.fetch(FetchDescriptor<Todo>())
        let deleted = try #require(todos.first { $0.externalTaskLink?.taskID == "deleted" })
        let archived = try #require(todos.first { $0.externalTaskLink?.taskID == "archived" })
        deleted.softDelete(now: now)
        archived.archive(now: now)
        try context.save()

        let result = try run([task(id: "deleted", title: "変更"), task(id: "archived", title: "変更")], area: area, context: context)

        #expect(result == ConnectorImportResult(inserted: 0, updated: 0, skipped: 2))
        #expect(try context.fetchCount(FetchDescriptor<Todo>()) == 2)
        #expect(deleted.isDeleted)
        #expect(archived.isArchived)
        #expect(deleted.title == "タスク")
        #expect(archived.title == "タスク")
    }

    @Test func missingExternalTasksKeepLocalTaskAndHistory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = try makeArea(context)
        _ = try run([task()], area: area, context: context)
        let todo = try #require(context.fetch(FetchDescriptor<Todo>()).first)
        let (session, _) = addHistory(for: todo, area: area, seconds: 60, context: context)
        try context.save()

        let result = try run([], area: area, context: context)

        #expect(result == ConnectorImportResult())
        #expect(!todo.isDeleted)
        #expect(session.todo?.id == todo.id)
        #expect(try context.fetchCount(FetchDescriptor<Todo>()) == 1)
    }

    @Test func failedSaveRollsBackInsertedTasksAndUpdatedMetadata() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = try makeArea(context)
        _ = try run([task()], area: area, context: context)
        let todo = try #require(context.fetch(FetchDescriptor<Todo>()).first)
        let originalLink = todo.externalTaskLinkRawValue
        let importer = ConnectorTaskImporter(save: { _ in throw TestFailure.expected })

        #expect(throws: TestFailure.expected) {
            try importer.importTasks(
                [task(title: "失敗する更新"), task(id: "new")],
                provider: .todoist,
                accountID: "account",
                area: area,
                modelContext: context,
                now: now.addingTimeInterval(60)
            )
        }

        #expect(try context.fetchCount(FetchDescriptor<Todo>()) == 1)
        #expect(todo.title == "タスク")
        #expect(todo.externalTaskLinkRawValue == originalLink)
        #expect(!context.hasChanges)
    }

    @Test func failedImportRestoresOwnChangesAndKeepsPendingUserEdits() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = try makeArea(context)
        _ = try run([task()], area: area, context: context)
        let imported = try #require(context.fetch(FetchDescriptor<Todo>()).first)
        let unrelated = Todo(title: "編集前", area: area)
        context.insert(unrelated)
        try context.save()
        unrelated.title = "保存前のユーザー編集"
        let importer = ConnectorTaskImporter(save: { _ in throw TestFailure.expected })

        #expect(throws: TestFailure.expected) {
            try importer.importTasks(
                [task(title: "失敗する更新"), task(id: "new")],
                provider: .todoist, accountID: "account", area: area,
                modelContext: context, now: now
            )
        }

        #expect(imported.title == "タスク")
        #expect(unrelated.title == "保存前のユーザー編集")
        #expect(context.hasChanges)
        #expect(try context.fetchCount(FetchDescriptor<Todo>()) == 2)
        #expect(area.todos?.count == 2)
        // A later normal editor save must persist only the user's pending edit,
        // not accidentally commit the previously failed import.
        try context.save()
        let saved = try ModelContext(container).fetch(FetchDescriptor<Todo>())
        #expect(saved.count == 2)
        #expect(saved.first { $0.id == imported.id }?.title == "タスク")
        #expect(saved.first { $0.id == unrelated.id }?.title == "保存前のユーザー編集")
    }

    @Test func failedReconciliationKeepsPendingEditorChangesAndOriginalHistoryLinks() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = try makeArea(context)
        _ = try run([task()], area: area, context: context)
        let canonical = try #require(context.fetch(FetchDescriptor<Todo>()).first)
        let duplicate = try makeDuplicate(of: canonical, context: context)
        let (session, segment) = addHistory(for: duplicate, area: area, seconds: 60, context: context)
        let unrelated = Todo(title: "編集前", area: area)
        context.insert(unrelated)
        try context.save()
        unrelated.title = "保存前のユーザー編集"
        let importer = ConnectorTaskImporter(save: { _ in throw TestFailure.expected })

        #expect(throws: TestFailure.expected) {
            try importer.reconcileDuplicates(modelContext: context, now: now)
        }

        #expect(unrelated.title == "保存前のユーザー編集")
        #expect(context.hasChanges)
        #expect(!duplicate.isDeleted)
        #expect(duplicate.externalTaskLink?.supersededByTodoID == nil)
        #expect(session.todo?.id == duplicate.id)
        #expect(segment.todo?.id == duplicate.id)
        try context.save()
        let savedSession = try #require(ModelContext(container).fetch(FetchDescriptor<FlowSession>()).first)
        #expect(savedSession.todo?.id == duplicate.id)
    }

    @Test func malformedLinkDuringBackgroundRepairDoesNotRollbackAnEditor() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = try makeArea(context)
        let malformed = Todo(title: "識別情報", area: area)
        malformed.externalTaskLinkRawValue = "not-json"
        let draft = Todo(title: "編集前", area: area)
        context.insert(malformed)
        context.insert(draft)
        try context.save()
        draft.title = "保存前のユーザー編集"

        #expect(throws: DecodingError.self) {
            try ConnectorTaskImporter().reconcileDuplicates(modelContext: context, now: now)
        }
        #expect(draft.title == "保存前のユーザー編集")
        #expect(context.hasChanges)
    }

    @Test func malformedIdentityFailsWithoutInsertingDuplicate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = try makeArea(context)
        let todo = Todo(title: "既存", area: area)
        todo.externalTaskLinkRawValue = "not-json"
        context.insert(todo)
        try context.save()

        #expect(throws: DecodingError.self) {
            try run([task()], area: area, context: context)
        }

        #expect(try context.fetchCount(FetchDescriptor<Todo>()) == 1)
        #expect(todo.externalTaskLinkRawValue == "not-json")
        #expect(!context.hasChanges)
    }

    @Test func cloudDuplicatesConvergeAndRebuildMeasuredProgressFromBothHistories() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = try makeArea(context)
        _ = try run([task(notes: "Macのメモ")], area: area, context: context)
        let canonical = try #require(context.fetch(FetchDescriptor<Todo>()).first)
        canonical.measurement = .minutes
        canonical.plannedAmount = 20
        let duplicate = try makeDuplicate(of: canonical, context: context)
        duplicate.notes = "iPhoneのメモ"
        duplicate.measurement = .minutes
        duplicate.plannedAmount = 20
        let (firstSession, firstSegment) = addHistory(for: canonical, area: area, seconds: 600, context: context)
        let (secondSession, secondSegment) = addHistory(for: duplicate, area: area, seconds: 720, context: context)
        let historyIDs = [firstSession.id, firstSegment.id, secondSession.id, secondSegment.id]
        try context.save()
        let importer = ConnectorTaskImporter()

        #expect(try importer.reconcileDuplicates(modelContext: context, now: now.addingTimeInterval(60)))

        #expect(duplicate.isDeleted)
        #expect(!canonical.isDeleted)
        #expect(duplicate.externalTaskLink?.supersededByTodoID == canonical.id)
        #expect(canonical.actualProgress == 22)
        #expect(canonical.recordedFocusSeconds == 1320)
        #expect(canonical.isCompleted)
        #expect(canonical.notes == "Macのメモ\n\niPhoneのメモ")
        #expect(firstSession.todo?.id == canonical.id)
        #expect(firstSegment.todo?.id == canonical.id)
        #expect(secondSession.todo?.id == canonical.id)
        #expect(secondSegment.todo?.id == canonical.id)
        #expect([firstSession.id, firstSegment.id, secondSession.id, secondSegment.id] == historyIDs)
        #expect(try !importer.reconcileDuplicates(modelContext: context, now: now.addingTimeInterval(120)))
        let result = try run([task()], area: area, context: context)
        #expect(result.updated == 1)
        #expect(result.inserted == 0)
        #expect(try context.fetch(FetchDescriptor<Todo>()).filter { !$0.isDeleted }.count == 1)
    }

    @Test func duplicateConvergenceKeepsOldestIdentityAndLatestExternalSnapshot() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = try makeArea(context)
        _ = try run([task(title: "古い外部タイトル", dueDate: now)], area: area, context: context)
        let canonical = try #require(context.fetch(FetchDescriptor<Todo>()).first)
        canonical.notes = "自分のメモ"
        canonical.priority = .high
        canonical.scheduledDate = now.addingTimeInterval(86_400)
        canonical.setManuallyCompleted(true, now: now)
        let canonicalID = canonical.id
        let duplicate = try makeDuplicate(of: canonical, context: context)
        duplicate.title = "新しい外部タイトル"
        duplicate.deadline = now.addingTimeInterval(2 * 86_400)
        let latestImport = now.addingTimeInterval(60)
        let latestURL = URL(string: "https://app.todoist.com/app/task/task?source=new")!
        var latestLink = try #require(duplicate.externalTaskLink)
        latestLink.lastSyncedAt = latestImport
        latestLink.sourceID = "moved-project"
        latestLink.originalURL = latestURL
        duplicate.externalTaskLinkRawValue = try latestLink.encoded()
        let (session, segment) = addHistory(for: duplicate, area: area, seconds: 60, context: context)
        try context.save()

        #expect(try ConnectorTaskImporter().reconcileDuplicates(modelContext: context, now: latestImport))

        #expect(canonical.id == canonicalID)
        #expect(canonical.title == "新しい外部タイトル")
        #expect(canonical.deadline == now.addingTimeInterval(2 * 86_400))
        #expect(canonical.externalTaskLink?.sourceID == "moved-project")
        #expect(canonical.externalTaskLink?.originalURL == latestURL)
        #expect(canonical.externalTaskLink?.lastSyncedAt == latestImport)
        #expect(canonical.externalTaskLink?.supersededByTodoID == nil)
        #expect(canonical.notes == "自分のメモ")
        #expect(canonical.priority == .high)
        #expect(canonical.area?.id == area.id)
        #expect(canonical.scheduledDate == now.addingTimeInterval(86_400))
        #expect(canonical.isCompleted)
        #expect(canonical.completedAt == now)
        #expect(session.todo?.id == canonicalID)
        #expect(segment.todo?.id == canonicalID)
        #expect(duplicate.isDeleted)
    }

    @Test func lateCloudKitHistoryIsReattachedFromSupersededTodo() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = try makeArea(context)
        _ = try run([task()], area: area, context: context)
        let canonical = try #require(context.fetch(FetchDescriptor<Todo>()).first)
        let duplicate = try makeDuplicate(of: canonical, context: context)
        try context.save()
        let importer = ConnectorTaskImporter()
        _ = try importer.reconcileDuplicates(modelContext: context, now: now)
        let (session, segment) = addHistory(for: duplicate, area: area, seconds: 720, context: context)
        try context.save()

        #expect(try importer.reconcileDuplicates(modelContext: context, now: now))
        #expect(session.todo?.id == canonical.id)
        #expect(segment.todo?.id == canonical.id)
        #expect(canonical.recordedFocusSeconds == 720)
        #expect(canonical.status == .active)
    }

    @Test func userDeletionWinsOverConcurrentOfflineImport() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = try makeArea(context)
        _ = try run([task()], area: area, context: context)
        let canonical = try #require(context.fetch(FetchDescriptor<Todo>()).first)
        let duplicate = try makeDuplicate(of: canonical, context: context)
        duplicate.softDelete(now: now)
        try context.save()

        let result = try run([task()], area: area, context: context)

        #expect(result.skipped == 1)
        #expect(result.inserted == 0)
        #expect(canonical.isDeleted)
        #expect(duplicate.isDeleted)
        #expect(canonical.externalTaskLink?.supersededByTodoID == nil)
    }

    @Test func failedDuplicateSaveRestoresRelationshipsAndTombstones() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = try makeArea(context)
        _ = try run([task()], area: area, context: context)
        let canonical = try #require(context.fetch(FetchDescriptor<Todo>()).first)
        let duplicate = try makeDuplicate(of: canonical, context: context)
        let (session, segment) = addHistory(for: duplicate, area: area, seconds: 60, context: context)
        try context.save()
        let importer = ConnectorTaskImporter(save: { _ in throw TestFailure.expected })

        #expect(throws: TestFailure.expected) {
            try importer.reconcileDuplicates(modelContext: context, now: now)
        }

        #expect(!duplicate.isDeleted)
        #expect(duplicate.externalTaskLink?.supersededByTodoID == nil)
        #expect(session.todo?.id == duplicate.id)
        #expect(segment.todo?.id == duplicate.id)
        #expect(!context.hasChanges)
    }

    @Test func externalLinkAddsNoEntityAndExistingTasksRemainUnlinked() throws {
        let schema = AppModelContainerFactory.schema
        #expect(schema.entities.count == 5)
        let entity = try #require(schema.entities.first { $0.name == "Todo" })
        let property = try #require(entity.properties.first { $0.name == "externalTaskLinkRawValue" })
        #expect(property.isOptional)
        let todo = Todo(title: "既存", area: Area(name: "仕事", type: .neutral))
        #expect(todo.externalTaskLinkRawValue == nil)
        #expect(todo.externalTaskLink == nil)
    }

    @Test func habitAreaImportIsRejectedBeforeChangingPersistence() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "習慣", type: .habit)
        context.insert(area)
        try context.save()

        #expect(throws: ConnectorImportError.self) {
            try run([task()], area: area, context: context)
        }
        #expect(try context.fetchCount(FetchDescriptor<Todo>()) == 0)
    }

    @Test func importedTaskMovedToHabitIsNotAnOccurrenceOrRemovedByScheduleChanges() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let originalArea = try makeArea(context)
        _ = try run([task()], area: originalArea, context: context)
        let imported = try #require(context.fetch(FetchDescriptor<Todo>()).first)
        let habit = Area(
            name: "読書", type: .habit, goalTarget: 1, goalPeriod: .daily,
            goalUnit: .occurrences, goalSchedule: .everyDay
        )
        context.insert(habit)
        imported.area = habit
        imported.scheduledDate = now
        let planner = RequiredTodoPlanner()
        let occurrence = try #require(planner.makeRequiredTodo(for: habit, existingTodos: [imported], on: now))
        context.insert(occurrence)
        try context.save()

        let reconciliation = HabitTodoReconciler().reconcile(
            todos: [imported, occurrence], sessions: [], segments: [], now: now
        )
        #expect(!reconciliation.changed)
        #expect(planner.existingRequiredTodo(for: habit, in: [imported, occurrence], on: now)?.id == occurrence.id)

        habit.goalUnit = .minutes
        habit.goalTarget = 30
        _ = HabitScheduleChangeReconciler().reconcile(
            area: habit, todos: [imported, occurrence], modelContext: context, now: now
        )
        #expect(imported.measurement == .checkbox)
        #expect(imported.plannedAmount == nil)
        #expect(!imported.isDeleted)
        #expect(occurrence.measurement == .minutes)

        HabitPauseService().pauseToday(habit, todos: [imported, occurrence], now: now)
        #expect(!imported.isDeleted)
        #expect(occurrence.isDeleted)
    }

    private func task(
        id: String = "task",
        sourceID: String = "list",
        title: String = "タスク",
        notes: String? = nil,
        dueDate: Date? = nil,
        isCompleted: Bool = false
    ) -> ConnectorTask {
        ConnectorTask(
            id: id,
            sourceID: sourceID,
            title: title,
            notes: notes,
            dueDate: dueDate,
            isCompleted: isCompleted,
            completedAt: isCompleted ? now : nil,
            url: URL(string: "https://app.todoist.com/app/task/\(id)")
        )
    }

    private func run(
        _ tasks: [ConnectorTask],
        area: Area,
        context: ModelContext,
        provider: ConnectorProviderID = .todoist,
        accountID: String = "account",
        date: Date? = nil
    ) throws -> ConnectorImportResult {
        try ConnectorTaskImporter().importTasks(
            tasks,
            provider: provider,
            accountID: accountID,
            area: area,
            modelContext: context,
            now: date ?? now
        )
    }

    private func makeArea(_ context: ModelContext) throws -> Area {
        let area = Area(name: "仕事", type: .neutral)
        context.insert(area)
        try context.save()
        return area
    }

    private func makeDuplicate(of todo: Todo, context: ModelContext) throws -> Todo {
        let area = try #require(todo.area)
        let duplicate = Todo(
            title: todo.title,
            area: area,
            createdAt: todo.createdAt.addingTimeInterval(1),
            updatedAt: todo.updatedAt
        )
        duplicate.externalTaskLinkRawValue = todo.externalTaskLinkRawValue
        context.insert(duplicate)
        return duplicate
    }

    @discardableResult
    private func addHistory(
        for todo: Todo,
        area: Area,
        seconds: Int,
        context: ModelContext
    ) -> (FlowSession, FlowSegment) {
        let end = now.addingTimeInterval(Double(seconds))
        let session = FlowSession(
            area: area,
            todo: todo,
            result: "保存された結果",
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: now,
            plannedEndAt: end,
            endedAt: end,
            plannedFocusDurationSeconds: seconds,
            actualFocusDurationSeconds: seconds,
            plannedBreakDurationSeconds: 0
        )
        let segment = FlowSegment(session: session, area: area, todo: todo, startedAt: now, startFocusSeconds: 0)
        segment.close(at: end, totalFocusSeconds: seconds)
        session.segments = [segment]
        context.insert(session)
        return (session, segment)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = AppModelContainerFactory.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        container.mainContext.autosaveEnabled = false
        return container
    }

    private enum TestFailure: Error, Equatable {
        case expected
    }
}
