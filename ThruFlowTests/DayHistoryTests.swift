//
//  DayHistoryTests.swift
//  ThruFlowTests
//
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
        let area = Area(name: "仕事", type: .neutral)
        let todo = Todo(title: "レビュー", area: area)
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
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let area = Area(name: "仕事", type: .neutral)
        let todo = Todo(
            title: "実装",
            area: area,
            measurement: .minutes,
            plannedAmount: 60
        )
        let start = Date(timeIntervalSince1970: 25_000)
        context.insert(area)
        context.insert(todo)

        let session = try FlowHistoryEditor().createManual(
            todo: todo,
            area: area,
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
        #expect(session.resolvedSegments.count == 1)
        #expect(session.resolvedSegments.first?.resolvedFocusSeconds == 25 * 60)
        #expect(area.recordedFocusSeconds == 25 * 60)
        #expect(todo.recordedFocusSeconds == 25 * 60)
        #expect(todo.actualProgress == 25)
        #expect(todo.status == .active)
        #expect(todo.completedAt == nil)
    }

    @Test func attachingCreatedTaskUpdatesOpenHistoryItemWithoutRebuild() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let area = Area(
            name: "筋トレ",
            type: .habit,
            symbolName: "💪",
            colorHex: "#FFCC00"
        )
        let start = Date(timeIntervalSince1970: 30_000)
        context.insert(area)

        let editor = FlowHistoryEditor()
        let session = try editor.createManual(
            todo: nil,
            area: area,
            mode: .twentyFiveFive,
            startedAt: start,
            focusSeconds: 25 * 60,
            modelContext: context,
            now: start.addingTimeInterval(25 * 60)
        )
        let item = try #require(
            HistoryCalendarBuilder(calendar: calendar)
                .build(
                    interval: DateInterval(
                        start: start.addingTimeInterval(-60),
                        end: start.addingTimeInterval(30 * 60)
                    ),
                    sessions: [session],
                    breaks: []
                )
                .items
                .first
        )
        #expect(item.displayTitle == "(筋トレ)")

        let todo = Todo(
            title: "スクワット",
            area: area,
            measurement: .minutes,
            plannedAmount: 30
        )
        context.insert(todo)
        let segment = try #require(session.resolvedSegments.first)

        try editor.attach(
            todo: todo,
            to: segment,
            in: session,
            modelContext: context,
            now: start.addingTimeInterval(25 * 60)
        )

        #expect(segment.todo?.id == todo.id)
        #expect(session.todo?.id == todo.id)
        #expect(item.displayTitle == "スクワット")
        #expect(item.displaySubtitle == "筋トレ")
        #expect(todo.recordedFocusSeconds == 25 * 60)
        #expect(todo.actualProgress == 25)
    }

    @Test func movingFlowShiftsSessionAndSegmentsWithoutChangingProgress() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let area = Area(name: "仕事", type: .neutral)
        let todo = Todo(
            title: "実装",
            area: area,
            measurement: .minutes,
            plannedAmount: 60
        )
        let start = Date(timeIntervalSince1970: 20 * 60 * 60)
        context.insert(area)
        context.insert(todo)

        let editor = FlowHistoryEditor()
        let session = try editor.createManual(
            todo: todo,
            area: area,
            mode: .twentyFiveFive,
            startedAt: start,
            focusSeconds: 25 * 60,
            modelContext: context,
            now: start.addingTimeInterval(25 * 60)
        )
        let originalCreatedAt = session.createdAt
        let originalSegmentCreatedAt = try #require(session.resolvedSegments.first?.createdAt)
        let target = start.addingTimeInterval(24 * 60 * 60 + 90 * 60)

        try editor.move(
            session: session,
            itemStartedAt: start,
            to: target,
            modelContext: context,
            now: target
        )

        #expect(session.startedAt == target)
        #expect(session.plannedEndAt == target.addingTimeInterval(25 * 60))
        #expect(session.endedAt == target.addingTimeInterval(25 * 60))
        #expect(session.resolvedSegments.first?.startedAt == target)
        #expect(session.resolvedSegments.first?.endedAt == target.addingTimeInterval(25 * 60))
        #expect(session.createdAt == originalCreatedAt)
        #expect(session.resolvedSegments.first?.createdAt == originalSegmentCreatedAt)
        #expect(todo.recordedFocusSeconds == 25 * 60)
        #expect(todo.actualProgress == 25)
        #expect(area.recordedFocusSeconds == 25 * 60)
    }

    @Test func historyOrdersTimedEntriesAndSeparatesLegacyCompletions() {
        let day = Date(timeIntervalSince1970: 86_400)
        let area = Area(name: "読書", type: .habit, symbolName: "📚", colorHex: "#34C759")
        let timedTodo = Todo(
            title: "第3章",
            area: area,
            status: .completed,
            completedAt: day.addingTimeInterval(14 * 60 * 60),
            updatedAt: day.addingTimeInterval(14 * 60 * 60)
        )
        let legacyTodo = Todo(
            title: "旧タスク",
            area: area,
            status: .completed,
            updatedAt: day.addingTimeInterval(18 * 60 * 60)
        )
        let session = FlowSession(
            area: area,
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

    @Test func historyKeepsExactTaskSwitchSegmentsForEditing() {
        let day = Date(timeIntervalSince1970: 86_400)
        let study = Area(name: "勉強", type: .neutral)
        let work = Area(name: "仕事", type: .neutral)
        let reading = Todo(title: "読書", area: study)
        let report = Todo(title: "報告書", area: work)
        let start = day.addingTimeInterval(10 * 60 * 60)
        let session = FlowSession(
            area: work,
            todo: report,
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
        let readingSegment = FlowSegment(
            session: session,
            area: study,
            todo: reading,
            startedAt: start,
            startFocusSeconds: 0
        )
        readingSegment.close(
            at: start.addingTimeInterval(10 * 60),
            totalFocusSeconds: 10 * 60
        )
        let reportSegment = FlowSegment(
            session: session,
            area: work,
            todo: report,
            startedAt: start.addingTimeInterval(10 * 60),
            startFocusSeconds: 10 * 60
        )
        reportSegment.close(
            at: start.addingTimeInterval(25 * 60),
            totalFocusSeconds: 25 * 60
        )
        session.resolvedSegments = [readingSegment, reportSegment]

        let snapshot = DayHistoryBuilder(calendar: calendar).build(
            date: day,
            sessions: [session],
            todos: [reading, report]
        )

        #expect(snapshot.flows.map(\.id) == [readingSegment.id, reportSegment.id])
        #expect(snapshot.flows.map(\.segment?.id) == [readingSegment.id, reportSegment.id])
        #expect(snapshot.flows.allSatisfy { $0.session.id == session.id })
    }

    @Test func historyIntervalAggregatesFlowsAndScheduledTasksAcrossTheSelectedRange() {
        let day = Date(timeIntervalSince1970: 10 * 86_400)
        let area = Area(name: "仕事", type: .neutral, symbolName: "💻", colorHex: "#0A84FF")
        let firstTodo = Todo(title: "設計", area: area, scheduledDate: day)
        let secondTodo = Todo(title: "実装", area: area, scheduledDate: day.addingTimeInterval(86_400))
        let unworkedTodo = Todo(title: "未着手", area: area, scheduledDate: day.addingTimeInterval(12 * 3_600))
        let firstSession = FlowSession(
            area: area,
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
            area: area,
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
            todos: [firstTodo, secondTodo, unworkedTodo]
        )

        #expect(snapshot.interval == interval)
        #expect(snapshot.totalFocusSeconds == 37 * 60)
        #expect(snapshot.taskSummaries.count == 2)
        #expect(snapshot.areaSummaries.first?.taskCount == 2)
        #expect(snapshot.areaSummaries.first?.flowCount == 2)
    }

    @Test func historyKeepsRecordedHabitOccurrencesAsSeparateTasks() {
        let day = Date(timeIntervalSince1970: 20 * 86_400)
        let habit = Area(name: "筋トレ", type: .habit, symbolName: "💪", colorHex: "#FFD60A")
        let normal = Area(name: "仕事", type: .neutral)
        let firstHabit = Todo(
            title: "筋トレ B",
            area: habit,
            measurement: .checkbox,
            scheduledDate: day
        )
        let secondHabit = Todo(
            title: "筋トレ C",
            area: habit,
            measurement: .checkbox,
            scheduledDate: day.addingTimeInterval(86_400)
        )
        let firstNormal = Todo(title: "レビュー", area: normal, scheduledDate: day)
        let secondNormal = Todo(title: "レビュー", area: normal, scheduledDate: day.addingTimeInterval(86_400))
        let interval = DateInterval(start: day, end: day.addingTimeInterval(2 * 86_400))
        let sessions = [
            makeCompletedSession(todo: firstHabit, area: habit, startedAt: day.addingTimeInterval(9 * 3_600)),
            makeCompletedSession(todo: secondHabit, area: habit, startedAt: day.addingTimeInterval(86_400 + 9 * 3_600)),
            makeCompletedSession(todo: firstNormal, area: normal, startedAt: day.addingTimeInterval(10 * 3_600)),
            makeCompletedSession(todo: secondNormal, area: normal, startedAt: day.addingTimeInterval(86_400 + 10 * 3_600))
        ]

        let snapshot = DayHistoryBuilder(calendar: calendar).build(
            interval: interval,
            sessions: sessions,
            todos: [firstHabit, secondHabit, firstNormal, secondNormal]
        )

        let habitSummaries = snapshot.taskSummaries.filter { $0.areaID == habit.id }
        let normalSummaries = snapshot.taskSummaries.filter { $0.areaID == normal.id }
        #expect(habitSummaries.count == 2)
        #expect(Set(habitSummaries.map(\.title)) == ["筋トレ B", "筋トレ C"])
        #expect(habitSummaries.allSatisfy { $0.todos.count == 1 })
        #expect(normalSummaries.count == 2)
        #expect(snapshot.areaSummaries.first(where: { $0.areaID == habit.id })?.taskCount == 2)

        secondHabit.setManuallyCompleted(true, now: day.addingTimeInterval(86_400 + 12 * 3_600))

        #expect(firstHabit.title == "筋トレ B")
        #expect(!firstHabit.isCompleted)
        #expect(secondHabit.title == "筋トレ C")
        #expect(secondHabit.isCompleted)
    }

    @Test func historyHidesScheduledTasksWithoutRecordedFlow() {
        let day = Date(timeIntervalSince1970: 25 * 86_400)
        let area = Area(name: "仕事", type: .neutral)
        let todo = Todo(title: "未着手", area: area, scheduledDate: day)

        let snapshot = DayHistoryBuilder(calendar: calendar).build(
            date: day,
            sessions: [],
            todos: [todo]
        )

        #expect(snapshot.taskSummaries.isEmpty)
    }

    @Test func dailyHabitUsesTheTodoActuallyLinkedToFlow() {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 30 * 86_400))
        let habit = Area(name: "AWS", type: .habit, symbolName: "☁️", colorHex: "#FFD60A")
        let previousHabit = Todo(
            title: "",
            area: habit,
            measurement: .focusBlocks,
            plannedAmount: 2,
            scheduledDate: day.addingTimeInterval(-86_400)
        )
        let currentHabit = Todo(
            title: "",
            area: habit,
            measurement: .focusBlocks,
            plannedAmount: 2,
            scheduledDate: day
        )
        let session = FlowSession(
            area: habit,
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
        #expect(summary?.todos.map(\.id) == [previousHabit.id])
        #expect(summary?.linkedTodoIDs == [previousHabit.id])
        #expect(summary?.focusSeconds == 25 * 60)
    }

    private func makeCompletedSession(
        todo: Todo,
        area: Area,
        startedAt: Date
    ) -> FlowSession {
        FlowSession(
            area: area,
            todo: todo,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: startedAt,
            plannedEndAt: startedAt.addingTimeInterval(25 * 60),
            endedAt: startedAt.addingTimeInterval(25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
    }

    @Test func editingFlowMovesOnlyItsProgressToTheNewTaskAndArea() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let originalArea = Area(name: "仕事", type: .neutral, focusDurationSeconds: 50 * 60)
        let newArea = Area(name: "学習", type: .neutral, focusDurationSeconds: 0)
        let originalTodo = Todo(
            title: "資料",
            area: originalArea,
            measurement: .minutes,
            plannedAmount: 60,
            actualProgress: 50,
            focusDurationSeconds: 50 * 60
        )
        let newTodo = Todo(
            title: "Swift",
            area: newArea,
            measurement: .minutes,
            plannedAmount: 30
        )
        let start = Date(timeIntervalSince1970: 20_000)
        let priorSession = FlowSession(
            area: originalArea,
            todo: originalTodo,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: start.addingTimeInterval(-30 * 60),
            plannedEndAt: start.addingTimeInterval(-5 * 60),
            endedAt: start.addingTimeInterval(-5 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        let session = FlowSession(
            area: originalArea,
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
        context.insert(originalArea)
        context.insert(newArea)
        context.insert(originalTodo)
        context.insert(newTodo)
        context.insert(priorSession)
        context.insert(session)

        let adjustedStart = start.addingTimeInterval(60 * 60)
        try FlowHistoryEditor().update(
            session: session,
            todo: newTodo,
            area: newArea,
            startedAt: adjustedStart,
            focusSeconds: 12 * 60,
            memo: "型を復習",
            modelContext: context
        )

        #expect(originalArea.recordedFocusSeconds == 25 * 60)
        #expect(originalTodo.recordedFocusSeconds == 25 * 60)
        #expect(originalTodo.actualProgress == 25)
        #expect(newArea.recordedFocusSeconds == 12 * 60)
        #expect(newTodo.recordedFocusSeconds == 12 * 60)
        #expect(newTodo.actualProgress == 12)
        #expect(newTodo.notes == "型を復習")
        #expect(session.result == "型を復習")
        #expect(session.todo?.id == newTodo.id)
        #expect(session.area?.id == newArea.id)
        #expect(session.startedAt == adjustedStart)
        #expect(session.endedAt == adjustedStart.addingTimeInterval(12 * 60))
        #expect(session.plannedEndAt == session.endedAt)
    }

    @Test func editingAreaOnlyFlowKeepsItIndependentAndStoresItsResult() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let originalArea = Area(name: "読書", type: .neutral)
        let updatedArea = Area(name: "学習", type: .neutral)
        let start = Date(timeIntervalSince1970: 30_000)
        let session = FlowSession(
            area: originalArea,
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
        context.insert(originalArea)
        context.insert(updatedArea)
        context.insert(session)

        try FlowHistoryEditor().update(
            session: session,
            todo: nil,
            area: updatedArea,
            startedAt: start.addingTimeInterval(60),
            focusSeconds: 20 * 60,
            memo: "第3章を読んだ",
            modelContext: context
        )

        #expect(session.todo == nil)
        #expect(session.area?.id == updatedArea.id)
        #expect(session.result == "第3章を読んだ")
        #expect(session.actualFocusDurationSeconds == 20 * 60)
        #expect(updatedArea.recordedFocusSeconds == 20 * 60)
        #expect(originalArea.recordedFocusSeconds == 0)
    }

    @Test func deletingFlowRebuildsStaleBlockProgressFromRemainingHistory() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let area = Area(name: "学習", type: .habit, focusDurationSeconds: 55 * 60)
        let todo = Todo(
            title: "AWS",
            area: area,
            measurement: .focusBlocks,
            plannedAmount: 2,
            actualProgress: 2,
            focusDurationSeconds: 55 * 60,
            status: .completed
        )
        let start = Date(timeIntervalSince1970: 25_000)
        let deletedSession = FlowSession(
            area: area,
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
        let remainingSession = FlowSession(
            area: area,
            todo: todo,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: start.addingTimeInterval(30 * 60),
            plannedEndAt: start.addingTimeInterval(60 * 60),
            endedAt: start.addingTimeInterval(60 * 60),
            plannedFocusDurationSeconds: 30 * 60,
            actualFocusDurationSeconds: 30 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        context.insert(area)
        context.insert(todo)
        context.insert(deletedSession)
        context.insert(remainingSession)

        try FlowHistoryEditor().delete(session: deletedSession, modelContext: context)

        #expect(todo.recordedFocusSeconds == 30 * 60)
        #expect(todo.actualProgress == 1)
        #expect(!todo.isCompleted)
        #expect(area.recordedFocusSeconds == 30 * 60)
    }

    @Test func deletingOneFlowSegmentRemovesOnlyItsProgress() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let area = Area(name: "仕事", type: .neutral, focusDurationSeconds: 25 * 60)
        let todo = Todo(
            title: "実装",
            area: area,
            measurement: .minutes,
            plannedAmount: 30,
            actualProgress: 25,
            focusDurationSeconds: 25 * 60
        )
        let start = Date(timeIntervalSince1970: 30_000)
        let session = FlowSession(
            area: area,
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
        let first = FlowSegment(session: session, area: area, todo: todo, startedAt: start, startFocusSeconds: 0)
        first.close(at: start.addingTimeInterval(10 * 60), totalFocusSeconds: 10 * 60)
        let second = FlowSegment(session: session, area: area, todo: todo, startedAt: start.addingTimeInterval(10 * 60), startFocusSeconds: 10 * 60)
        second.close(at: start.addingTimeInterval(25 * 60), totalFocusSeconds: 25 * 60)
        session.resolvedSegments = [first, second]
        context.insert(area)
        context.insert(todo)
        context.insert(session)

        try FlowHistoryEditor().delete(segment: first, from: session, modelContext: context)

        #expect(session.resolvedSegments.map(\.id) == [second.id])
        #expect(session.actualFocusDurationSeconds == 15 * 60)
        #expect(area.recordedFocusSeconds == 15 * 60)
        #expect(todo.recordedFocusSeconds == 15 * 60)
        #expect(todo.actualProgress == 15)
    }

    @Test func editingOneFlowSegmentPreservesSiblingContextAndReconcilesProgress() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let ankiArea = Area(name: "Anki", type: .neutral)
        let hiroconArea = Area(name: "広コン", type: .neutral)
        let ankiTodo = Todo(
            title: "単語を復習",
            area: ankiArea,
            measurement: .minutes,
            plannedAmount: 30
        )
        let hiroconTodo = Todo(
            title: "ゲーム特別版のプレゼンを作成",
            area: hiroconArea,
            measurement: .minutes,
            plannedAmount: 30
        )
        let start = Date(timeIntervalSince1970: 50_000)
        let session = FlowSession(
            area: hiroconArea,
            todo: hiroconTodo,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: start,
            plannedEndAt: start.addingTimeInterval(18 * 60),
            endedAt: start.addingTimeInterval(18 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 18 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        let ankiSegment = FlowSegment(
            session: session,
            area: ankiArea,
            todo: ankiTodo,
            startedAt: start,
            startFocusSeconds: 0
        )
        ankiSegment.close(
            at: start.addingTimeInterval(10 * 60),
            totalFocusSeconds: 10 * 60
        )
        let hiroconSegment = FlowSegment(
            session: session,
            area: hiroconArea,
            todo: hiroconTodo,
            startedAt: start.addingTimeInterval(10 * 60),
            startFocusSeconds: 10 * 60
        )
        hiroconSegment.close(
            at: start.addingTimeInterval(18 * 60),
            totalFocusSeconds: 18 * 60
        )
        session.resolvedSegments = [ankiSegment, hiroconSegment]
        context.insert(ankiArea)
        context.insert(hiroconArea)
        context.insert(ankiTodo)
        context.insert(hiroconTodo)
        context.insert(session)

        let editor = FlowHistoryEditor()
        try editor.update(
            segment: ankiSegment,
            in: session,
            todo: hiroconTodo,
            area: hiroconArea,
            focusSeconds: 8 * 60,
            memo: nil,
            modelContext: context,
            now: start.addingTimeInterval(20 * 60)
        )

        #expect(session.resolvedSegments.count == 2)
        #expect(session.resolvedSegments.contains { $0.id == hiroconSegment.id })
        #expect(ankiSegment.todo?.id == hiroconTodo.id)
        #expect(ankiSegment.area?.id == hiroconArea.id)
        #expect(ankiSegment.resolvedFocusSeconds == 8 * 60)
        #expect(hiroconSegment.todo?.id == hiroconTodo.id)
        #expect(hiroconSegment.resolvedFocusSeconds == 8 * 60)
        #expect(session.todo?.id == hiroconTodo.id)
        #expect(session.area?.id == hiroconArea.id)
        #expect(session.actualFocusDurationSeconds == 16 * 60)
        #expect(ankiTodo.recordedFocusSeconds == 0)
        #expect(hiroconTodo.recordedFocusSeconds == 16 * 60)
        #expect(ankiArea.recordedFocusSeconds == 0)
        #expect(hiroconArea.recordedFocusSeconds == 16 * 60)
    }

    @Test func deletingFlowSessionSoftDeletesRelatedBreaks() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let area = Area(name: "仕事", type: .neutral)
        let start = Date(timeIntervalSince1970: 40_000)
        let session = FlowSession(
            area: area,
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
        context.insert(area)
        context.insert(session)
        context.insert(flowBreak)

        try FlowHistoryEditor().delete(
            session: session,
            modelContext: context,
            now: start.addingTimeInterval(40 * 60)
        )

        #expect(flowBreak.deletedAt == start.addingTimeInterval(40 * 60))
    }

    @Test func editingBreakPushesOnlyOverlappingSessionsInTheSameSeries() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let area = Area(name: "仕事", type: .neutral)
        let seriesID = UUID()
        let start = Date(timeIntervalSince1970: 100_000)

        let first = FlowSession(
            seriesID: seriesID,
            area: area,
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
            area: area,
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
            area: area,
            todo: nil,
            startedAt: secondStart,
            startFocusSeconds: 0
        )
        secondSegment.close(at: secondStart.addingTimeInterval(25 * 60), totalFocusSeconds: 25 * 60)
        second.resolvedSegments = [secondSegment]
        let thirdStart = start.addingTimeInterval(60 * 60)
        let third = FlowSession(
            seriesID: seriesID,
            area: area,
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
            area: area,
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

        context.insert(area)
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

    @Test func editingBreakStartUpdatesItsIntervalAndPushesOnlyAnOverlap() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let area = Area(name: "仕事", type: .neutral)
        let seriesID = UUID()
        let start = Date(timeIntervalSince1970: 200_000)
        let first = FlowSession(
            seriesID: seriesID,
            area: area,
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
        let second = FlowSession(
            seriesID: seriesID,
            area: area,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: start.addingTimeInterval(30 * 60),
            plannedEndAt: start.addingTimeInterval(55 * 60),
            endedAt: start.addingTimeInterval(55 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        let flowBreak = FlowBreak(
            seriesID: seriesID,
            previousSessionID: first.id,
            nextSessionID: second.id,
            startedAt: start.addingTimeInterval(25 * 60),
            timerStoppedAt: start.addingTimeInterval(30 * 60),
            connectedUntil: start.addingTimeInterval(30 * 60),
            plannedDurationSeconds: 5 * 60
        )
        context.insert(area)
        context.insert(first)
        context.insert(second)
        context.insert(flowBreak)

        let newStart = start.addingTimeInterval(27 * 60)
        let result = try FlowBreakEditor().updateInterval(
            of: flowBreak,
            startedAt: newStart,
            minutes: 5,
            modelContext: context,
            now: start.addingTimeInterval(2 * 3_600)
        )

        #expect(flowBreak.startedAt == newStart)
        #expect(flowBreak.adjustedEndAt == start.addingTimeInterval(32 * 60))
        #expect(result.shiftedSeconds == 2 * 60)
        #expect(first.startedAt == start)
        #expect(second.startedAt == start.addingTimeInterval(32 * 60))
        #expect(second.endedAt == start.addingTimeInterval(57 * 60))
    }

    @Test func deletingBreakSoftDeletesOnlyThatHistoryRecord() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 300_000)
        let flowBreak = FlowBreak(
            seriesID: UUID(),
            previousSessionID: UUID(),
            startedAt: start,
            timerStoppedAt: start.addingTimeInterval(5 * 60),
            plannedDurationSeconds: 5 * 60
        )
        context.insert(flowBreak)
        let deletedAt = start.addingTimeInterval(60 * 60)

        try FlowBreakEditor().delete(
            flowBreak,
            modelContext: context,
            now: deletedAt
        )

        #expect(flowBreak.deletedAt == deletedAt)
        #expect(flowBreak.updatedAt == deletedAt)
        #expect(try context.fetch(FetchDescriptor<FlowBreak>()).count == 1)
    }

    @Test
    func breakEndTimeConvertsClockSelectionToDurationAcrossMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 29, hour: 23, minute: 55)
        )!
        let selectedClock = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 29, hour: 0, minute: 10)
        )!
        let flowBreak = FlowBreak(
            seriesID: UUID(),
            previousSessionID: UUID(),
            startedAt: start,
            plannedDurationSeconds: 5 * 60
        )
        let editor = FlowBreakEditor()

        let normalizedEnd = editor.normalizedEndTime(
            for: flowBreak,
            selectedTime: selectedClock,
            calendar: calendar
        )

        #expect(normalizedEnd == start.addingTimeInterval(15 * 60))
        #expect(editor.durationMinutes(from: start, to: normalizedEnd) == 15)
    }
}
