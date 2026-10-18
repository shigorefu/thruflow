import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct TaskTimingTests {
    @Test func quickInputReadsStrictClockTimeWithoutChangingDuration() {
        let parser = TaskQuickInputParser()
        let result = parser.parse("[25m] Read 09:30 18:45 #Study")
        #expect(result.title == "Read")
        #expect(result.timeMinutes == 18 * 60 + 45)
        #expect(result.measurement == .minutes)
        #expect(result.plannedAmount == 25)
        #expect(result.hashtags == ["Study"])
        #expect(parser.parse("Task 00:00").timeMinutes == 0)
        #expect(parser.parse("Task 23:59").timeMinutes == 1439)
    }

    @Test func invalidOrPartialClockTokensStayInTitle() {
        let parser = TaskQuickInputParser()
        for token in ["9:30", "09:3", "09:", "24:00", "23:60", "-1:20", "０９:３０", "09:30:00", "at09:30"] {
            let result = parser.parse("Task \(token)")
            #expect(result.title == "Task \(token)")
            #expect(result.timeMinutes == nil)
        }
        let editing = parser.parse("Task 09:30", consumeTrailingToken: false)
        #expect(editing.title == "Task 09:30")
        #expect(editing.timeMinutes == nil)
        let committed = parser.parse("Task 09:30 ", consumeTrailingToken: false)
        #expect(committed.title == "Task ")
        #expect(committed.timeMinutes == 570)
    }

    @Test func clockAndReminderPersistSeparatelyFromTaskDateAndDuration() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "Reading", type: .neutral)
        context.insert(area)
        let task = try TaskEditingService().save(
            draft: TodoDraft(title: "Book", area: area, measurement: .minutes, plannedAmount: 25,
                             scheduledDate: day, scheduledTimeMinutes: 570, reminderEnabled: true),
            modelContext: context, now: day
        )
        let loaded = try #require(try ModelContext(container).fetch(FetchDescriptor<Todo>()).first)
        #expect(loaded.id == task.id)
        #expect(loaded.scheduledDate == day)
        #expect(loaded.scheduledTimeMinutes == 570)
        #expect(loaded.reminderEnabled)
        #expect(loaded.plannedAmount == 25)
        #expect(loaded.actualProgress == 0)
        #expect(TodoDraft(todo: loaded).scheduledTimeMinutes == 570)
    }

    @Test func noDateAndRemovedTimeClearReminderAtSaveBoundary() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "Reading", type: .neutral)
        context.insert(area)
        let service = TaskEditingService()
        let task = try service.save(
            draft: TodoDraft(area: area, scheduledDate: day, scheduledTimeMinutes: 570, reminderEnabled: true),
            modelContext: context
        )
        var draft = TodoDraft(todo: task)
        draft.scheduledDate = nil
        _ = try service.save(draft: draft, editing: task, modelContext: context)
        #expect(task.scheduledDate == nil)
        #expect(task.scheduledTimeMinutes == nil)
        #expect(!task.reminderEnabled)

        draft = TodoDraft(todo: task)
        draft.scheduledDate = day
        draft.scheduledTimeMinutes = nil
        draft.reminderEnabled = true
        _ = try service.save(draft: draft, editing: task, modelContext: context)
        #expect(!task.reminderEnabled)
        let undated = try service.save(
            draft: TodoDraft(area: area, scheduledDate: nil, scheduledTimeMinutes: 570, reminderEnabled: true),
            modelContext: context
        )
        #expect(undated.scheduledTimeMinutes == nil)
        #expect(!undated.reminderEnabled)
    }

    @Test func settingClockDoesNotImplicitlyEnableReminderAndRejectsInvalidMinutes() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "Work", type: .neutral)
        context.insert(area)
        let service = TaskEditingService()
        let task = try service.save(
            draft: TodoDraft(area: area, scheduledDate: day, scheduledTimeMinutes: 0),
            modelContext: context
        )
        #expect(task.scheduledTimeMinutes == 0)
        #expect(!task.reminderEnabled)
        for minutes in [-1, 1440] {
            var draft = TodoDraft(todo: task)
            draft.scheduledTimeMinutes = minutes
            #expect(service.validationErrors(for: draft, editing: task).contains(.invalidScheduledTime))
            #expect(throws: TaskEditingError.self) {
                try service.save(draft: draft, editing: task, modelContext: context)
            }
            #expect(task.scheduledTimeMinutes == 0)
        }
    }

    @Test func habitOccurrenceCanChangeClockWithoutChangingItsStructureOrDate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "Habit", type: .habit)
        let other = Area(name: "Other", type: .neutral)
        context.insert(area)
        context.insert(other)
        let occurrence = Todo(title: "Study", area: area, habitOccurrence: true,
                              measurement: .minutes, plannedAmount: 30, scheduledDate: day)
        context.insert(occurrence)
        try context.save()
        var draft = TodoDraft(todo: occurrence)
        draft.area = other
        draft.measurement = .checkbox
        draft.scheduledDate = day.addingTimeInterval(86_400)
        draft.scheduledTimeMinutes = 19 * 60
        draft.reminderEnabled = true
        _ = try TaskEditingService().save(draft: draft, editing: occurrence, modelContext: context)
        #expect(occurrence.area?.id == area.id)
        #expect(occurrence.isHabitOccurrence)
        #expect(occurrence.measurement == .minutes)
        #expect(occurrence.plannedAmount == 30)
        #expect(occurrence.scheduledDate == day)
        #expect(occurrence.scheduledTimeMinutes == 1140)
        #expect(occurrence.reminderEnabled)
    }

    @Test func failedTaskSaveRestoresClockAndReminder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "Work", type: .neutral)
        context.insert(area)
        let task = try TaskEditingService().save(
            draft: TodoDraft(area: area, scheduledDate: day, scheduledTimeMinutes: 570, reminderEnabled: true),
            modelContext: context
        )
        let timingRevision = task.scheduledTimeUpdatedAt
        var draft = TodoDraft(todo: task)
        draft.scheduledTimeMinutes = 600
        draft.reminderEnabled = false
        #expect(throws: SaveFailure.self) {
            try TaskEditingService(saveChanges: { _ in throw SaveFailure.expected })
                .save(draft: draft, editing: task, modelContext: context)
        }
        #expect(task.scheduledTimeMinutes == 570)
        #expect(task.reminderEnabled)
        let loaded = try #require(try ModelContext(container).fetch(FetchDescriptor<Todo>()).first)
        #expect(loaded.scheduledTimeMinutes == 570)
        #expect(loaded.reminderEnabled)
        #expect(task.scheduledTimeUpdatedAt == timingRevision)
        #expect(loaded.scheduledTimeUpdatedAt == timingRevision)
    }

    @Test func reschedulingPreservesClockButMovingToNoDateClearsIt() {
        let area = Area(name: "Work", type: .neutral)
        let task = timedTask(area: area, minutes: 570)
        let tomorrow = day.addingTimeInterval(86_400)
        task.reschedule(to: tomorrow, now: day)
        #expect(task.scheduledTimeMinutes == 570)
        #expect(task.reminderEnabled)
        let request = TaskReminderPlan().requests(todos: [task], calendar: calendar, now: day).first
        #expect(request?.fireDate == tomorrow.addingTimeInterval(570 * 60))
        task.reschedule(to: nil, now: day)
        #expect(task.scheduledTimeMinutes == nil)
        #expect(!task.reminderEnabled)
    }

    @Test func reminderPlanExcludesPastAndIneligibleTasks() {
        let area = Area(name: "Work", type: .neutral)
        let archivedArea = Area(name: "Archived", type: .neutral)
        archivedArea.archivedAt = day
        let future = timedTask(area: area, minutes: 11 * 60)
        let past = timedTask(area: area, minutes: 9 * 60)
        let current = timedTask(area: area, minutes: 10 * 60)
        let completed = timedTask(area: area, minutes: 11 * 60)
        completed.setManuallyCompleted(true, now: day)
        let archived = timedTask(area: area, minutes: 11 * 60)
        archived.archive(now: day)
        let deleted = timedTask(area: area, minutes: 11 * 60)
        deleted.softDelete(now: day)
        let inactiveAreaTask = timedTask(area: archivedArea, minutes: 11 * 60)
        let disabled = timedTask(area: area, minutes: 11 * 60)
        disabled.reminderEnabled = false
        let undated = timedTask(area: area, minutes: 11 * 60)
        undated.scheduledDate = nil
        let noTime = timedTask(area: area, minutes: 11 * 60)
        noTime.scheduledTimeMinutes = nil
        let orphan = timedTask(area: area, minutes: 11 * 60)
        orphan.area = nil
        let requests = TaskReminderPlan().requests(
            todos: [future, past, current, completed, archived, deleted, inactiveAreaTask, disabled, undated, noTime, orphan],
            calendar: calendar, now: day.addingTimeInterval(10 * 3600)
        )
        #expect(requests.map(\.taskID) == [future.id])
        #expect(requests.first?.body == "Task")
        #expect(requests.first?.identifier == TaskReminderRequest.prefix + future.id.uuidString)
    }

    @Test func clockUsesSelectedCivilDateEvenBeforeFlowDayBoundary() throws {
        let area = Area(name: "Work", type: .neutral)
        let task = timedTask(area: area, minutes: 90)
        let request = try #require(TaskReminderPlan().requests(todos: [task], calendar: calendar, now: day).first)
        #expect(request.fireDate == day.addingTimeInterval(90 * 60))
        #expect(calendar.isDate(request.fireDate, inSameDayAs: day))
    }

    @Test func clockHandlesMissingAndRepeatedDaylightSavingTimes() throws {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let springDay = try #require(newYork.date(from: DateComponents(year: 2026, month: 3, day: 8)))
        let spring = try #require(TaskTimeFormatting.date(on: springDay, minutes: 150, calendar: newYork))
        let springParts = newYork.dateComponents([.day, .hour, .minute], from: spring)
        #expect(springParts.day == 8)
        #expect(springParts.hour == 3)
        #expect(springParts.minute == 0)
        let autumnDay = try #require(newYork.date(from: DateComponents(year: 2026, month: 11, day: 1)))
        let autumn = try #require(TaskTimeFormatting.date(on: autumnDay, minutes: 90, calendar: newYork))
        #expect(newYork.component(.hour, from: autumn) == 1)
        #expect(newYork.component(.minute, from: autumn) == 30)
        #expect(newYork.timeZone.secondsFromGMT(for: autumn) == -4 * 3600)
    }

    @Test func reminderQueueKeepsNearestSixtyAndRefillsAfterEarlierTimesPass() {
        let area = Area(name: "Work", type: .neutral)
        let tasks = (0..<65).map { timedTask(area: area, minutes: 600 + $0) }.reversed()
        let plan = TaskReminderPlan()
        let requests = plan.requests(todos: Array(tasks), calendar: calendar, now: day)
        #expect(requests.count == 60)
        #expect(requests.first?.fireDate == day.addingTimeInterval(600 * 60))
        #expect(requests.last?.fireDate == day.addingTimeInterval(659 * 60))
        let refill = plan.requests(todos: Array(tasks), calendar: calendar, now: day.addingTimeInterval(604 * 60))
        #expect(refill.count == 60)
        #expect(refill.last?.fireDate == day.addingTimeInterval(664 * 60))
        #expect(plan.requests(todos: Array(tasks), calendar: calendar, now: day, limit: 0).isEmpty)
    }

    @Test func timingRevisionChangesOnlyForExplicitClockOrReminderChanges() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "Work", type: .neutral)
        context.insert(area)
        let service = TaskEditingService()
        let task = try service.save(
            draft: TodoDraft(area: area, scheduledDate: day, scheduledTimeMinutes: 570, reminderEnabled: true),
            modelContext: context, now: day
        )
        #expect(task.scheduledTimeUpdatedAt == day)
        var draft = TodoDraft(todo: task)
        draft.title = "Renamed"
        _ = try service.save(draft: draft, editing: task, modelContext: context, now: day.addingTimeInterval(100))
        #expect(task.scheduledTimeUpdatedAt == day)
        draft = TodoDraft(todo: task)
        draft.reminderEnabled = false
        _ = try service.save(draft: draft, editing: task, modelContext: context, now: day.addingTimeInterval(200))
        #expect(task.scheduledTimeUpdatedAt == day.addingTimeInterval(200))
        draft = TodoDraft(todo: task)
        draft.scheduledTimeMinutes = nil
        _ = try service.save(draft: draft, editing: task, modelContext: context, now: day.addingTimeInterval(300))
        #expect(task.scheduledTimeUpdatedAt == day.addingTimeInterval(300))
        #expect(task.scheduledTimeMinutes == nil)
        #expect(!task.reminderEnabled)
    }

    @Test func duplicateHabitRetainsExplicitTimingDespiteNewerUntimedGeneration() throws {
        let area = Area(name: "Study", type: .habit)
        let canonical = Todo(title: "Keep", area: area, habitOccurrence: true, scheduledDate: day,
                             createdAt: day, updatedAt: day.addingTimeInterval(300))
        let configured = Todo(title: "", area: area, habitOccurrence: true, scheduledDate: day,
                              scheduledTimeMinutes: 570, reminderEnabled: true,
                              createdAt: day.addingTimeInterval(10), updatedAt: day.addingTimeInterval(100))
        configured.scheduledTimeUpdatedAt = day.addingTimeInterval(100)
        let generated = Todo(title: "", area: area, habitOccurrence: true, scheduledDate: day,
                             createdAt: day.addingTimeInterval(400), updatedAt: day.addingTimeInterval(400))
        #expect(generated.scheduledTimeUpdatedAt == nil)
        let result = HabitTodoReconciler(calendar: calendar).reconcile(
            todos: [generated, configured, canonical], sessions: [], segments: [], now: day.addingTimeInterval(500)
        )
        #expect(result.canonicalTodos.first?.id == canonical.id)
        #expect(canonical.scheduledTimeMinutes == 570)
        #expect(canonical.reminderEnabled)
        #expect(canonical.scheduledTimeUpdatedAt == configured.scheduledTimeUpdatedAt)
        #expect(configured.isDeleted)
        #expect(generated.isDeleted)
    }

    @Test func duplicateHabitPreservesLaterExplicitClearDespiteUnrelatedProgressTimestamp() {
        let area = Area(name: "Study", type: .habit)
        let canonical = Todo(title: "Keep", area: area, habitOccurrence: true, scheduledDate: day,
                             scheduledTimeMinutes: 570, reminderEnabled: true,
                             createdAt: day, updatedAt: day.addingTimeInterval(900))
        canonical.scheduledTimeUpdatedAt = day.addingTimeInterval(100)
        let cleared = Todo(title: "", area: area, habitOccurrence: true, scheduledDate: day,
                           createdAt: day.addingTimeInterval(10), updatedAt: day.addingTimeInterval(200))
        cleared.scheduledTimeUpdatedAt = day.addingTimeInterval(200)
        _ = HabitTodoReconciler(calendar: calendar).reconcile(
            todos: [cleared, canonical], sessions: [], segments: [], now: day.addingTimeInterval(1000)
        )
        #expect(canonical.scheduledTimeMinutes == nil)
        #expect(!canonical.reminderEnabled)
        #expect(canonical.scheduledTimeUpdatedAt == day.addingTimeInterval(200))
    }

    @Test func duplicateTimingConflictResolvesIdenticallyRegardlessOfInputOrder() {
        func mergedTime(reversed: Bool) -> Int? {
            let area = Area(name: "Study", type: .habit)
            let canonical = Todo(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                                 title: "Keep", area: area, habitOccurrence: true, scheduledDate: day)
            let first = Todo(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                             title: "", area: area, habitOccurrence: true, scheduledDate: day,
                             scheduledTimeMinutes: 570, reminderEnabled: true, updatedAt: day)
            let second = Todo(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                              title: "", area: area, habitOccurrence: true, scheduledDate: day,
                              scheduledTimeMinutes: 600, reminderEnabled: false, updatedAt: day)
            let records = reversed ? [second, first, canonical] : [canonical, first, second]
            _ = HabitTodoReconciler(calendar: calendar).reconcile(todos: records, sessions: [], segments: [], now: day)
            return canonical.scheduledTimeMinutes
        }
        #expect(mergedTime(reversed: false) == 570)
        #expect(mergedTime(reversed: true) == 570)
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private var day: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 18))!
    }

    private func timedTask(area: Area, minutes: Int) -> Todo {
        Todo(title: "Task", area: area, scheduledDate: day, scheduledTimeMinutes: minutes, reminderEnabled: true)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = AppModelContainerFactory.schema
        return try ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        ])
    }

    private enum SaveFailure: Error { case expected }
}
