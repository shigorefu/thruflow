//
//  TodoTests.swift
//  ThruFlowTests
//
//  Created by Codex on 2026/07/08.
//

import Foundation
import Testing
@testable import ThruFlow

struct TodoTests {

    @Test func checkboxProgressCompletesWhenChecked() {
        let calculator = TodoProgressCalculator()

        #expect(calculator.progress(measurement: .checkbox, plannedAmount: nil, actualProgress: 0) == 0)
        #expect(calculator.progress(measurement: .checkbox, plannedAmount: nil, actualProgress: 1) == 1)
        #expect(calculator.status(measurement: .checkbox, plannedAmount: nil, actualProgress: 1) == .completed)
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

    @Test func defaultOtherDirectionIsNeutralAndHiddenSystemDirection() {
        let direction = DefaultDirections.makeTaskInbox(now: Date(timeIntervalSince1970: 0))

        #expect(direction.name == "その他")
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
