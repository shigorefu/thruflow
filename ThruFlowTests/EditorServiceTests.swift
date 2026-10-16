import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct EditorServiceTests {
    @Test func editingUndatedTaskAcceptsEmptyNameAndPersistsNormalizedText() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let area = Area(name: "Study", type: .neutral)
        let todo = Todo(title: "Old title", area: area, habitOccurrence: false, scheduledDate: nil)
        context.insert(area)
        context.insert(todo)
        try context.save()
        var draft = TodoDraft(todo: todo)
        draft.title = " \n "
        draft.notes = "  Notes\n "
        draft.hashtags = [" #Study ", "study", "", "#Exam"]

        let saved = try TaskEditingService().save(draft: draft, editing: todo, modelContext: context, now: monday)
        let loaded = try #require(try ModelContext(container).fetch(FetchDescriptor<Todo>()).first)

        #expect(saved.id == todo.id)
        #expect(loaded.title.isEmpty)
        #expect(loaded.scheduledDate == nil)
        #expect(loaded.notes == "Notes")
        #expect(loaded.hashtags == ["Study", "Exam"])
        #expect(loaded.updatedAt == monday)
    }

    @Test func renamingUndatedTaskPreservesItsArchivedArea() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let area = Area(name: "Archived study", type: .neutral, archivedAt: sunday)
        let todo = Todo(title: "Original", area: area, habitOccurrence: false, scheduledDate: nil)
        context.insert(area)
        context.insert(todo)
        try context.save()
        var draft = TodoDraft(todo: todo)
        draft.title = "Renamed"

        _ = try TaskEditingService().save(draft: draft, editing: todo, modelContext: context, now: monday)
        let loaded = try #require(try ModelContext(container).fetch(FetchDescriptor<Todo>()).first)

        #expect(loaded.title == "Renamed")
        #expect(loaded.area?.id == area.id)
        #expect(loaded.area?.archivedAt == sunday)
        #expect(loaded.scheduledDate == nil)
        #expect(!loaded.isArchived)
        #expect(loaded.habitOccurrence == false)
        #expect(try context.fetch(FetchDescriptor<Area>()).count == 1)
    }

    @Test func manualTaskInHabitAreaRemainsIndependent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let area = makeHabit()
        context.insert(area)
        let draft = TodoDraft(title: "Mock exam", area: area, measurement: .minutes, plannedAmount: 90, scheduledDate: monday)

        let saved = try TaskEditingService().save(draft: draft, modelContext: context, now: monday)
        let loaded = try #require(try ModelContext(container).fetch(FetchDescriptor<Todo>()).first)

        #expect(saved.id == loaded.id)
        #expect(loaded.habitOccurrence == false)
        #expect(!loaded.isHabitOccurrence)
        #expect(loaded.title == "Mock exam")
        #expect(loaded.measurement == .minutes)
        #expect(loaded.plannedAmount == 90)
    }

    @Test func taskCreationReusesInboxAndPrependsToExistingOrder() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let inbox = DefaultAreas.makeTaskInbox(now: monday)
        let existing = Todo(title: "Existing", area: inbox, habitOccurrence: false, sortIndex: -7)
        context.insert(inbox)
        context.insert(existing)
        try context.save()

        let saved = try TaskEditingService().save(draft: TodoDraft(title: "New", scheduledDate: nil), modelContext: context, now: monday)

        #expect(saved.area?.id == inbox.id)
        #expect(saved.sortIndex == -8)
        #expect(saved.scheduledDate == nil)
        #expect(try context.fetch(FetchDescriptor<Area>()).count == 1)
    }

    @Test func taskCreationMakesInboxWhenNoAreaExists() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let saved = try TaskEditingService().save(draft: TodoDraft(title: "", scheduledDate: nil), modelContext: context, now: monday)
        let inbox = try #require(saved.area)
        let loaded = try #require(try ModelContext(container).fetch(FetchDescriptor<Todo>()).first)

        #expect(DefaultAreas.isTaskInbox(inbox))
        #expect(loaded.area?.id == inbox.id)
        #expect(loaded.habitOccurrence == false)
    }

    @Test func habitEditorPreservesSchedulingAndTemplateFieldsBeforeValidation() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let habit = makeHabit()
        let other = Area(name: "Other area", type: .neutral)
        let todo = Todo(title: "", area: habit, habitOccurrence: true, measurement: .minutes,
                        priority: .medium, plannedAmount: 30, scheduledDate: monday, deadline: tuesday)
        context.insert(habit)
        context.insert(other)
        context.insert(todo)
        try context.save()
        var draft = TodoDraft(todo: todo)
        draft.title = "Workout"
        draft.notes = "Done"
        draft.hashtags = ["exercise"]
        draft.area = other
        draft.measurement = .focusBlocks
        draft.plannedAmount = 0
        draft.priority = .low
        draft.isRoomIfPossible = true
        draft.scheduledDate = nil
        draft.deadline = nil
        draft.actualProgress = 12
        let service = TaskEditingService()

        #expect(service.validationErrors(for: draft, editing: todo).isEmpty)
        _ = try service.save(draft: draft, editing: todo, modelContext: context, now: monday)
        let loaded = try #require(try ModelContext(container).fetch(FetchDescriptor<Todo>()).first)

        #expect(loaded.title == "Workout")
        #expect(loaded.notes == "Done")
        #expect(loaded.hashtags == ["exercise"])
        #expect(loaded.actualProgress == 12)
        #expect(loaded.area?.id == habit.id)
        #expect(loaded.measurement == .minutes)
        #expect(loaded.plannedAmount == 30)
        #expect(loaded.priority == .medium)
        #expect(!loaded.isRoomIfPossible)
        #expect(loaded.scheduledDate == monday)
        #expect(loaded.deadline == tuesday)
        #expect(loaded.habitOccurrence == true)
    }

    @Test func checkboxCreationClampsProgressAndSetsCompletionDate() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let draft = TodoDraft(title: "Done", priority: .high, isRoomIfPossible: true, actualProgress: 7)

        let saved = try TaskEditingService().save(draft: draft, modelContext: context, now: monday)

        #expect(saved.actualProgress == 1)
        #expect(saved.isCompleted)
        #expect(saved.completedAt == monday)
        #expect(!saved.isRoomIfPossible)
        var edited = TodoDraft(todo: saved)
        edited.actualProgress = 0
        _ = try TaskEditingService().save(draft: edited, editing: saved, modelContext: context, now: tuesday)
        #expect(!saved.isCompleted)
        #expect(saved.completedAt == nil)
    }

    @Test func invalidTaskDraftDoesNotMutateExistingTaskOrCreateInbox() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let area = Area(name: "Study", type: .neutral)
        let todo = Todo(title: "Original", area: area, habitOccurrence: false)
        context.insert(area)
        context.insert(todo)
        try context.save()
        let draft = TodoDraft(title: "Invalid", measurement: .minutes, plannedAmount: 0)

        #expect(throws: TaskEditingError.self) {
            try TaskEditingService().save(draft: draft, editing: todo, modelContext: context, now: monday)
        }
        #expect(todo.title == "Original")
        #expect(todo.area?.id == area.id)
        #expect(!context.hasChanges)
        #expect(try context.fetch(FetchDescriptor<Area>()).count == 1)
    }

    @Test func failedTaskCreationRollsBackTaskAndAutomaticInbox() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let service = TaskEditingService(saveChanges: { _ in throw SaveFailure.expected })

        #expect(throws: SaveFailure.expected) {
            try service.save(draft: TodoDraft(title: "New"), modelContext: context, now: monday)
        }
        #expect(!context.hasChanges)
        #expect(try context.fetch(FetchDescriptor<Todo>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Area>()).isEmpty)
    }

    @Test func failedTaskEditRestoresPersistedTitleAndProgress() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let area = Area(name: "Study", type: .neutral)
        let todo = Todo(title: "Original", area: area, habitOccurrence: false)
        context.insert(area)
        context.insert(todo)
        try context.save()
        var draft = TodoDraft(todo: todo)
        draft.title = "Changed"
        draft.actualProgress = 1
        let service = TaskEditingService(saveChanges: { _ in throw SaveFailure.expected })

        #expect(throws: SaveFailure.expected) {
            try service.save(draft: draft, editing: todo, modelContext: context, now: monday)
        }
        let loaded = try #require(try ModelContext(container).fetch(FetchDescriptor<Todo>()).first)
        #expect(loaded.title == "Original")
        #expect(loaded.actualProgress == 0)
        #expect(todo.title == "Original")
        #expect(!context.hasChanges)
    }

    @Test func habitWithoutSelectedWeekdaysIsRejectedWithoutMutation() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let area = makeHabit()
        context.insert(area)
        try context.save()
        var draft = AreaDraft(area: area)
        draft.name = "Changed"
        draft.goalSchedule = .weekdays
        draft.weekdayMask = 0
        let service = AreaEditingService()

        #expect(service.validationErrors(for: draft).contains(.missingWeekdays))
        #expect(throws: AreaEditingError.self) {
            try service.save(draft: draft, editing: area, modelContext: context, now: monday)
        }
        #expect(area.name == "Workout")
        #expect(area.goalSchedule == .everyDay)
        #expect(!context.hasChanges)
    }

    @Test func normalAreaCreationClearsHabitFieldsAndAppendsOrder() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let existing = Area(name: "Existing", type: .neutral, sortIndex: 8)
        context.insert(existing)
        try context.save()
        let draft = AreaDraft(name: "  Study \n", type: .neutral, symbolName: "invalid", goalEnabled: true,
                              goalTarget: 20, goalPeriod: .weekly, goalUnit: .minutes,
                              goalSchedule: .weeklyCount, weeklyTargetCount: 4, weekdayMask: 2)

        let saved = try AreaEditingService().save(draft: draft, modelContext: context, now: monday)
        let loaded = try #require(try ModelContext(container).fetch(FetchDescriptor<Area>()).first { $0.id == saved.id })

        #expect(loaded.name == "Study")
        #expect(loaded.symbolName == "🎯")
        #expect(loaded.sortIndex == 9)
        #expect(loaded.goalTarget == nil)
        #expect(loaded.goalPeriod == nil)
        #expect(loaded.goalUnit == nil)
        #expect(loaded.goalSchedule == nil)
        #expect(loaded.weeklyTargetCount == nil)
        #expect(loaded.weekdayMask == nil)
    }

    @Test func areaScheduleEditReconcilesUnstartedHabitTasksAndPreservesHistory() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let area = makeHabit()
        let past = Todo(title: "Past", area: area, habitOccurrence: true, scheduledDate: sunday)
        let future = Todo(title: "Future", area: area, habitOccurrence: true, scheduledDate: wednesday)
        let started = Todo(title: "Started", area: area, habitOccurrence: true, actualProgress: 1, scheduledDate: monday)
        let manual = Todo(title: "Independent", area: area, habitOccurrence: false, scheduledDate: wednesday)
        context.insert(area)
        [past, future, started, manual].forEach(context.insert)
        try context.save()
        var draft = AreaDraft(area: area)
        draft.goalSchedule = .weekdays
        draft.weekdayMask = GoalWeekday.tuesday.rawValue

        _ = try AreaEditingService(calendar: calendar).save(draft: draft, editing: area, modelContext: context, now: monday)
        let all = try ModelContext(container).fetch(FetchDescriptor<Todo>())

        #expect(try #require(all.first { $0.id == future.id }).isDeleted)
        #expect(try #require(all.first { $0.id == past.id }).isDeleted == false)
        #expect(try #require(all.first { $0.id == started.id }).actualProgress == 1)
        #expect(try #require(all.first { $0.id == started.id }).isDeleted == false)
        #expect(try #require(all.first { $0.id == manual.id }).isDeleted == false)
        #expect(all.contains { !$0.isDeleted && $0.isHabitOccurrence && $0.scheduledDate == tuesday })
    }

    @Test func failedAreaScheduleEditRollsBackAreaAndReconciliation() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let area = makeHabit()
        let future = Todo(title: "Future", area: area, habitOccurrence: true, scheduledDate: wednesday)
        context.insert(area)
        context.insert(future)
        try context.save()
        var draft = AreaDraft(area: area)
        draft.goalSchedule = .weekdays
        draft.weekdayMask = GoalWeekday.tuesday.rawValue
        let service = AreaEditingService(calendar: calendar, saveChanges: { _ in throw SaveFailure.expected })

        #expect(throws: SaveFailure.expected) {
            try service.save(draft: draft, editing: area, modelContext: context, now: monday)
        }
        let loadedArea = try #require(try ModelContext(container).fetch(FetchDescriptor<Area>()).first)
        let loadedTasks = try ModelContext(container).fetch(FetchDescriptor<Todo>())
        #expect(loadedArea.goalSchedule == .everyDay)
        #expect(loadedTasks.count == 1)
        #expect(loadedTasks.first?.isDeleted == false)
        #expect(!future.isDeleted)
        #expect(!context.hasChanges)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeHabit() -> Area {
        Area(name: "Workout", type: .habit, goalTarget: 30, goalPeriod: .daily,
             goalUnit: .minutes, goalSchedule: .everyDay)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var sunday: Date { date(5) }
    private var monday: Date { date(6) }
    private var tuesday: Date { date(7) }
    private var wednesday: Date { date(8) }

    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day))!
    }

    private enum SaveFailure: Error, Equatable {
        case expected
    }
}
