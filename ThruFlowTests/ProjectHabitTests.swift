import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct ProjectHabitTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        c.firstWeekday = 2
        return c
    }
    private func day(_ n: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: n, hour: hour))!
    }
    private func container() throws -> ModelContainer {
        let schema = AppModelContainerFactory.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        return container
    }
    private var service: ProjectEditingService { ProjectEditingService(calendar: calendar) }
    private func config(schedule: GoalScheduleKind = .everyDay, unit: GoalUnit = .minutes) -> ProjectHabitSettings {
        var value = ProjectHabitSettings()
        value.isEnabled = true; value.goalTarget = 30; value.goalUnit = unit
        value.goalSchedule = schedule; value.weeklyTargetCount = 3
        return value
    }
    private func all(_ c: ModelContext) throws -> [Todo] { try c.fetch(FetchDescriptor<Todo>()) }
    private func active(_ c: ModelContext) throws -> [Todo] { try all(c).filter { !$0.isDeleted } }
    private func materialize(_ c: ModelContext, areas: [Area] = [], days: [Int], now: Int) throws {
        try HabitTodoMaterializer(calendar: calendar).materialize(areas: areas, dates: days.map { day($0) }, modelContext: c, now: day(now))
    }

    @Test func oldProjectIsOffAndManualTasksNeverBecomeHabits() throws {
        let container = try container(); let c = container.mainContext; let area = Area(name: "Cloud", type: .neutral); c.insert(area)
        let project = try service.save(name: "AWS", notes: "Keep memo", area: area, modelContext: c, now: day(19))
        #expect(project.habitSettings == nil)
        let task = try TaskEditingService().save(draft: TodoDraft(title: "Exam", area: area, project: project), modelContext: c)
        try materialize(c, days: [19], now: 19)
        #expect(try active(c).count == 1)
        _ = try service.save(name: project.name, notes: project.notes ?? "", area: area, editing: project, habit: config(), modelContext: c, now: day(19))
        #expect(!task.isHabitOccurrence)
        let generated = try #require(try active(c).first { $0.isHabitOccurrence })
        #expect(generated.project?.id == project.id)
        #expect(generated.taskType == .habit)
        #expect(generated.measurement == .minutes && generated.plannedAmount == 30)
        #expect(TodoDisplay.taskTitle(for: generated) == "AWS")
        let loaded = try #require(try ModelContext(c.container).fetch(FetchDescriptor<Project>()).first)
        #expect(loaded.habitSettings == project.habitSettings)
        #expect(loaded.notes == "Keep memo")
    }

    @Test func parentAndSiblingHabitsHaveIndependentIdentityAndProgress() throws {
        let container = try container(); let c = container.mainContext
        let area = Area(name: "Cloud", type: .habit, goalTarget: 1, goalPeriod: .daily, goalUnit: .occurrences, goalSchedule: .everyDay)
        c.insert(area)
        let a = try service.save(name: "AWS", area: area, habit: config(), modelContext: c, now: day(19))
        let b = try service.save(name: "Azure", area: area, habit: config(), modelContext: c, now: day(19))
        try materialize(c, areas: [area], days: [19], now: 19)
        try materialize(c, areas: [area], days: [19], now: 19)
        let todos = try active(c)
        #expect(todos.count == 3)
        let first = try #require(todos.first { $0.project?.id == a.id })
        first.focusDurationSeconds = 900
        let duplicate = Todo(title: "", area: area, project: a, habitOccurrence: true, scheduledDate: first.scheduledDate)
        c.insert(duplicate)
        let result = HabitTodoReconciler(calendar: calendar).reconcile(todos: todos + [duplicate], sessions: [], segments: [], now: day(19))
        #expect(result.changed)
        #expect(try active(c).count == 3)
        #expect(try active(c).contains { $0.project?.id == b.id })
        let summary = StatisticsPeriodBuilder(calendar: calendar).build(flowRecords: [], achievementRecords: [],
            filter: StatisticsPeriodFilter(period: .month, anchorDate: day(19)),
            habitRecords: try active(c).compactMap { HabitCompletionRecord(todo: $0, calendar: calendar) }, now: day(19)).habitCompletion
        #expect(summary.occurrenceCount == 3)
        #expect(summary.areas.count == 3)
        #expect(summary.completedFraction == 0.5)
        #expect(summary.areas.contains { $0.name == "Cloud / AWS" })
    }

    @Test func weeklyAttemptsStartFreshAndRenamePreservesPostponement() throws {
        let container = try container(); let c = container.mainContext; let area = Area(name: "Cloud", type: .neutral); c.insert(area)
        let project = try service.save(name: "AWS", area: area, habit: config(schedule: .weeklyCount), modelContext: c, now: day(19))
        let first = try #require(try active(c).first)
        first.focusDurationSeconds = 600; first.actualProgress = 10; try c.save()
        try materialize(c, days: [20], now: 20)
        let next = try #require(try active(c).first { $0.id != first.id })
        #expect(first.scheduledDate == day(19, hour: 0))
        #expect(next.actualProgress == 0 && next.recordedFocusSeconds == 0)
        #expect(TaskRescheduleService(calendar: calendar).validate(next, movingTo: day(21), among: try all(c), now: day(20)).isSuccess)
        next.scheduledDate = day(21, hour: 0); try c.save()
        _ = try service.save(name: "Renamed", area: area, editing: project, habit: project.habitSettings, modelContext: c, now: day(20))
        #expect(!next.isDeleted && next.scheduledDate == day(21, hour: 0))
        try materialize(c, days: [20], now: 20)
        #expect(try active(c).count == 2)
        #expect(next.id != first.id)
    }

    @Test func disableCompleteAndReopenKeepGapsAndStartedHistory() throws {
        let container = try container(); let c = container.mainContext; let area = Area(name: "Cloud", type: .neutral); c.insert(area)
        let project = try service.save(name: "AWS", area: area, habit: config(), modelContext: c, now: day(19))
        try materialize(c, days: [20, 21, 22, 23, 24], now: 19)
        let started = try #require(try active(c).first { $0.scheduledDate == day(19, hour: 0) })
        started.focusDurationSeconds = 600; started.actualProgress = 10; try c.save()
        var settings = try #require(project.habitSettings); settings.isEnabled = false
        _ = try service.save(name: "AWS", area: area, editing: project, habit: settings, modelContext: c, now: day(20))
        #expect(try active(c).count == 1)
        try service.setCompleted(true, for: project, modelContext: c, now: day(21))
        settings.isEnabled = true
        _ = try service.save(name: "AWS", area: area, editing: project, habit: settings, modelContext: c, now: day(22))
        #expect(try active(c).count == 1)
        try service.setCompleted(false, for: project, modelContext: c, now: day(23))
        try materialize(c, days: [18, 19, 20, 21, 22, 23, 24], now: 23)
        let dates = try active(c).compactMap(\.scheduledDate).sorted()
        #expect(dates == [19, 23, 24].map { day($0, hour: 0) })
        #expect(started.recordedFocusSeconds == 600 && started.isHabitOccurrence)
        #expect(project.habitSettings?.isEnabled == true)
        // A delayed CloudKit occurrence in the inactive interval is retired too.
        let imported = Todo(title: "", area: area, project: project, habitOccurrence: true, scheduledDate: day(21, hour: 0))
        c.insert(imported); try c.save()
        try materialize(c, days: [23], now: 23)
        #expect(imported.isDeleted)
    }

    @Test func archiveNeutralParentBlocksBackfillButAreaHabitPauseIsIndependent() throws {
        let container = try container(); let c = container.mainContext; let area = Area(name: "Cloud", type: .neutral); c.insert(area)
        let project = try service.save(name: "AWS", area: area, habit: config(), modelContext: c, now: day(19))
        try materialize(c, days: [20, 21, 22], now: 19)
        let lifecycle = AreaLifecycleService(calendar: calendar)
        try lifecycle.archive(area, modelContext: c, now: day(20))
        #expect(try active(c).count == 1)
        try lifecycle.restore(area, modelContext: c, now: day(22))
        try materialize(c, days: [19, 20, 21, 22], now: 22)
        #expect(try active(c).map(\.scheduledDate).compactMap { $0 }.sorted() == [19, 22].map { day($0, hour: 0) })
        area.type = .habit
        area.goalTarget = 1; area.goalUnit = .occurrences; area.goalPeriod = .daily; area.goalSchedule = .everyDay
        HabitPauseService(calendar: calendar).pauseIndefinitely(area, todos: try all(c), now: day(22))
        try materialize(c, areas: [area], days: [23], now: 23)
        #expect(try active(c).contains { $0.project?.id == project.id && $0.scheduledDate == day(23, hour: 0) })
        #expect(try active(c).allSatisfy { $0.project != nil })
    }

    @Test func goalValidationScheduleChangesAndFailedSaveAreAtomic() throws {
        let container = try container(); let c = container.mainContext; let area = Area(name: "Cloud", type: .neutral); c.insert(area)
        var settings = config(schedule: .weekdays)
        #expect(throws: ProjectEditingError.self) { try service.save(name: "AWS", area: area, habit: settings, modelContext: c, now: day(19)) }
        settings.weekdayMask = GoalWeekday.monday.rawValue
        let project = try service.save(name: "AWS", area: area, habit: settings, modelContext: c, now: day(19))
        let occurrence = try #require(try active(c).first)
        try materialize(c, days: [20, 21], now: 19)
        #expect(try active(c).count == 1)
        var updated = settings; updated.goalTarget = 2; updated.goalUnit = .hours
        _ = try service.save(name: "AWS", area: area, editing: project, habit: updated, modelContext: c, now: day(19))
        #expect(occurrence.plannedAmount == 120 && occurrence.measurement == .minutes)
        let before = project.habitSettingsRawValue
        let failing = ProjectEditingService(calendar: calendar, saveChanges: { _ in throw Failure.save })
        updated.isEnabled = false
        #expect(throws: Failure.self) { try failing.save(name: "Changed", area: area, editing: project, habit: updated, modelContext: c, now: day(19)) }
        #expect(project.name == "AWS" && project.habitSettingsRawValue == before)
        #expect(!occurrence.isDeleted)
        #expect(throws: Failure.self) { try failing.setCompleted(true, for: project, modelContext: c, now: day(19)) }
        #expect(!project.isCompleted && !occurrence.isDeleted)
    }

    @Test func generatedProjectTaskKeepsOwnershipWhenEditedAndDisabled() throws {
        let container = try container(); let c = container.mainContext; let area = Area(name: "Cloud", type: .neutral); c.insert(area)
        let project = try service.save(name: "AWS", area: area, habit: config(), modelContext: c, now: day(19))
        let task = try #require(try active(c).first)
        var draft = TodoDraft(todo: task); draft.title = "Study"; draft.project = nil; draft.plannedAmount = 1
        _ = try TaskEditingService().save(draft: draft, editing: task, modelContext: c)
        #expect(task.project?.id == project.id && task.plannedAmount == 30)
        task.actualProgress = 10; task.focusDurationSeconds = 600; try c.save()
        try service.setCompleted(true, for: project, modelContext: c, now: day(19))
        #expect(task.isHabitOccurrence && !task.isDeleted)
        #expect(HabitCompletionRecord(todo: task, calendar: calendar)?.fraction == 1.0 / 3)
    }

    @Test func incompleteCloudRelationshipsNeverMergeDifferentHabitOwners() throws {
        let container = try container(); let c = container.mainContext
        let area = Area(name: "Cloud", type: .habit, goalTarget: 1, goalPeriod: .daily, goalUnit: .occurrences, goalSchedule: .everyDay)
        c.insert(area)
        let a = try service.save(name: "AWS", area: area, habit: config(), modelContext: c, now: day(19))
        let b = try service.save(name: "Azure", area: area, habit: config(), modelContext: c, now: day(19))
        let todos = try active(c)
        let first = try #require(todos.first { $0.project?.id == a.id })
        let second = try #require(todos.first { $0.project?.id == b.id })
        let parent = try #require(RequiredTodoPlanner(calendar: calendar).makeRequiredTodo(for: area, on: day(19)))
        c.insert(parent)
        first.project = nil // Project has not resolved yet, Area has.
        second.direction = nil // Project has resolved, Area has not.
        let reconciler = HabitTodoReconciler(calendar: calendar)
        #expect(first.isHabitOccurrence && second.isHabitOccurrence)
        #expect(!reconciler.hasDuplicateOccurrences(in: [first, second, parent]))
        #expect(!reconciler.reconcile(todos: [first, second, parent], sessions: [], segments: []).changed)
        #expect(!RequiredTodoPlanner(calendar: calendar).shouldCreateRequiredTodo(for: try #require(HabitDefinition(project: a)), in: [first], on: day(19)))
        HabitPauseService(calendar: calendar).pauseToday(area, todos: [first, second], now: day(19))
        #expect(!first.isDeleted && !second.isDeleted)
        first.direction = nil
        #expect(!RequiredTodoPlanner(calendar: calendar).matchesGeneratedTemplate(first, for: area))
        #expect(HabitCompletionRecord(todo: first, calendar: calendar) == nil)
        first.direction = area; first.project = a; second.direction = area
        #expect(HabitDefinition(todo: first)?.ownerKey == "project:\(a.id)")
        #expect(!reconciler.hasDuplicateOccurrences(in: [first, second, parent]))
        let duplicate = Todo(title: "", area: area, project: a, habitOccurrence: true, scheduledDate: first.scheduledDate)
        #expect(reconciler.hasDuplicateOccurrences(in: [first, second, parent, duplicate]))
    }

    @Test func existingProjectsMigrateWithHabitsOffAndIdentityUnchanged() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("project.store")
        let ids = try writeOldStore(at: url)
        let schema = AppModelContainerFactory.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
        let c = container.mainContext
        let project = try #require(try c.fetch(FetchDescriptor<Project>()).first)
        let task = try #require(try c.fetch(FetchDescriptor<Todo>()).first)
        #expect(project.id == ids.project && project.notes == "Original memo")
        #expect(project.habitSettingsRawValue == nil)
        #expect(task.id == ids.task && task.project?.id == project.id)
        #expect(task.habitOwnerKeyRawValue == nil && !task.isHabitOccurrence)
        #expect(task.scheduledTimeMinutes == 540 && task.reminderEnabled)
        _ = try service.save(name: "AWS", notes: project.notes ?? "", area: try #require(project.area), editing: project, habit: config(), modelContext: c, now: day(19))
        #expect(project.id == ids.project && task.id == ids.task)
        #expect(try active(c).count == 2)
    }

    private func writeOldStore(at url: URL) throws -> (project: UUID, task: UUID) {
        let schema = Schema(versionedSchema: PreProjectHabitSchema.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
        let c = container.mainContext
        let area = PreProjectHabitSchema.Direction(); area.name = "Cloud"
        let project = PreProjectHabitSchema.Project(); project.name = "AWS"; project.notes = "Original memo"; project.direction = area
        let task = PreProjectHabitSchema.Todo(); task.title = "Exam"; task.project = project; task.direction = area
        task.habitOccurrence = false; task.scheduledDate = day(19, hour: 0); task.scheduledTimeMinutes = 540; task.reminderEnabled = true
        c.insert(area); c.insert(project); c.insert(task); try c.save()
        return (project.id, task.id)
    }

    private enum Failure: Error { case save }
}

private extension Result where Success == Void {
    var isSuccess: Bool { if case .success = self { true } else { false } }
}
