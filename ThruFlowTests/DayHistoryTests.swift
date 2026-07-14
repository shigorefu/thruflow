//
//  DayHistoryTests.swift
//  ThruFlowTests
//
//  Created by Codex on 2026/07/11.
//

import Foundation
import SwiftData
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

    @Test func flowHistoryTimeDraftKeepsTimesAndMinutesInSync() {
        let start = Date(timeIntervalSince1970: 20 * 60 * 60 + 41 * 60)
        let end = start.addingTimeInterval(11 * 60)
        var draft = FlowHistoryTimeDraft(startedAt: start, endedAt: end, focusSeconds: 11 * 60)

        #expect(draft.focusMinutes == 11)

        draft.setFocusMinutes(20)
        #expect(draft.endedAt == start.addingTimeInterval(20 * 60))

        draft.setEndedAt(start.addingTimeInterval(5 * 60))
        #expect(draft.focusMinutes == 5)
        #expect(draft.focusSeconds == 5 * 60)

        let earlierStart = start.addingTimeInterval(-4 * 60)
        draft.setStartedAt(earlierStart)
        #expect(draft.focusMinutes == 9)
        #expect(draft.endedAt == earlierStart.addingTimeInterval(9 * 60))
    }

    @Test func creatingManualFlowCreatesIndependentSeriesAndAppliesProgress() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let direction = Direction(name: "仕事", type: .neutral)
        let todo = Todo(
            title: "実装",
            direction: direction,
            measurement: .minutes,
            plannedAmount: 60
        )
        let start = Date(timeIntervalSince1970: 25_000)
        context.insert(direction)
        context.insert(todo)

        let session = FlowHistoryEditor().createManual(
            todo: todo,
            direction: direction,
            mode: .twentyFiveFive,
            startedAt: start,
            focusSeconds: 25 * 60,
            modelContext: context,
            now: start.addingTimeInterval(30 * 60)
        )

        #expect(session.seriesID == session.id)
        #expect(session.status == .completed)
        #expect(session.phase == .completed)
        #expect(session.endedAt == start.addingTimeInterval(25 * 60))
        #expect(session.segments.count == 1)
        #expect(session.segments.first?.resolvedFocusSeconds == 25 * 60)
        #expect(direction.recordedFocusSeconds == 25 * 60)
        #expect(todo.recordedFocusSeconds == 25 * 60)
        #expect(todo.actualProgress == 25)
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

    @Test func historyIntervalAggregatesFlowsAndScheduledTasksAcrossTheSelectedRange() {
        let day = Date(timeIntervalSince1970: 10 * 86_400)
        let direction = Direction(name: "仕事", type: .neutral, symbolName: "💻", colorHex: "#0A84FF")
        let firstTodo = Todo(title: "設計", direction: direction, scheduledDate: day)
        let secondTodo = Todo(title: "実装", direction: direction, scheduledDate: day.addingTimeInterval(86_400))
        let firstSession = FlowSession(
            direction: direction,
            todo: firstTodo,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: day.addingTimeInterval(10 * 3_600),
            plannedEndAt: day.addingTimeInterval(10 * 3_600 + 25 * 60),
            endedAt: day.addingTimeInterval(10 * 3_600 + 25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        let secondSession = FlowSession(
            direction: direction,
            todo: secondTodo,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: day.addingTimeInterval(86_400 + 11 * 3_600),
            plannedEndAt: day.addingTimeInterval(86_400 + 11 * 3_600 + 12 * 60),
            endedAt: day.addingTimeInterval(86_400 + 11 * 3_600 + 12 * 60),
            plannedFocusDurationSeconds: 12 * 60,
            actualFocusDurationSeconds: 12 * 60,
            plannedBreakDurationSeconds: 3 * 60
        )
        let interval = DateInterval(start: day, end: day.addingTimeInterval(2 * 86_400))

        let snapshot = DayHistoryBuilder(calendar: calendar).build(
            interval: interval,
            sessions: [firstSession, secondSession],
            todos: [firstTodo, secondTodo]
        )

        #expect(snapshot.interval == interval)
        #expect(snapshot.totalFocusSeconds == 37 * 60)
        #expect(snapshot.taskSummaries.count == 2)
        #expect(snapshot.directionSummaries.first?.taskCount == 2)
        #expect(snapshot.directionSummaries.first?.flowCount == 2)
    }

    @Test func historyCombinesDailyHabitOccurrencesButKeepsNormalTodosSeparate() {
        let day = Date(timeIntervalSince1970: 20 * 86_400)
        let habit = Direction(name: "AWS", type: .habit, symbolName: "☁️", colorHex: "#FFD60A")
        let normal = Direction(name: "仕事", type: .neutral)
        let firstHabit = Todo(
            title: "",
            direction: habit,
            measurement: .focusBlocks,
            plannedAmount: 2,
            scheduledDate: day
        )
        let secondHabit = Todo(
            title: "",
            direction: habit,
            measurement: .focusBlocks,
            plannedAmount: 2,
            scheduledDate: day.addingTimeInterval(86_400)
        )
        let firstNormal = Todo(title: "レビュー", direction: normal, scheduledDate: day)
        let secondNormal = Todo(title: "レビュー", direction: normal, scheduledDate: day.addingTimeInterval(86_400))
        let interval = DateInterval(start: day, end: day.addingTimeInterval(2 * 86_400))

        let snapshot = DayHistoryBuilder(calendar: calendar).build(
            interval: interval,
            sessions: [],
            todos: [firstHabit, secondHabit, firstNormal, secondNormal]
        )

        let habitSummaries = snapshot.taskSummaries.filter { $0.directionID == habit.id }
        let normalSummaries = snapshot.taskSummaries.filter { $0.directionID == normal.id }
        #expect(habitSummaries.count == 1)
        #expect(habitSummaries.first?.todos.count == 2)
        #expect(normalSummaries.count == 2)
        #expect(snapshot.directionSummaries.first(where: { $0.directionID == habit.id })?.taskCount == 1)
    }

    @Test func dailyHabitUsesScheduledOccurrenceWhileKeepingFlowFromAnotherOccurrence() {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 30 * 86_400))
        let habit = Direction(name: "AWS", type: .habit, symbolName: "☁️", colorHex: "#FFD60A")
        let previousHabit = Todo(
            title: "",
            direction: habit,
            measurement: .focusBlocks,
            plannedAmount: 2,
            scheduledDate: day.addingTimeInterval(-86_400)
        )
        let currentHabit = Todo(
            title: "",
            direction: habit,
            measurement: .focusBlocks,
            plannedAmount: 2,
            scheduledDate: day
        )
        let session = FlowSession(
            direction: habit,
            todo: previousHabit,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: day.addingTimeInterval(10 * 3_600),
            plannedEndAt: day.addingTimeInterval(10 * 3_600 + 25 * 60),
            endedAt: day.addingTimeInterval(10 * 3_600 + 25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )

        let snapshot = DayHistoryBuilder(calendar: calendar).build(
            date: day,
            sessions: [session],
            todos: [previousHabit, currentHabit]
        )

        let summary = snapshot.taskSummaries.first
        #expect(snapshot.taskSummaries.count == 1)
        #expect(summary?.todos.map(\.id) == [currentHabit.id])
        #expect(summary?.linkedTodoIDs == [previousHabit.id, currentHabit.id])
        #expect(summary?.focusSeconds == 25 * 60)
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

        let adjustedStart = start.addingTimeInterval(60 * 60)
        FlowHistoryEditor().update(
            session: session,
            todo: newTodo,
            direction: newDirection,
            startedAt: adjustedStart,
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
        #expect(session.startedAt == adjustedStart)
        #expect(session.endedAt == adjustedStart.addingTimeInterval(12 * 60))
        #expect(session.plannedEndAt == session.endedAt)
    }

    @Test func deletingOneFlowSegmentRemovesOnlyItsProgress() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let direction = Direction(name: "仕事", type: .neutral, focusDurationSeconds: 25 * 60)
        let todo = Todo(
            title: "実装",
            direction: direction,
            measurement: .minutes,
            plannedAmount: 30,
            actualProgress: 25,
            focusDurationSeconds: 25 * 60
        )
        let start = Date(timeIntervalSince1970: 30_000)
        let session = FlowSession(
            direction: direction,
            todo: todo,
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
        let first = FlowSegment(session: session, direction: direction, todo: todo, startedAt: start, startFocusSeconds: 0)
        first.close(at: start.addingTimeInterval(10 * 60), totalFocusSeconds: 10 * 60)
        let second = FlowSegment(session: session, direction: direction, todo: todo, startedAt: start.addingTimeInterval(10 * 60), startFocusSeconds: 10 * 60)
        second.close(at: start.addingTimeInterval(25 * 60), totalFocusSeconds: 25 * 60)
        session.segments = [first, second]
        context.insert(direction)
        context.insert(todo)
        context.insert(session)

        FlowHistoryEditor().delete(segment: first, from: session, modelContext: context)

        #expect(session.segments.map(\.id) == [second.id])
        #expect(session.actualFocusDurationSeconds == 15 * 60)
        #expect(direction.recordedFocusSeconds == 15 * 60)
        #expect(todo.recordedFocusSeconds == 15 * 60)
        #expect(todo.actualProgress == 15)
    }

    @Test func deletingFlowSessionSoftDeletesRelatedBreaks() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let direction = Direction(name: "仕事", type: .neutral)
        let start = Date(timeIntervalSince1970: 40_000)
        let session = FlowSession(
            direction: direction,
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
        let flowBreak = FlowBreak(
            seriesID: session.seriesID ?? session.id,
            previousSessionID: session.id,
            startedAt: session.endedAt!,
            plannedDurationSeconds: 5 * 60
        )
        context.insert(direction)
        context.insert(session)
        context.insert(flowBreak)

        FlowHistoryEditor().delete(session: session, modelContext: context, now: start.addingTimeInterval(40 * 60))

        #expect(flowBreak.deletedAt == start.addingTimeInterval(40 * 60))
    }

    @Test func editingBreakPushesOnlyOverlappingSessionsInTheSameSeries() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let direction = Direction(name: "仕事", type: .neutral)
        let seriesID = UUID()
        let start = Date(timeIntervalSince1970: 100_000)

        let first = FlowSession(
            seriesID: seriesID,
            direction: direction,
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
        let secondStart = start.addingTimeInterval(30 * 60)
        let second = FlowSession(
            seriesID: seriesID,
            direction: direction,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: secondStart,
            plannedEndAt: secondStart.addingTimeInterval(25 * 60),
            endedAt: secondStart.addingTimeInterval(25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        let secondSegment = FlowSegment(
            session: second,
            direction: direction,
            todo: nil,
            startedAt: secondStart,
            startFocusSeconds: 0
        )
        secondSegment.close(at: secondStart.addingTimeInterval(25 * 60), totalFocusSeconds: 25 * 60)
        second.segments = [secondSegment]
        let thirdStart = start.addingTimeInterval(60 * 60)
        let third = FlowSession(
            seriesID: seriesID,
            direction: direction,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: thirdStart,
            plannedEndAt: thirdStart.addingTimeInterval(25 * 60),
            endedAt: thirdStart.addingTimeInterval(25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        let unrelated = FlowSession(
            direction: direction,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: start.addingTimeInterval(50 * 60),
            plannedEndAt: start.addingTimeInterval(75 * 60),
            endedAt: start.addingTimeInterval(75 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        let editedBreak = FlowBreak(
            seriesID: seriesID,
            previousSessionID: first.id,
            nextSessionID: second.id,
            startedAt: first.endedAt!,
            timerStoppedAt: secondStart,
            connectedUntil: secondStart,
            plannedDurationSeconds: 5 * 60
        )
        let laterBreak = FlowBreak(
            seriesID: seriesID,
            previousSessionID: second.id,
            nextSessionID: third.id,
            startedAt: second.endedAt!,
            timerStoppedAt: thirdStart,
            connectedUntil: thirdStart,
            plannedDurationSeconds: 5 * 60
        )

        context.insert(direction)
        context.insert(first)
        context.insert(second)
        context.insert(third)
        context.insert(unrelated)
        context.insert(editedBreak)
        context.insert(laterBreak)

        let result = try FlowBreakEditor().updateDuration(
            of: editedBreak,
            minutes: 10,
            modelContext: context,
            now: start.addingTimeInterval(2 * 3_600)
        )

        #expect(result.shiftedSeconds == 5 * 60)
        #expect(editedBreak.adjustedEndAt == start.addingTimeInterval(35 * 60))
        #expect(second.startedAt == start.addingTimeInterval(35 * 60))
        #expect(second.endedAt == start.addingTimeInterval(60 * 60))
        #expect(secondSegment.startedAt == second.startedAt)
        #expect(secondSegment.endedAt == second.endedAt)
        #expect(laterBreak.startedAt == start.addingTimeInterval(60 * 60))
        #expect(third.startedAt == start.addingTimeInterval(65 * 60))
        #expect(unrelated.startedAt == start.addingTimeInterval(50 * 60))

        let shortened = try FlowBreakEditor().updateDuration(
            of: editedBreak,
            minutes: 2,
            modelContext: context,
            now: start.addingTimeInterval(3 * 3_600)
        )

        #expect(shortened.shiftedSeconds == 0)
        #expect(editedBreak.adjustedEndAt == start.addingTimeInterval(27 * 60))
        #expect(second.startedAt == start.addingTimeInterval(35 * 60))
    }
}
