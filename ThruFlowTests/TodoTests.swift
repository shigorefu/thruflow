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

    @Test func todoDraftAllowsMissingDirectionButRequiresTitleAndPlannedAmount() {
        let draft = TodoDraft(
            title: " ",
            direction: nil,
            measurement: .focusBlocks,
            plannedAmount: 0
        )

        let errors = TodoValidator().validate(draft)

        #expect(errors == [.emptyTitle, .invalidPlannedAmount])
    }

    @Test func defaultTaskInboxDirectionIsNeutral() {
        let direction = DefaultDirections.makeTaskInbox(now: Date(timeIntervalSince1970: 0))

        #expect(direction.name == "タスク")
        #expect(direction.type == .neutral)
        #expect(direction.symbolName == "📝")
        #expect(direction.colorHex == "#007AFF")
        #expect(DefaultDirections.isTaskInbox(direction))
    }

    @Test func userDirectionIsNotTaskInboxColorlessDefault() {
        let direction = Direction(name: "仕事", type: .neutral)

        #expect(!DefaultDirections.isTaskInbox(direction))
    }

    @Test func activeUnscheduledTodoAppearsInToday() {
        let direction = Direction(name: "仕事", type: .neutral)
        let todo = Todo(title: "資料を作る", direction: direction)

        #expect(TodayTodoFilter().includes(todo, on: Date(timeIntervalSince1970: 0)))
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

    @Test func dailyMustDirectionCreatesTodayTodoDraft() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let direction = Direction(
            name: "読書",
            type: .must,
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
        #expect(todo?.plannedAmount == 1)
        #expect(todo?.scheduledDate == date)
    }

    @Test func weeklyCountWithoutSelectedWeekdaysDoesNotCreateTodayTodo() {
        let direction = Direction(
            name: "筋トレ",
            type: .must,
            goalTarget: 3,
            goalPeriod: .weekly,
            goalUnit: .occurrences,
            goalSchedule: .weeklyCount,
            weeklyTargetCount: 3
        )

        #expect(!RequiredTodoPlanner().shouldAppearToday(direction, on: Date(timeIntervalSince1970: 0)))
    }

    @Test func selectedWeekdayMustDirectionAppearsOnlyOnThatWeekday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let monday = Date(timeIntervalSince1970: 4 * 86_400)
        let tuesday = Date(timeIntervalSince1970: 5 * 86_400)
        let direction = Direction(
            name: "Anki",
            type: .must,
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
}
