//
//  TodoTests.swift
//  ThruFlowTests
//
//

import Foundation
import SwiftData
import Testing
@testable import ThruFlow

struct TodoTests {

    @Test func checkboxProgressCompletesWhenChecked() {
        let calculator = TodoProgressCalculator()

        #expect(calculator.progress(measurement: .checkbox, plannedAmount: nil, actualProgress: 0) == 0)
        #expect(calculator.progress(measurement: .checkbox, plannedAmount: nil, actualProgress: 1) == 1)
        #expect(calculator.status(measurement: .checkbox, plannedAmount: nil, actualProgress: 1) == .completed)
    }

    @Test func manualCompletionOnlyChangesCheckboxTasks() {
        let area = Area(name: "生活", type: .neutral)
        let checkbox = Todo(title: "確認", area: area, measurement: .checkbox)
        let blocks = Todo(title: "読書", area: area, measurement: .focusBlocks, plannedAmount: 2)
        let minutes = Todo(title: "散歩", area: area, measurement: .minutes, plannedAmount: 30)

        #expect(checkbox.setManuallyCompleted(true))
        #expect(checkbox.isCompleted)
        #expect(!blocks.setManuallyCompleted(true))
        #expect(!minutes.setManuallyCompleted(true))
        #expect(!blocks.isCompleted)
        #expect(!minutes.isCompleted)
        #expect(blocks.actualProgress == 0)
        #expect(minutes.actualProgress == 0)
    }

    @Test func blockProgressClampsAtCompletion() {
        let calculator = TodoProgressCalculator()

        #expect(calculator.progress(measurement: .focusBlocks, plannedAmount: 3, actualProgress: 1) == 1.0 / 3.0)
        #expect(calculator.progress(measurement: .focusBlocks, plannedAmount: 3, actualProgress: 4) == 1)
        #expect(calculator.status(measurement: .focusBlocks, plannedAmount: 3, actualProgress: 2) == .active)
        #expect(calculator.status(measurement: .focusBlocks, plannedAmount: 3, actualProgress: 3) == .completed)
    }

    @Test func minuteProgressIgnoresNegativeActualValues() {
        let calculator = TodoProgressCalculator()

        #expect(calculator.progress(measurement: .minutes, plannedAmount: 30, actualProgress: -5) == 0)
    }

    @Test func todoDraftAllowsEmptyTitleAndMissingAreaButRequiresPlannedAmount() {
        let draft = TodoDraft(
            title: " ",
            area: nil,
            measurement: .focusBlocks,
            plannedAmount: 0
        )

        let errors = TodoValidator().validate(draft)

        #expect(errors == [.invalidPlannedAmount])
    }

    @Test func historyRenameTrimsAndUpdatesAnyTaskTitle() {
        let area = Area(name: "読書", type: .neutral)
        let createdAt = Date(timeIntervalSince1970: 100)
        let renamedAt = Date(timeIntervalSince1970: 200)
        let todo = Todo(
            title: "古い名前",
            area: area,
            createdAt: createdAt,
            updatedAt: createdAt
        )

        #expect(todo.rename(to: "  新しい名前\n", now: renamedAt))
        #expect(todo.title == "新しい名前")
        #expect(todo.updatedAt == renamedAt)
    }

    @Test func historyRenameDoesNotReplaceATaskWithAnEmptyTitle() {
        let area = Area(name: "読書", type: .neutral)
        let updatedAt = Date(timeIntervalSince1970: 100)
        let todo = Todo(
            title: "本を読む",
            area: area,
            updatedAt: updatedAt
        )

        #expect(!todo.rename(to: "  \n", now: Date(timeIntervalSince1970: 200)))
        #expect(todo.title == "本を読む")
        #expect(todo.updatedAt == updatedAt)
    }

    @Test func defaultTaskInboxUsesLocalizedNameAndStableSystemProperties() {
        let area = DefaultAreas.makeTaskInbox(now: Date(timeIntervalSince1970: 0))

        #expect(area.name == DefaultAreas.taskInboxName)
        #expect(area.type == .neutral)
        #expect(area.symbolName == "📝")
        #expect(area.colorHex == "#007AFF")
        #expect(DefaultAreas.isTaskInbox(area))
    }

    @Test func userAreaIsNotTaskInboxColorlessDefault() {
        let area = Area(name: "仕事", type: .neutral)

        #expect(!DefaultAreas.isTaskInbox(area))
    }

