import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct HabitRestScheduleTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        value.firstWeekday = 2
        return value
    }

    private func day(_ number: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: number, hour: hour))!
    }

    private func area(rest: Int = 1, target: Int = 3) -> Area {
        Area(name: "Exercise", type: .habit, goalTarget: 1, goalPeriod: .weekly,
             goalUnit: .occurrences, goalSchedule: .weeklyCount,
             weeklyTargetCount: target, minimumRestDays: rest)
    }

    private func completed(_ area: Area, scheduled: Int, at completion: Int, hour: Int = 12) -> Todo {
        let task = Todo(title: "", area: area, scheduledDate: day(scheduled))
        task.setCompleted(true, now: day(completion, hour: hour))
        return task
    }

    private func container() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: Area.self, Project.self, Todo.self, FlowSession.self,
                                  FlowSegment.self, FlowBreak.self, configurations: config)
    }

    @Test(arguments: 0...6)
    func exactNumberOfFullLogicalDaysIsReserved(rest: Int) {
        let habit = area(rest: rest, target: 1)
        let task = completed(habit, scheduled: 13, at: 13)
        let planner = RequiredTodoPlanner(calendar: calendar)
        for offset in 1...7 {
            let isRest = planner.isRestDay(for: HabitDefinition(area: habit), in: [task], on: day(13 + offset))
            #expect(isRest == (offset <= rest))
        }
    }

    @Test func completionDateAndDayBoundaryControlCrossWeekRest() {
        let habit = area()
        let task = completed(habit, scheduled: 11, at: 14, hour: 1)
        let planner = RequiredTodoPlanner(calendar: calendar, dayBoundary: AppDayBoundary(hour: 2))
        // Monday 01:00 belongs to Sunday. Monday is rest, Tuesday is eligible.
        #expect(!planner.shouldCreateRequiredTodo(for: habit, in: [task], on: day(14)))
        #expect(planner.shouldCreateRequiredTodo(for: habit, in: [task], on: day(15)))
        let midnightPlanner = RequiredTodoPlanner(calendar: calendar)
        #expect(!midnightPlanner.shouldCreateRequiredTodo(for: habit, in: [task], on: day(15)))
        #expect(midnightPlanner.shouldCreateRequiredTodo(for: habit, in: [task], on: day(16)))
    }

    @Test func incompleteAndOtherOwnersDoNotStartRest() throws {
        let habit = area()
        let partial = Todo(title: "", area: habit, measurement: .minutes, plannedAmount: 40,
                           focusDurationSeconds: 1200, scheduledDate: day(7))
        let unrelated = completed(area(), scheduled: 7, at: 7)
        let planner = RequiredTodoPlanner(calendar: calendar)
        #expect(planner.shouldCreateRequiredTodo(for: habit, in: [partial, unrelated], on: day(8)))
        let project = Project(name: "Report", area: habit)
        project.habitSettings = ProjectHabitSettings(isEnabled: true, goalSchedule: .weeklyCount,
            weeklyTargetCount: 3, minimumRestDays: 1, startsOn: day(1))
        let projectTask = Todo(title: "", area: habit, project: project, habitOccurrence: true,
                               scheduledDate: day(7))
        projectTask.setCompleted(true, now: day(7, hour: 12))
        let definition = try #require(HabitDefinition(project: project))
        #expect(!planner.shouldCreateRequiredTodo(for: definition, in: [projectTask], on: day(8)))
        #expect(planner.shouldCreateRequiredTodo(for: habit, in: [projectTask], on: day(8)))
        #expect(planner.shouldCreateRequiredTodo(for: definition, in: [projectTask], on: day(9)))
        projectTask.setCompleted(false, now: day(8))
        #expect(planner.shouldCreateRequiredTodo(for: definition, in: [projectTask], on: day(8)))
    }

    @Test func validatorRejectsImpossibleRepeatingWeeksIncludingWeekBoundary() {
        #expect(HabitRestSchedule.maximumWeeklyCount(minimumRestDays: 0, weekdayMask: nil) == 7)
        #expect(HabitRestSchedule.maximumWeeklyCount(minimumRestDays: 1, weekdayMask: nil) == 3)
        #expect(HabitRestSchedule.maximumWeeklyCount(minimumRestDays: 2, weekdayMask: nil) == 2)
        #expect(HabitRestSchedule.maximumWeeklyCount(minimumRestDays: 6, weekdayMask: nil) == 1)
        var draft = AreaDraft(area: area(target: 4))
        #expect(AreaValidator().validate(draft).contains(.impossibleRestSchedule))
        draft.weeklyTargetCount = 3
        #expect(AreaValidator().validate(draft).isEmpty)
        draft.weekdayMask = GoalWeekday.monday.rawValue | GoalWeekday.tuesday.rawValue | GoalWeekday.friday.rawValue
        #expect(AreaValidator().validate(draft).contains(.impossibleRestSchedule))
        draft.weeklyTargetCount = 2
        #expect(AreaValidator().validate(draft).isEmpty)
        draft.minimumRestDays = 7
        #expect(AreaValidator().validate(draft).contains(.invalidMinimumRestDays))
        draft.minimumRestDays = 0
        draft.weeklyTargetCount = 4
        #expect(AreaValidator().validate(draft).isEmpty)
    }

    @Test func moveOptionsReserveEnoughSpacedDaysAndRejectRestDates() {
        let habit = area()
        let task = Todo(title: "", area: habit, scheduledDate: day(7))
        let planner = RequiredTodoPlanner(calendar: calendar)
        let options = planner.weeklyRescheduleOptions(for: task, in: [task], now: day(7))
        #expect(options.first { $0.date == day(9) }?.isAllowed == true)
        #expect(options.first { $0.date == day(10) }?.isAllowed == false)
        let done = completed(habit, scheduled: 7, at: 7)
        let remaining = Todo(title: "", area: habit, scheduledDate: day(9))
        let afterCompletion = planner.weeklyRescheduleOptions(for: remaining, in: [done, remaining], now: day(8))
        #expect(afterCompletion.first { $0.date == day(8) }?.isAllowed == false)
        #expect(afterCompletion.first { $0.date == day(9) }?.isAllowed == true)
        let validator = TaskRescheduleService(calendar: calendar)
        if case .success = validator.validate(remaining, movingTo: day(8), among: [done, remaining]) {
            Issue.record("A rest day was allowed")
        }
    }

    @Test func materializerRetiresOnlyUnusedRestOccurrencesAndIsIdempotent() throws {
        let store = try container()
        let context = store.mainContext
        let habit = area()
        context.insert(habit)
        let done = completed(habit, scheduled: 7, at: 7)
        let unused = Todo(title: "", area: habit, scheduledDate: day(8))
        let worked = Todo(title: "", area: habit, measurement: .minutes,
                          plannedAmount: 40, focusDurationSeconds: 300, scheduledDate: day(9))
        context.insert(done); context.insert(unused); context.insert(worked)
        // Use checkbox progress so a history reconciliation does not clear it.
        worked.measurement = .checkbox
        worked.actualProgress = 1
        habit.minimumRestDays = 2
        try context.save()
        let materializer = HabitTodoMaterializer(calendar: calendar)
        #expect(try materializer.materialize(areas: [habit], dates: [day(8)], modelContext: context, now: day(8, hour: 12)))
        #expect(unused.isDeleted)
        #expect(!worked.isDeleted)
        #expect(done.isCompleted)
        #expect(try !materializer.materialize(areas: [habit], dates: [day(8)], modelContext: context, now: day(8, hour: 12)))
        #expect(try materializer.materialize(areas: [habit], dates: [day(10)], modelContext: context, now: day(10, hour: 12)))
        #expect(!worked.isDeleted)
        #expect(try context.fetch(FetchDescriptor<Todo>()).contains { !$0.isDeleted && $0.scheduledDate == day(10) })
    }

    @Test func optionalSettingsReloadAndOldProjectJSONDecodes() throws {
        let old = Data("""
        {"isEnabled":true,"goalTarget":1,"goalUnit":"occurrences","goalSchedule":"weeklyCount",
         "weeklyTargetCount":3,"inactivePeriods":[]}
        """.utf8)
        let settings = try JSONDecoder().decode(ProjectHabitSettings.self, from: old)
        #expect(settings.minimumRestDays == nil)
        #expect(settings.weeklyTargetCount == 3)
        let store = try container()
        let context = store.mainContext
        let habit = try AreaEditingService(calendar: calendar).save(
            draft: AreaDraft(area: area()), modelContext: context, now: day(7))
        let project = try ProjectEditingService(calendar: calendar).save(
            name: "Report", area: habit,
            habit: ProjectHabitSettings(isEnabled: true, goalSchedule: .weeklyCount,
                weeklyTargetCount: 3, minimumRestDays: 1),
            modelContext: context, now: day(7))
        let reloaded = ModelContext(store)
        let loadedArea = try #require(try reloaded.fetch(FetchDescriptor<Area>()).first { $0.id == habit.id })
        let loadedProject = try #require(try reloaded.fetch(FetchDescriptor<Project>()).first { $0.id == project.id })
        #expect(loadedArea.minimumRestDays == 1)
        #expect(loadedProject.habitSettings?.minimumRestDays == 1)
        #expect(AreaDraft(area: loadedArea).minimumRestDays == 1)
    }

    @Test func failedAreaSaveRestoresRestSetting() throws {
        struct SaveFailure: Error {}
        let store = try container()
        let context = store.mainContext
        let habit = area()
        context.insert(habit)
        try context.save()
        var draft = AreaDraft(area: habit)
        draft.minimumRestDays = 2
        draft.weeklyTargetCount = 2
        do {
            try AreaEditingService(calendar: calendar, saveChanges: { _ in throw SaveFailure() })
                .save(draft: draft, editing: habit, modelContext: context, now: day(7))
            Issue.record("Save should fail")
        } catch is SaveFailure {}
        #expect(habit.minimumRestDays == 1)
        #expect(habit.weeklyTargetCount == 3)
    }
}
