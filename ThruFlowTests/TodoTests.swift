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
        let direction = Direction(name: "生活", type: .neutral)
        let checkbox = Todo(title: "確認", direction: direction, measurement: .checkbox)
        let blocks = Todo(title: "読書", direction: direction, measurement: .focusBlocks, plannedAmount: 2)
        let minutes = Todo(title: "散歩", direction: direction, measurement: .minutes, plannedAmount: 30)

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

    @Test func todoDraftAllowsEmptyTitleAndMissingDirectionButRequiresPlannedAmount() {
        let draft = TodoDraft(
            title: " ",
            direction: nil,
            measurement: .focusBlocks,
            plannedAmount: 0
        )

        let errors = TodoValidator().validate(draft)

        #expect(errors == [.invalidPlannedAmount])
    }

    @Test func historyRenameTrimsAndUpdatesAnyTaskTitle() {
        let direction = Direction(name: "読書", type: .neutral)
        let createdAt = Date(timeIntervalSince1970: 100)
        let renamedAt = Date(timeIntervalSince1970: 200)
        let todo = Todo(
            title: "古い名前",
            direction: direction,
            createdAt: createdAt,
            updatedAt: createdAt
        )

        #expect(todo.rename(to: "  新しい名前\n", now: renamedAt))
        #expect(todo.title == "新しい名前")
        #expect(todo.updatedAt == renamedAt)
    }

    @Test func historyRenameDoesNotReplaceATaskWithAnEmptyTitle() {
        let direction = Direction(name: "読書", type: .neutral)
        let updatedAt = Date(timeIntervalSince1970: 100)
        let todo = Todo(
            title: "本を読む",
            direction: direction,
            updatedAt: updatedAt
        )

        #expect(!todo.rename(to: "  \n", now: Date(timeIntervalSince1970: 200)))
        #expect(todo.title == "本を読む")
        #expect(todo.updatedAt == updatedAt)
    }

    @Test func defaultTaskInboxUsesLocalizedNameAndStableSystemProperties() {
        let direction = DefaultDirections.makeTaskInbox(now: Date(timeIntervalSince1970: 0))

        #expect(direction.name == DefaultDirections.taskInboxName)
        #expect(direction.type == .neutral)
        #expect(direction.symbolName == "📝")
        #expect(direction.colorHex == "#007AFF")
        #expect(DefaultDirections.isTaskInbox(direction))
    }

    @Test func userDirectionIsNotTaskInboxColorlessDefault() {
        let direction = Direction(name: "仕事", type: .neutral)

        #expect(!DefaultDirections.isTaskInbox(direction))
    }

    @Test func activeUnscheduledTodoDoesNotAppearInDailyTasks() {
        let direction = Direction(name: "仕事", type: .neutral)
        let todo = Todo(title: "資料を作る", direction: direction)

        #expect(!TodayTodoFilter().includes(todo, on: Date(timeIntervalSince1970: 0)))
    }

    @Test func archivedTodoDoesNotAppearInToday() {
        let direction = Direction(name: "仕事", type: .neutral)
        let todo = Todo(title: "資料を作る", direction: direction)

        todo.archive(now: Date(timeIntervalSince1970: 100))

        #expect(!TodayTodoFilter().includes(todo, on: Date(timeIntervalSince1970: 0)))
    }

    @Test func scheduledTodoAppearsOnlyOnMatchingDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let direction = Direction(name: "仕事", type: .neutral)
        let scheduledDate = Date(timeIntervalSince1970: 86_400)
        let todo = Todo(title: "資料を作る", direction: direction, scheduledDate: scheduledDate)

        let filter = TodayTodoFilter(calendar: calendar)

        #expect(filter.includes(todo, on: Date(timeIntervalSince1970: 86_400 + 60)))
        #expect(!filter.includes(todo, on: Date(timeIntervalSince1970: 0)))
    }

    @Test func dailyHabitDirectionCreatesTodayTodoDraft() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let direction = Direction(
            name: "読書",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .daily,
            goalUnit: .focusBlocks,
            goalSchedule: .everyDay
        )
        let planner = RequiredTodoPlanner(calendar: calendar)
        let date = Date(timeIntervalSince1970: 0)
        let todo = planner.makeRequiredTodo(for: direction, on: date)

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

        let direction = Direction(
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
            planner.makeRequiredTodo(for: direction, on: afternoon)?.scheduledDate ==
                calendar.startOfDay(for: afternoon)
        )
    }

    @Test func duplicateHabitOccurrencesKeepHistoryAndSoftDeleteTheEmptyDuplicate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let day = date(2026, 7, 24, calendar: calendar)
        let direction = weeklyHabitDirection()
        let emptyDuplicate = Todo(
            title: "",
            direction: direction,
            scheduledDate: day,
            createdAt: day
        )
        let recordedDuplicate = Todo(
            title: "上半身",
            direction: direction,
            scheduledDate: day.addingTimeInterval(15 * 3_600),
            createdAt: day.addingTimeInterval(60)
        )
        let session = FlowSession(
            direction: direction,
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
        let direction = weeklyHabitDirection()
        let active = Todo(title: "", direction: direction, scheduledDate: day, createdAt: day)
        let completed = Todo(
            title: "",
            direction: direction,
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

        let direction = Direction(
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

        #expect(planner.shouldAppearToday(direction, on: date))
        #expect(planner.makeRequiredTodo(for: direction, on: date) != nil)
    }

    @Test func movedWeeklyHabitDoesNotCreateReplacement() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let direction = weeklyHabitDirection()
        let planner = RequiredTodoPlanner(calendar: calendar)
        let today = date(2026, 7, 6, calendar: calendar)
        let tomorrow = date(2026, 7, 7, calendar: calendar)
        let movedTodo = Todo(title: "", direction: direction, scheduledDate: tomorrow)

        #expect(!planner.shouldCreateRequiredTodo(for: direction, in: [movedTodo], on: today))
    }

    @Test func nextWeeklyHabitAppearsOnFollowingDayAfterCompletion() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let direction = weeklyHabitDirection()
        let planner = RequiredTodoPlanner(calendar: calendar)
        let monday = date(2026, 7, 6, calendar: calendar)
        let tuesday = date(2026, 7, 7, calendar: calendar)
        let completedTodo = Todo(title: "", direction: direction, scheduledDate: monday)
        completedTodo.setCompleted(true, now: monday)

        #expect(!planner.shouldCreateRequiredTodo(for: direction, in: [completedTodo], on: monday))
        #expect(planner.shouldCreateRequiredTodo(for: direction, in: [completedTodo], on: tuesday))
    }

    @Test func pendingWeeklyHabitRollsForwardWithinCurrentWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1

        let direction = weeklyHabitDirection()
        let planner = RequiredTodoPlanner(calendar: calendar)
        let sunday = date(2026, 7, 12, calendar: calendar)
        let wednesday = date(2026, 7, 15, calendar: calendar)
        let pendingTodo = Todo(title: "", direction: direction, scheduledDate: sunday)

        #expect(
            planner.pendingWeeklyTodoToRollForward(
                for: direction,
                in: [pendingTodo],
                on: wednesday
            )?.id == pendingTodo.id
        )
    }

    @Test func pendingWeeklyHabitDoesNotRollBackwardOrAcrossWeeks() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1

        let direction = weeklyHabitDirection()
        let planner = RequiredTodoPlanner(calendar: calendar)
        let saturday = date(2026, 7, 11, calendar: calendar)
        let wednesday = date(2026, 7, 15, calendar: calendar)
        let friday = date(2026, 7, 17, calendar: calendar)
        let previousWeekTodo = Todo(title: "", direction: direction, scheduledDate: saturday)
        let futureTodo = Todo(title: "", direction: direction, scheduledDate: friday)

        #expect(
            planner.pendingWeeklyTodoToRollForward(
                for: direction,
                in: [previousWeekTodo, futureTodo],
                on: wednesday
            ) == nil
        )
    }

    @Test func weeklyHabitCannotMovePastAchievableDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2

        let direction = weeklyHabitDirection(target: 4)
        let planner = RequiredTodoPlanner(calendar: calendar)
        let friday = date(2026, 7, 10, calendar: calendar)
        let todo = Todo(title: "", direction: direction, scheduledDate: friday)
        let options = planner.weeklyRescheduleOptions(for: todo, in: [todo], now: friday)

        #expect(options.first?.date == friday)
        #expect(options.allSatisfy { !$0.isAllowed })
    }

    @Test func selectedWeekdayHabitDirectionAppearsOnlyOnThatWeekday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let monday = Date(timeIntervalSince1970: 4 * 86_400)
        let tuesday = Date(timeIntervalSince1970: 5 * 86_400)
        let direction = Direction(
            name: "Anki",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .weekly,
            goalUnit: .focusBlocks,
            goalSchedule: .weekdays,
            weekdayMask: GoalWeekday.monday.rawValue
        )
        let planner = RequiredTodoPlanner(calendar: calendar)

        #expect(planner.shouldAppearToday(direction, on: monday))
        #expect(!planner.shouldAppearToday(direction, on: tuesday))
    }

    @Test func pausedDailyHabitDoesNotAppearUntilPauseEnds() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = date(2026, 7, 6, calendar: calendar)
        let tuesday = date(2026, 7, 7, calendar: calendar)
        let direction = Direction(
            name: "読書",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .daily,
            goalUnit: .occurrences,
            goalSchedule: .everyDay
        )
        let pauseService = HabitPauseService(calendar: calendar)
        let planner = RequiredTodoPlanner(calendar: calendar)

        #expect(pauseService.pauseToday(direction, todos: [], now: monday))
        #expect(!planner.shouldAppearToday(direction, on: monday))
        #expect(planner.makeRequiredTodo(for: direction, on: monday) == nil)
        #expect(planner.shouldAppearToday(direction, on: tuesday))
    }

    @Test func indefinitelyPausedHabitCanResumeOnCurrentDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = date(2026, 7, 6, calendar: calendar)
        let direction = weeklyHabitDirection()
        let pauseService = HabitPauseService(calendar: calendar)

        #expect(pauseService.pauseIndefinitely(direction, todos: [], now: monday))
        #expect(pauseService.isPaused(direction, on: monday))
        #expect(pauseService.resume(direction, now: monday))
        #expect(!pauseService.isPaused(direction, on: monday))
    }

    @Test func pausingHabitSuppressesOnlyUnstartedGeneratedTodos() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = date(2026, 7, 6, calendar: calendar)
        let direction = weeklyHabitDirection()
        let pending = Todo(title: "", direction: direction, scheduledDate: monday)
        let completed = Todo(title: "", direction: direction, scheduledDate: monday)
        completed.setCompleted(true, now: monday)
        let progressed = Todo(
            title: "",
            direction: direction,
            measurement: .minutes,
            plannedAmount: 30,
            actualProgress: 5,
            scheduledDate: monday
        )
        let recorded = Todo(title: "", direction: direction, scheduledDate: monday)
        recorded.recordedFocusSeconds = 60

        #expect(
            HabitPauseService(calendar: calendar).pauseToday(
                direction,
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
            Direction.self,
            Todo.self,
            FlowSession.self,
            FlowSegment.self,
            FlowBreak.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let date = Date(timeIntervalSince1970: 4 * 86_400)
        let direction = Direction(
            name: "読書",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .daily,
            goalUnit: .occurrences,
            goalSchedule: .everyDay
        )
        let first = Todo(title: "", direction: direction, scheduledDate: date)
        let duplicate = Todo(title: "", direction: direction, scheduledDate: date)
        context.insert(direction)
        context.insert(first)
        context.insert(duplicate)

        let changed = try HabitTodoMaterializer(calendar: calendar).materialize(
            directions: [direction],
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

    private func weeklyHabitDirection(target: Int = 3) -> Direction {
        Direction(
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
