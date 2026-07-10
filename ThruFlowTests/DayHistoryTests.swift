//
//  DayHistoryTests.swift
//  ThruFlowTests
//
//  Created by Codex on 2026/07/11.
//

import Foundation
import Testing
@testable import ThruFlow

@MainActor
struct DayHistoryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func completingTodoStoresExactCompletionDateAndClearsItWhenReopened() {
        let direction = Direction(name: "仕事", type: .neutral)
        let todo = Todo(title: "レビュー", direction: direction)
        let completedAt = Date(timeIntervalSince1970: 10_000)

        todo.setCompleted(true, now: completedAt)

        #expect(todo.completedAt == completedAt)
        #expect(todo.status == .completed)

        todo.setCompleted(false, now: completedAt.addingTimeInterval(60))

        #expect(todo.completedAt == nil)
        #expect(todo.status == .active)
    }

    @Test func historyOrdersTimedEntriesAndSeparatesLegacyCompletions() {
        let day = Date(timeIntervalSince1970: 86_400)
        let direction = Direction(name: "読書", type: .habit, symbolName: "📚", colorHex: "#34C759")
        let timedTodo = Todo(
            title: "第3章",
            direction: direction,
            status: .completed,
            completedAt: day.addingTimeInterval(14 * 60 * 60),
            updatedAt: day.addingTimeInterval(14 * 60 * 60)
        )
        let legacyTodo = Todo(
            title: "旧タスク",
            direction: direction,
            status: .completed,
            updatedAt: day.addingTimeInterval(18 * 60 * 60)
        )
        let session = FlowSession(
            direction: direction,
            todo: timedTodo,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: day.addingTimeInterval(10 * 60 * 60),
            plannedEndAt: day.addingTimeInterval(10 * 60 * 60 + 25 * 60),
            endedAt: day.addingTimeInterval(10 * 60 * 60 + 25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )

        let snapshot = DayHistoryBuilder(calendar: calendar).build(
            date: day,
            sessions: [session],
            todos: [legacyTodo, timedTodo]
        )

        #expect(snapshot.flows.map(\.id) == [session.id])
        #expect(snapshot.totalFocusSeconds == 25 * 60)
        #expect(snapshot.completedTaskCount == 2)
        #expect(snapshot.completedTasks.first?.completedAt == timedTodo.completedAt)
        #expect(snapshot.completedTasks.last?.completedAt == nil)
    }

    @Test func editingFlowMovesOnlyItsProgressToTheNewTaskAndDirection() {
        let originalDirection = Direction(name: "仕事", type: .neutral, focusDurationSeconds: 50 * 60)
        let newDirection = Direction(name: "学習", type: .neutral, focusDurationSeconds: 0)
        let originalTodo = Todo(
            title: "資料",
            direction: originalDirection,
            measurement: .minutes,
            plannedAmount: 60,
            actualProgress: 50,
            focusDurationSeconds: 50 * 60
        )
        let newTodo = Todo(
            title: "Swift",
            direction: newDirection,
            measurement: .minutes,
            plannedAmount: 30
        )
        let start = Date(timeIntervalSince1970: 20_000)
        let session = FlowSession(
            direction: originalDirection,
            todo: originalTodo,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: start,
            plannedEndAt: start.addingTimeInterval(25 * 60),
            endedAt: start.addingTimeInterval(25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )

        FlowHistoryEditor().update(
            session: session,
            todo: newTodo,
            direction: newDirection,
            focusSeconds: 12 * 60,
            memo: "型を復習"
        )

        #expect(originalDirection.recordedFocusSeconds == 25 * 60)
        #expect(originalTodo.recordedFocusSeconds == 25 * 60)
        #expect(originalTodo.actualProgress == 25)
        #expect(newDirection.recordedFocusSeconds == 12 * 60)
        #expect(newTodo.recordedFocusSeconds == 12 * 60)
        #expect(newTodo.actualProgress == 12)
        #expect(newTodo.notes == "型を復習")
        #expect(session.todo?.id == newTodo.id)
        #expect(session.direction?.id == newDirection.id)
    }
}
