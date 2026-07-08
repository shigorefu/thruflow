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

    @Test func todoDraftRequiresTitleAndDirection() {
        let draft = TodoDraft(
            title: " ",
            direction: nil,
            measurement: .focusBlocks,
            plannedAmount: 0
        )

        let errors = TodoValidator().validate(draft)

        #expect(errors == [.emptyTitle, .missingDirection, .invalidPlannedAmount])
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
}