    @Test func activeUnscheduledTodoDoesNotAppearInDailyTasks() {
        let area = Area(name: "仕事", type: .neutral)
        let todo = Todo(title: "資料を作る", area: area)

        #expect(!TodayTodoFilter().includes(todo, on: Date(timeIntervalSince1970: 0)))
    }

    @Test func archivedTodoDoesNotAppearInToday() {
        let area = Area(name: "仕事", type: .neutral)
        let todo = Todo(title: "資料を作る", area: area)

        todo.archive(now: Date(timeIntervalSince1970: 100))

        #expect(!TodayTodoFilter().includes(todo, on: Date(timeIntervalSince1970: 0)))
    }

    @Test func scheduledTodoAppearsOnlyOnMatchingDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let area = Area(name: "仕事", type: .neutral)
        let scheduledDate = Date(timeIntervalSince1970: 86_400)
        let todo = Todo(title: "資料を作る", area: area, scheduledDate: scheduledDate)

        let filter = TodayTodoFilter(calendar: calendar)

        #expect(filter.includes(todo, on: Date(timeIntervalSince1970: 86_400 + 60)))
        #expect(!filter.includes(todo, on: Date(timeIntervalSince1970: 0)))
    }

    @Test func dailyHabitAreaCreatesTodayTodoDraft() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let area = Area(
            name: "読書",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .daily,
            goalUnit: .focusBlocks,
            goalSchedule: .everyDay
        )
        let planner = RequiredTodoPlanner(calendar: calendar)
        let date = Date(timeIntervalSince1970: 0)
        let todo = planner.makeRequiredTodo(for: area, on: date)

        #expect(todo?.title == "")
        #expect(todo?.measurement == .focusBlocks)
        #expect(todo?.priority == .high)
        #expect(todo?.isRoomIfPossible == false)
        #expect(todo?.plannedAmount == 1)
        #expect(todo?.scheduledDate == date)
    }

    @Test func generatedHabitDateIsNormalizedToCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let area = Area(
            name: "読書",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .daily,
            goalUnit: .occurrences,
            goalSchedule: .everyDay
        )
        let planner = RequiredTodoPlanner(calendar: calendar)
        let afternoon = date(2026, 7, 24, calendar: calendar).addingTimeInterval(15 * 3_600)

        #expect(
            planner.makeRequiredTodo(for: area, on: afternoon)?.scheduledDate ==
                calendar.startOfDay(for: afternoon)
        )
    }

    @Test func duplicateHabitOccurrencesKeepHistoryAndSoftDeleteTheEmptyDuplicate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let day = date(2026, 7, 24, calendar: calendar)
        let area = weeklyHabitArea()
        let emptyDuplicate = Todo(
            title: "",
            area: area,
            scheduledDate: day,
            createdAt: day
        )
        let recordedDuplicate = Todo(
            title: "上半身",
            area: area,
            scheduledDate: day.addingTimeInterval(15 * 3_600),
            createdAt: day.addingTimeInterval(60)
        )
        let session = FlowSession(
            area: area,
            todo: recordedDuplicate,
            mode: .sprint,
            startedAt: day.addingTimeInterval(15 * 3_600),
            plannedEndAt: day.addingTimeInterval((15 * 3_600) + 720),
            plannedFocusDurationSeconds: 720,
            plannedBreakDurationSeconds: 180
        )

        let result = HabitTodoReconciler(calendar: calendar).reconcile(
            todos: [emptyDuplicate, recordedDuplicate],
            sessions: [session],
            segments: [],
            now: day.addingTimeInterval(16 * 3_600)
        )

        #expect(result.changed)
        #expect(result.canonicalTodos.map(\.id) == [recordedDuplicate.id])
        #expect(session.todo?.id == recordedDuplicate.id)
        #expect(emptyDuplicate.isDeleted)
        #expect(!recordedDuplicate.isDeleted)
        #expect(recordedDuplicate.scheduledDate == day)
    }

    @Test func duplicateCompletedCheckboxHabitPreservesCompletion() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let day = date(2026, 7, 24, calendar: calendar)
        let area = weeklyHabitArea()
        let active = Todo(title: "", area: area, scheduledDate: day, createdAt: day)
        let completed = Todo(
            title: "",
            area: area,
            scheduledDate: day.addingTimeInterval(9 * 3_600),
            createdAt: day.addingTimeInterval(60)
        )
        completed.setCompleted(true, now: day.addingTimeInterval(10 * 3_600))

        let result = HabitTodoReconciler(calendar: calendar).reconcile(
            todos: [active, completed],
            sessions: [],
            segments: [],
            now: day.addingTimeInterval(11 * 3_600)
        )

        #expect(result.changed)
        #expect(completed.isCompleted)
        #expect(active.isDeleted)
        #expect(!completed.isDeleted)
    }

    @Test func weeklyCountWithoutSelectedWeekdaysCreatesCurrentTodo() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let area = Area(
            name: "筋トレ",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .weekly,
            goalUnit: .occurrences,
            goalSchedule: .weeklyCount,
            weeklyTargetCount: 3
        )
        let planner = RequiredTodoPlanner(calendar: calendar)
        let date = Date(timeIntervalSince1970: 0)

        #expect(planner.shouldAppearToday(area, on: date))
        #expect(planner.makeRequiredTodo(for: area, on: date) != nil)
    }

    @Test func movedWeeklyHabitDoesNotCreateReplacement() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let area = weeklyHabitArea()
        let planner = RequiredTodoPlanner(calendar: calendar)
        let today = date(2026, 7, 6, calendar: calendar)
        let tomorrow = date(2026, 7, 7, calendar: calendar)
        let movedTodo = Todo(title: "", area: area, scheduledDate: tomorrow)

        #expect(!planner.shouldCreateRequiredTodo(for: area, in: [movedTodo], on: today))
    }

    @Test func nextWeeklyHabitAppearsOnFollowingDayAfterCompletion() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let area = weeklyHabitArea()
        let planner = RequiredTodoPlanner(calendar: calendar)
        let monday = date(2026, 7, 6, calendar: calendar)
        let tuesday = date(2026, 7, 7, calendar: calendar)
        let completedTodo = Todo(title: "", area: area, scheduledDate: monday)
        completedTodo.setCompleted(true, now: monday)

        #expect(!planner.shouldCreateRequiredTodo(for: area, in: [completedTodo], on: monday))
        #expect(planner.shouldCreateRequiredTodo(for: area, in: [completedTodo], on: tuesday))
    }

    @Test func pendingWeeklyHabitRollsForwardWithinCurrentWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1

        let area = weeklyHabitArea()
        let planner = RequiredTodoPlanner(calendar: calendar)
        let sunday = date(2026, 7, 12, calendar: calendar)
        let wednesday = date(2026, 7, 15, calendar: calendar)
        let pendingTodo = Todo(title: "", area: area, scheduledDate: sunday)

        #expect(
            planner.pendingWeeklyTodoToRollForward(
                for: area,
                in: [pendingTodo],
                on: wednesday
            )?.id == pendingTodo.id
        )
    }

    @Test func pendingWeeklyHabitDoesNotRollBackwardOrAcrossWeeks() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1

        let area = weeklyHabitArea()
        let planner = RequiredTodoPlanner(calendar: calendar)
        let saturday = date(2026, 7, 11, calendar: calendar)
        let wednesday = date(2026, 7, 15, calendar: calendar)
        let friday = date(2026, 7, 17, calendar: calendar)
        let previousWeekTodo = Todo(title: "", area: area, scheduledDate: saturday)
        let futureTodo = Todo(title: "", area: area, scheduledDate: friday)

        #expect(
            planner.pendingWeeklyTodoToRollForward(
                for: area,
                in: [previousWeekTodo, futureTodo],
                on: wednesday
            ) == nil
        )
    }

    @Test func weeklyHabitCannotMovePastAchievableDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2

        let area = weeklyHabitArea(target: 4)
        let planner = RequiredTodoPlanner(calendar: calendar)
        let friday = date(2026, 7, 10, calendar: calendar)
        let todo = Todo(title: "", area: area, scheduledDate: friday)
        let options = planner.weeklyRescheduleOptions(for: todo, in: [todo], now: friday)

        #expect(options.first?.date == friday)
        #expect(options.allSatisfy { !$0.isAllowed })
    }

    @Test func selectedWeekdayHabitAreaAppearsOnlyOnThatWeekday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let monday = Date(timeIntervalSince1970: 4 * 86_400)
        let tuesday = Date(timeIntervalSince1970: 5 * 86_400)
        let area = Area(
            name: "Anki",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .weekly,
            goalUnit: .focusBlocks,
            goalSchedule: .weekdays,
            weekdayMask: GoalWeekday.monday.rawValue
        )
        let planner = RequiredTodoPlanner(calendar: calendar)

        #expect(planner.shouldAppearToday(area, on: monday))
        #expect(!planner.shouldAppearToday(area, on: tuesday))
    }

    @Test func pausedDailyHabitDoesNotAppearUntilPauseEnds() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = date(2026, 7, 6, calendar: calendar)
        let tuesday = date(2026, 7, 7, calendar: calendar)
        let area = Area(
            name: "読書",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .daily,
            goalUnit: .occurrences,
            goalSchedule: .everyDay
        )
        let pauseService = HabitPauseService(calendar: calendar)
        let planner = RequiredTodoPlanner(calendar: calendar)

        #expect(pauseService.pauseToday(area, todos: [], now: monday))
        #expect(!planner.shouldAppearToday(area, on: monday))
        #expect(planner.makeRequiredTodo(for: area, on: monday) == nil)
        #expect(planner.shouldAppearToday(area, on: tuesday))
    }

    @Test func indefinitelyPausedHabitCanResumeOnCurrentDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = date(2026, 7, 6, calendar: calendar)
        let area = weeklyHabitArea()
        let pauseService = HabitPauseService(calendar: calendar)

        #expect(pauseService.pauseIndefinitely(area, todos: [], now: monday))
        #expect(pauseService.isPaused(area, on: monday))
        #expect(pauseService.resume(area, now: monday))
        #expect(!pauseService.isPaused(area, on: monday))
    }

    @Test func pausingHabitSuppressesOnlyUnstartedGeneratedTodos() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = date(2026, 7, 6, calendar: calendar)
        let area = weeklyHabitArea()
        let pending = Todo(title: "", area: area, scheduledDate: monday)
        let completed = Todo(title: "", area: area, scheduledDate: monday)
        completed.setCompleted(true, now: monday)
        let progressed = Todo(
            title: "",
            area: area,
            measurement: .minutes,
            plannedAmount: 30,
            actualProgress: 5,
            scheduledDate: monday
        )
        let recorded = Todo(title: "", area: area, scheduledDate: monday)
        recorded.recordedFocusSeconds = 60

        #expect(
            HabitPauseService(calendar: calendar).pauseToday(
                area,
                todos: [pending, completed, progressed, recorded],
                now: monday
            )
        )
        #expect(pending.isDeleted)
        #expect(!completed.isDeleted)
        #expect(!progressed.isDeleted)
        #expect(!recorded.isDeleted)
    }

    @Test @MainActor func lightweightHabitMaterializationDoesNotReconcileHistory() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let schema = Schema([
            Area.self,
            Todo.self,
            FlowSession.self,
            FlowSegment.self,
            FlowBreak.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let date = Date(timeIntervalSince1970: 4 * 86_400)
        let area = Area(
            name: "読書",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .daily,
            goalUnit: .occurrences,
            goalSchedule: .everyDay
        )
        let first = Todo(title: "", area: area, scheduledDate: date)
        let duplicate = Todo(title: "", area: area, scheduledDate: date)
        context.insert(area)
        context.insert(first)
        context.insert(duplicate)

        let changed = try HabitTodoMaterializer(calendar: calendar).materialize(
            areas: [area],
            dates: [date],
            modelContext: context,
            now: date,
            knownTodos: [first, duplicate],
            reconcilesDuplicates: false
        )

        #expect(!changed)
        #expect(!first.isDeleted)
        #expect(!duplicate.isDeleted)
    }

    @Test @MainActor func habitScheduleChangeRebuildsUnstartedFutureOccurrences() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let schema = Schema([
            Area.self,
            Todo.self,
            FlowSession.self,
            FlowSegment.self,
            FlowBreak.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let monday = date(2026, 7, 6, calendar: calendar)
        let sunday = date(2026, 7, 5, calendar: calendar)
        let wednesday = date(2026, 7, 8, calendar: calendar)
        let friday = date(2026, 7, 10, calendar: calendar)
        let area = Area(
            name: "運動",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .weekly,
            goalUnit: .occurrences,
            goalSchedule: .weekdays,
            weekdayMask: GoalWeekday.monday.rawValue |
                GoalWeekday.wednesday.rawValue |
                GoalWeekday.friday.rawValue
        )
        let past = Todo(title: "", area: area, scheduledDate: sunday)
        let oldMonday = Todo(title: "", area: area, scheduledDate: monday)
        let oldWednesday = Todo(title: "", area: area, scheduledDate: wednesday)
        let oldFriday = Todo(title: "", area: area, scheduledDate: friday)
        context.insert(area)
        [past, oldMonday, oldWednesday, oldFriday].forEach(context.insert)

        area.update(
            name: area.name,
            type: .habit,
            symbolName: area.symbolName,
            colorHex: area.colorHex,
            goalTarget: 1,
            goalPeriod: .weekly,
            goalUnit: .occurrences,
            goalSchedule: .weekdays,
            weekdayMask: GoalWeekday.tuesday.rawValue | GoalWeekday.thursday.rawValue,
            now: monday
        )

        #expect(
            HabitScheduleChangeReconciler(calendar: calendar).reconcile(
                area: area,
                todos: [past, oldMonday, oldWednesday, oldFriday],
                modelContext: context,
                now: monday
            )
        )
        try context.save()

        let activeFutureDates = try context.fetch(FetchDescriptor<Todo>())
            .filter { !$0.isDeleted && ($0.scheduledDate ?? .distantPast) >= monday }
            .compactMap(\.scheduledDate)
            .map(calendar.startOfDay(for:))
            .sorted()

        #expect(activeFutureDates == [
            date(2026, 7, 7, calendar: calendar),
            date(2026, 7, 9, calendar: calendar),
        ])
        #expect(!past.isDeleted)
        #expect(oldMonday.isDeleted)
        #expect(oldWednesday.isDeleted)
        #expect(oldFriday.isDeleted)
    }

    @Test @MainActor func habitGoalChangeUpdatesOnlyUnstartedOccurrences() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let schema = Schema([
            Area.self,
            Todo.self,
            FlowSession.self,
            FlowSegment.self,
            FlowBreak.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let monday = date(2026, 7, 6, calendar: calendar)
        let tuesday = date(2026, 7, 7, calendar: calendar)
        let area = Area(
            name: "日本語",
            type: .habit,
            goalTarget: 30,
            goalPeriod: .daily,
            goalUnit: .minutes,
            goalSchedule: .everyDay
        )
        let unstarted = Todo(
            title: "復習",
            area: area,
            measurement: .minutes,
            plannedAmount: 30,
            scheduledDate: monday
        )
        let progressed = Todo(
            title: "会話",
            area: area,
            measurement: .minutes,
            plannedAmount: 30,
            actualProgress: 5,
            scheduledDate: tuesday
        )
        context.insert(area)
        context.insert(unstarted)
        context.insert(progressed)

        area.update(
            name: area.name,
            type: .habit,
            symbolName: area.symbolName,
            colorHex: area.colorHex,
            goalTarget: 2,
            goalPeriod: .daily,
            goalUnit: .hours,
            goalSchedule: .everyDay,
            now: monday
        )

        #expect(
            HabitScheduleChangeReconciler(calendar: calendar).reconcile(
                area: area,
                todos: [unstarted, progressed],
                modelContext: context,
                now: monday
            )
        )

        #expect(unstarted.measurement == .minutes)
        #expect(unstarted.plannedAmount == 120)
        #expect(progressed.measurement == .minutes)
        #expect(progressed.plannedAmount == 30)
        #expect(progressed.actualProgress == 5)
    }

    @Test @MainActor func habitScheduleChangePreservesZeroProgressTodoWithFlowHistory() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let schema = Schema([
            Area.self,
            Todo.self,
            FlowSession.self,
            FlowSegment.self,
            FlowBreak.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let monday = date(2026, 7, 6, calendar: calendar)
        let area = Area(
            name: "運動",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .weekly,
            goalUnit: .occurrences,
            goalSchedule: .weekdays,
            weekdayMask: GoalWeekday.monday.rawValue
        )
        let started = Todo(title: "筋トレ", area: area, scheduledDate: monday)
        let session = FlowSession(
            area: area,
            todo: started,
            mode: .sprint,
            startedAt: monday,
            plannedEndAt: monday.addingTimeInterval(12 * 60),
            plannedFocusDurationSeconds: 12 * 60,
            plannedBreakDurationSeconds: 3 * 60
        )
        context.insert(area)
        context.insert(started)
        context.insert(session)

        area.update(
            name: area.name,
            type: .habit,
            symbolName: area.symbolName,
            colorHex: area.colorHex,
            goalTarget: 1,
            goalPeriod: .weekly,
            goalUnit: .occurrences,
            goalSchedule: .weekdays,
            weekdayMask: GoalWeekday.tuesday.rawValue,
            now: monday
        )

        _ = HabitScheduleChangeReconciler(calendar: calendar).reconcile(
            area: area,
            todos: [started],
            modelContext: context,
            now: monday
        )

        #expect(!started.isDeleted)
        #expect(started.flowSessions?.contains(where: { $0.id == session.id }) == true)
    }

    private func weeklyHabitArea(target: Int = 3) -> Area {
        Area(
            name: "筋トレ",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .weekly,
            goalUnit: .occurrences,
            goalSchedule: .weeklyCount,
            weeklyTargetCount: target
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
