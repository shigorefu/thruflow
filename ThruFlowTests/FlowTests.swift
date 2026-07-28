//
//  FlowTests.swift
//  ThruFlowTests
//
//  Created by Codex on 2026/07/08.
//

import Foundation
import SwiftData
import Testing
@testable import ThruFlow

struct FlowTests {
    @Test @MainActor func sprintUsesNewRawValueAndReadsLegacyPersistenceValue() throws {
        #expect(FlowMode.sprint.rawValue == "sprint")
        #expect(FlowMode.persistedMode(rawValue: "sprint") == .sprint)
        #expect(FlowMode.persistedMode(rawValue: "twelveThree") == .sprint)

        let legacyData = Data("\"twelveThree\"".utf8)
        #expect(try JSONDecoder().decode(FlowMode.self, from: legacyData) == .sprint)
        #expect(String(decoding: try JSONEncoder().encode(FlowMode.sprint), as: UTF8.self) == "\"sprint\"")
    }

    @Test func blockDisplayUsesProductValues() {
        #expect(BlockUnit.displayText(forFocusedSeconds: 11 * 60) == "0 Block")
        #expect(BlockUnit.displayText(forFocusedSeconds: 12 * 60) == "0.5 Block")
        #expect(BlockUnit.displayText(forFocusedSeconds: 24 * 60) == "1 Block")
        #expect(BlockUnit.displayText(forFocusedSeconds: 25 * 60) == "1 Block")
        #expect(BlockUnit.displayText(forFocusedSeconds: 37 * 60) == "1.5 Blocks")
        #expect(BlockUnit.displayText(forFocusedSeconds: 50 * 60) == "2 Blocks")
    }

    @Test func blockCalculationUsesHalfBlockUnits() {
        let focusSeconds = 25 * 60
        let breakSeconds = 5 * 60

        #expect(BlockUnit.blocks(forFocusedSeconds: focusSeconds) == 1)
        #expect(BlockUnit.blocks(forFocusedSeconds: focusSeconds + breakSeconds) == 1)
    }

    @Test func seriesContinuationWindowIsOneAndAHalfTimesThePlannedBreak() {
        #expect(FlowSeriesPolicy.continuationWindow(forPlannedBreakSeconds: 3 * 60) == 4 * 60 + 30)
        #expect(FlowSeriesPolicy.continuationWindow(forPlannedBreakSeconds: 5 * 60) == 7 * 60 + 30)
        #expect(FlowSeriesPolicy.continuationWindow(forPlannedBreakSeconds: 10 * 60) == 15 * 60)
        #expect(FlowSeriesPolicy.continuationWindow(forPlannedBreakSeconds: 20 * 60) == 30 * 60)
    }

    @Test func longBreakIsDueAfterEveryFourAccumulatedBlocks() {
        let policy = FlowSeriesPolicy()

        #expect(!policy.shouldUseLongBreak(totalSeriesFocusSeconds: 95 * 60, completedLongBreakCount: 0))
        #expect(policy.shouldUseLongBreak(totalSeriesFocusSeconds: 96 * 60, completedLongBreakCount: 0))
        #expect(!policy.shouldUseLongBreak(totalSeriesFocusSeconds: 96 * 60, completedLongBreakCount: 1))
        #expect(policy.shouldUseLongBreak(totalSeriesFocusSeconds: 192 * 60, completedLongBreakCount: 1))
    }

    @Test func timerStartPauseResumeAndFinishUseAbsoluteDates() {
        let engine = FlowTimerEngine()
        let start = Date(timeIntervalSince1970: 1_000)
        let pausedAt = start.addingTimeInterval(5 * 60)
        let resumedAt = pausedAt.addingTimeInterval(2 * 60)
        let finishedAt = resumedAt.addingTimeInterval(7 * 60)

        let initial = engine.start(mode: .twentyFiveFive, now: start)
        let paused = engine.pause(initial, now: pausedAt)
        let resumed = engine.resume(paused, now: resumedAt)
        let finished = engine.finish(resumed, now: finishedAt)

        #expect(paused.phase == .paused)
        #expect(resumed.phase == .focusing)
        #expect(resumed.accumulatedPauseDurationSeconds == 2 * 60)
        #expect(engine.remainingSeconds(for: resumed, now: resumedAt) == 20 * 60)
        #expect(finished.phase == .awaitingResult)
        #expect(finished.actualFocusDurationSeconds == 12 * 60)
        #expect(engine.remainingSeconds(for: finished, now: finishedAt) == 0)
    }

    @Test func focusUnderOneMinuteIsNotCredited() {
        let engine = FlowTimerEngine()
        let start = Date(timeIntervalSince1970: 1_500)

        let initial = engine.start(mode: .twentyFiveFive, now: start)
        let finishedTooSoon = engine.finish(initial, now: start.addingTimeInterval(59))
        let finishedAtThreshold = engine.finish(initial, now: start.addingTimeInterval(60))
        let breakTooSoon = engine.startBreak(initial, now: start.addingTimeInterval(59))

        #expect(finishedTooSoon.actualFocusDurationSeconds == 0)
        #expect(finishedAtThreshold.actualFocusDurationSeconds == 60)
        #expect(breakTooSoon.actualFocusDurationSeconds == 0)
    }

    @Test func timerRestoresFromBackgroundWithoutAutoStartingBreak() {
        let engine = FlowTimerEngine()
        let start = Date(timeIntervalSince1970: 2_000)
        let restoredAt = start.addingTimeInterval(26 * 60)

        let initial = engine.start(mode: .twentyFiveFive, now: start)
        let restored = engine.advanceIfNeeded(initial, now: restoredAt)

        #expect(restored.phase == .focusing)
        #expect(restored.actualFocusDurationSeconds == nil)
        #expect(engine.remainingSeconds(for: restored, now: restoredAt) == -60)
        #expect(engine.actualFocusDuration(for: restored, now: restoredAt) == 26 * 60)
    }

    @Test func manualBreakBeforeTwentyFourMinutesUsesShortBreak() {
        let engine = FlowTimerEngine()
        let start = Date(timeIntervalSince1970: 2_500)
        let breakStartedAt = start.addingTimeInterval(23 * 60)

        let initial = engine.start(mode: .twentyFiveFive, now: start)
        let breakState = engine.startBreak(initial, now: breakStartedAt)

        #expect(breakState.phase == .breakTime)
        #expect(breakState.actualFocusDurationSeconds == 23 * 60)
        #expect(breakState.plannedBreakDurationSeconds == 3 * 60)
        #expect(engine.remainingSeconds(for: breakState, now: breakStartedAt) == 3 * 60)
    }

    @Test func manualBreakAtTwentyFourMinutesCountsAsTwentyFiveFive() {
        let engine = FlowTimerEngine()
        let start = Date(timeIntervalSince1970: 2_600)
        let breakStartedAt = start.addingTimeInterval(24 * 60)

        let initial = engine.start(mode: .twentyFiveFive, now: start)
        let breakState = engine.startBreak(initial, now: breakStartedAt)

        #expect(breakState.phase == .breakTime)
        #expect(breakState.actualFocusDurationSeconds == 25 * 60)
        #expect(breakState.plannedBreakDurationSeconds == 5 * 60)
        #expect(engine.remainingSeconds(for: breakState, now: breakStartedAt.addingTimeInterval(6 * 60)) == -60)
    }

    @Test func manualBreakAfterThresholdKeepsActualOvertimeFocus() {
        let engine = FlowTimerEngine()
        let start = Date(timeIntervalSince1970: 2_700)
        let breakStartedAt = start.addingTimeInterval(35 * 60)

        let initial = engine.start(mode: .twentyFiveFive, now: start)
        let breakState = engine.startBreak(initial, now: breakStartedAt)

        #expect(breakState.phase == .breakTime)
        #expect(breakState.actualFocusDurationSeconds == 35 * 60)
        #expect(breakState.plannedBreakDurationSeconds == 5 * 60)
    }

    @Test func manualBreakAtFortyNineMinutesCountsAsFiftyTen() {
        let engine = FlowTimerEngine()
        let start = Date(timeIntervalSince1970: 2_800)
        let breakStartedAt = start.addingTimeInterval(49 * 60)

        let initial = engine.start(mode: .twentyFiveFive, now: start)
        let breakState = engine.startBreak(initial, now: breakStartedAt)

        #expect(breakState.phase == .breakTime)
        #expect(breakState.mode == .twentyFiveFive)
        #expect(breakState.actualFocusDurationSeconds == 50 * 60)
        #expect(breakState.plannedBreakDurationSeconds == 10 * 60)
    }

    @Test func adaptiveExtendsOneTimerStateThroughTwelveTwentyFiveFifty() {
        let engine = FlowTimerEngine()
        let start = Date(timeIntervalSince1970: 3_000)

        let initial = engine.start(mode: .adaptive, now: start)
        let firstDecision = engine.advanceIfNeeded(initial, now: start.addingTimeInterval(12 * 60))
        let extendedTo25 = engine.extendAdaptive(firstDecision, now: start.addingTimeInterval(12 * 60))
        let secondDecision = engine.advanceIfNeeded(extendedTo25, now: start.addingTimeInterval(25 * 60))
        let extendedTo50 = engine.extendAdaptive(secondDecision, now: start.addingTimeInterval(25 * 60))

        #expect(initial.plannedFocusDurationSeconds == 12 * 60)
        #expect(firstDecision.phase == .awaitingExtensionDecision)
        #expect(extendedTo25.plannedFocusDurationSeconds == 25 * 60)
        #expect(secondDecision.phase == .awaitingExtensionDecision)
        #expect(extendedTo50.plannedFocusDurationSeconds == 50 * 60)
        #expect(extendedTo50.mode == .adaptive)
    }

    @Test func focusProgressStaysAttachedToItsDirectionAndTodo() {
        let reading = Direction(
            name: "読書",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .daily,
            goalUnit: .focusBlocks,
            goalSchedule: .everyDay
        )
        let anki = Direction(
            name: "Anki",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .daily,
            goalUnit: .focusBlocks,
            goalSchedule: .everyDay
        )
        let readingTodo = Todo(title: "第8章", direction: reading, measurement: .focusBlocks, plannedAmount: 1)
        let ankiTodo = Todo(title: "復習", direction: anki, measurement: .focusBlocks, plannedAmount: 1)
        let calculator = FlowProgressCalculator()

        calculator.applyFocusDuration(seconds: 12 * 60, direction: reading, todo: readingTodo)
        calculator.applyFocusDuration(seconds: 13 * 60, direction: anki, todo: ankiTodo)

        #expect(reading.recordedFocusSeconds == 12 * 60)
        #expect(anki.recordedFocusSeconds == 13 * 60)
        #expect(readingTodo.recordedFocusSeconds == 12 * 60)
        #expect(ankiTodo.recordedFocusSeconds == 13 * 60)
        #expect(readingTodo.actualProgress == 0)
        #expect(ankiTodo.actualProgress == 0)
    }

    @Test func todoReceivesFullBlockAfterAccumulatedFocusMinutesReachTwentyFive() {
        let direction = Direction(
            name: "仕事",
            type: .neutral,
            goalTarget: 2,
            goalPeriod: .daily,
            goalUnit: .focusBlocks,
            goalSchedule: .everyDay
        )
        let todo = Todo(title: "資料", direction: direction, measurement: .focusBlocks, plannedAmount: 2)
        let calculator = FlowProgressCalculator()

        calculator.applyFocusDuration(seconds: 12 * 60, direction: direction, todo: todo)
        calculator.applyFocusDuration(seconds: 13 * 60, direction: direction, todo: todo)

        #expect(todo.recordedFocusSeconds == 25 * 60)
        #expect(todo.actualProgress == 1)
        #expect(direction.recordedFocusSeconds == 25 * 60)
    }

    @Test func twoHalfBlocksCompleteOneBlockTodo() {
        let direction = Direction(name: "読書", type: .habit)
        let todo = Todo(title: "タスク", direction: direction, measurement: .focusBlocks, plannedAmount: 2)
        let calculator = FlowProgressCalculator()

        calculator.applyFocusDuration(seconds: 12 * 60, direction: direction, todo: todo)
        calculator.applyFocusDuration(seconds: 12 * 60, direction: direction, todo: todo)

        #expect(todo.recordedFocusSeconds == 24 * 60)
        #expect(todo.actualProgress == 1)
        #expect(todo.status == .active)
        #expect(TodoProgressCalculator().summary(
            measurement: todo.measurement,
            plannedAmount: todo.plannedAmount,
            actualProgress: todo.actualProgress,
            focusDurationSeconds: todo.focusDurationSeconds
        ) == "1 Block / 2 Blocks")
    }

    @Test func manualBlockTodoProgressUsesTodoMeasurementWithoutDirectionGoal() {
        let direction = Direction(name: "仕事", type: .neutral)
        let todo = Todo(title: "実装", direction: direction, measurement: .focusBlocks, plannedAmount: 2)
        let calculator = FlowProgressCalculator()

        calculator.applyFocusDuration(seconds: 25 * 60, direction: direction, todo: todo)

        #expect(direction.recordedFocusSeconds == 25 * 60)
        #expect(todo.recordedFocusSeconds == 25 * 60)
        #expect(todo.actualProgress == 1)
        #expect(todo.status == .active)
    }

    @Test func occurrenceDirectionDoesNotWriteFlowProgressToTodo() {
        let direction = Direction(
            name: "筋トレ",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .daily,
            goalUnit: .occurrences,
            goalSchedule: .everyDay
        )
        let todo = Todo(title: "筋トレ", direction: direction, measurement: .checkbox)
        let calculator = FlowProgressCalculator()

        calculator.applyFocusDuration(seconds: 25 * 60, direction: direction, todo: todo)

        #expect(direction.recordedFocusSeconds == 25 * 60)
        #expect(todo.recordedFocusSeconds == 0)
        #expect(todo.actualProgress == 0)
    }

    @Test func minuteDirectionWritesFocusedMinutesToTodo() {
        let direction = Direction(
            name: "日本語",
            type: .habit,
            goalTarget: 30,
            goalPeriod: .daily,
            goalUnit: .minutes,
            goalSchedule: .everyDay
        )
        let todo = Todo(title: "日本語", direction: direction, measurement: .minutes, plannedAmount: 30)
        let calculator = FlowProgressCalculator()

        calculator.applyFocusDuration(seconds: 12 * 60, direction: direction, todo: todo)

        #expect(todo.recordedFocusSeconds == 12 * 60)
        #expect(todo.actualProgress == 12)
    }

    @Test func seekForwardAddsFiveMinutesWithoutChangingModeOrElapsedFocus() {
        let engine = FlowTimerEngine()
        let start = Date(timeIntervalSince1970: 4_000)
        let changedAt = start.addingTimeInterval(8 * 60)

        let sprint = engine.start(mode: .sprint, now: start)
        let extended = engine.seekForward(sprint, now: changedAt)

        #expect(extended.mode == .sprint)
        #expect(extended.plannedFocusDurationSeconds == 17 * 60)
        #expect(extended.plannedBreakDurationSeconds == 3 * 60)
        #expect(extended.plannedEndAt == sprint.plannedEndAt.addingTimeInterval(5 * 60))
        #expect(engine.actualFocusDuration(for: extended, now: changedAt) == 8 * 60)
        #expect(engine.remainingSeconds(for: extended, now: changedAt) == 9 * 60)
    }

    @Test func seekBackwardSubtractsFiveMinutesAndKeepsOneMinuteRemaining() {
        let engine = FlowTimerEngine()
        let start = Date(timeIntervalSince1970: 5_000)
        let changedAt = start.addingTimeInterval(20 * 60)

        let focus = engine.start(mode: .twentyFiveFive, now: start)
        let shortened = engine.seekBackward(focus, now: changedAt)
        let unchanged = engine.seekBackward(shortened, now: changedAt)

        #expect(shortened.mode == .twentyFiveFive)
        #expect(shortened.plannedFocusDurationSeconds == 21 * 60)
        #expect(shortened.plannedEndAt == start.addingTimeInterval(21 * 60))
        #expect(engine.remainingSeconds(for: shortened, now: changedAt) == 60)
        #expect(unchanged == shortened)
    }

    @Test func seekUsesPausedFocusTimeAndPreservesPauseState() {
        let engine = FlowTimerEngine()
        let start = Date(timeIntervalSince1970: 5_500)
        let pausedAt = start.addingTimeInterval(10 * 60)
        let focus = engine.start(mode: .twentyFiveFive, now: start)
        let paused = engine.pause(focus, now: pausedAt)

        let extended = engine.seekForward(paused, now: pausedAt.addingTimeInterval(30 * 60))
        let restored = engine.seekBackward(extended, now: pausedAt.addingTimeInterval(30 * 60))

        #expect(extended.phase == .paused)
        #expect(extended.pausedAt == pausedAt)
        #expect(extended.plannedFocusDurationSeconds == 30 * 60)
        #expect(engine.remainingSeconds(for: extended, now: pausedAt.addingTimeInterval(30 * 60)) == 20 * 60)
        #expect(restored.plannedFocusDurationSeconds == 25 * 60)
        #expect(engine.remainingSeconds(for: restored, now: pausedAt.addingTimeInterval(30 * 60)) == 15 * 60)
    }

    @Test func seekCrossesPresetThresholdsWithoutRenamingTheMode() {
        let engine = FlowTimerEngine()
        let start = Date(timeIntervalSince1970: 5_800)
        let sprint = engine.start(mode: .sprint, now: start)

        let seventeen = engine.seekForward(sprint, now: start)
        let twentyTwo = engine.seekForward(seventeen, now: start)
        let twentySeven = engine.seekForward(twentyTwo, now: start)

        #expect(twentySeven.mode == .sprint)
        #expect(twentySeven.plannedFocusDurationSeconds == 27 * 60)
        #expect(twentySeven.plannedBreakDurationSeconds == 5 * 60)
    }

    @Test func seekIsIgnoredOutsideFocusingOrPausedPhases() {
        let engine = FlowTimerEngine()
        let start = Date(timeIntervalSince1970: 6_000)

        let initial = engine.start(mode: .twentyFiveFive, now: start)
        let inBreak = engine.startBreak(initial, now: start.addingTimeInterval(26 * 60))
        let pausedBreak = engine.pause(inBreak, now: start.addingTimeInterval(27 * 60))

        #expect(inBreak.phase == .breakTime)
        #expect(engine.seekForward(inBreak, now: start.addingTimeInterval(26 * 60)) == inBreak)
        #expect(engine.seekBackward(inBreak, now: start.addingTimeInterval(26 * 60)) == inBreak)
        #expect(engine.seekForward(pausedBreak, now: start.addingTimeInterval(28 * 60)) == pausedBreak)
        #expect(engine.seekBackward(pausedBreak, now: start.addingTimeInterval(28 * 60)) == pausedBreak)
    }

    @Test func changingModeMovesThePlannedEndWithoutResettingElapsedFocus() {
        let engine = FlowTimerEngine()
        let start = Date(timeIntervalSince1970: 6_500)
        let changedAt = start.addingTimeInterval(10 * 60)
        let initial = engine.start(mode: .twentyFiveFive, now: start)

        let deep = engine.changeMode(.fiftyTen, for: initial)

        #expect(deep.mode == .fiftyTen)
        #expect(deep.startedAt == start)
        #expect(deep.plannedFocusDurationSeconds == 50 * 60)
        #expect(deep.plannedBreakDurationSeconds == 10 * 60)
        #expect(engine.actualFocusDuration(for: deep, now: changedAt) == 10 * 60)
        #expect(engine.remainingSeconds(for: deep, now: changedAt) == 40 * 60)
    }

    @Test func changingModeIsIgnoredDuringBreakIncludingPausedBreak() {
        let engine = FlowTimerEngine()
        let start = Date(timeIntervalSince1970: 6_600)
        let focus = engine.start(mode: .twentyFiveFive, now: start)
        let resting = engine.startBreak(focus, now: start.addingTimeInterval(25 * 60))
        let pausedRest = engine.pause(resting, now: start.addingTimeInterval(26 * 60))

        #expect(engine.changeMode(.fiftyTen, for: resting) == resting)
        #expect(engine.changeMode(.fiftyTen, for: pausedRest) == pausedRest)
    }

    @Test func changingModeAfterItsTargetKeepsElapsedFocusAsOvertime() {
        let engine = FlowTimerEngine()
        let start = Date(timeIntervalSince1970: 6_650)
        let changedAt = start.addingTimeInterval(27 * 60)
        let initial = engine.start(mode: .fiftyTen, now: start)

        let focus = engine.changeMode(.twentyFiveFive, for: initial)
        let deep = engine.changeMode(.fiftyTen, for: focus)

        #expect(focus.mode == .twentyFiveFive)
        #expect(engine.remainingSeconds(for: focus, now: changedAt) == -2 * 60)
        #expect(deep.mode == .fiftyTen)
        #expect(engine.remainingSeconds(for: deep, now: changedAt) == 23 * 60)
        #expect(engine.actualFocusDuration(for: deep, now: changedAt) == 27 * 60)
    }

    @Test @MainActor func breakProgressDrainsAndOvertimeUsesPlusPrefix() {
        let engine = FlowTimerEngine()
        let start = Date(timeIntervalSince1970: 6_700)
        let focus = engine.start(mode: .twentyFiveFive, now: start)
        let breakStartedAt = start.addingTimeInterval(25 * 60)
        let resting = engine.startBreak(focus, now: breakStartedAt)
        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.timerState = resting

        #expect(store.phaseProgress(now: breakStartedAt) == 1)
        #expect(store.phaseProgress(now: breakStartedAt.addingTimeInterval(150)) == 0.5)
        #expect(store.phaseProgress(now: breakStartedAt.addingTimeInterval(5 * 60 + 1)) == 0)
        #expect(ActiveFlowStore.timeText(seconds: 3 * 60) == "03:00")
        #expect(store.remainingText(now: breakStartedAt.addingTimeInterval(5 * 60 + 1)) == "+00:01")
    }

    @Test func segmentedFlowCreditsEachTaskOnlyForItsOwnFocusTime() {
        let start = Date(timeIntervalSince1970: 7_000)
        let writing = Direction(name: "執筆", type: .neutral)
        let review = Direction(name: "レビュー", type: .neutral)
        let writingTodo = Todo(title: "本文", direction: writing, measurement: .minutes, plannedAmount: 30)
        let reviewTodo = Todo(title: "確認", direction: review, measurement: .minutes, plannedAmount: 20)
        let session = FlowSession(
            direction: review,
            todo: reviewTodo,
            mode: .twentyFiveFive,
            startedAt: start,
            plannedEndAt: start.addingTimeInterval(25 * 60),
            endedAt: start.addingTimeInterval(25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        let first = FlowSegment(
            session: session,
            direction: writing,
            todo: writingTodo,
            startedAt: start,
            startFocusSeconds: 0
        )
        first.close(at: start.addingTimeInterval(16 * 60), totalFocusSeconds: 16 * 60)
        let second = FlowSegment(
            session: session,
            direction: review,
            todo: reviewTodo,
            startedAt: start.addingTimeInterval(16 * 60),
            startFocusSeconds: 16 * 60
        )
        second.close(at: start.addingTimeInterval(25 * 60), totalFocusSeconds: 25 * 60)
        session.resolvedSegments = [first, second]

        FlowProgressCalculator().applySession(session, fallbackSeconds: 25 * 60)

        #expect(writingTodo.recordedFocusSeconds == 16 * 60)
        #expect(writingTodo.actualProgress == 16)
        #expect(reviewTodo.recordedFocusSeconds == 9 * 60)
        #expect(reviewTodo.actualProgress == 9)
        #expect(writing.recordedFocusSeconds == 16 * 60)
        #expect(review.recordedFocusSeconds == 9 * 60)
    }

    @Test @MainActor func activeFlowSwitchesTaskWithoutResettingTimer() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 8_000)
        let firstDirection = Direction(name: "執筆", type: .neutral)
        let secondDirection = Direction(name: "確認", type: .neutral)
        let firstTodo = Todo(title: "本文", direction: firstDirection, measurement: .minutes, plannedAmount: 30)
        let secondTodo = Todo(title: "レビュー", direction: secondDirection, measurement: .minutes, plannedAmount: 20)
        context.insert(firstDirection)
        context.insert(secondDirection)
        context.insert(firstTodo)
        context.insert(secondTodo)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(direction: firstDirection, todo: firstTodo, mode: .twentyFiveFive)
        store.start(direction: firstDirection, todo: firstTodo, modelContext: context, now: start)
        store.selectContext(
            direction: secondDirection,
            todo: secondTodo,
            modelContext: context,
            now: start.addingTimeInterval(16 * 60)
        )

        #expect(store.timerState?.startedAt == start)
        #expect(store.selectedTodoID == secondTodo.id)
        #expect(store.activeSession?.resolvedSegments.count == 2)

        store.stop(modelContext: context, now: start.addingTimeInterval(25 * 60))

        let segments = store.activeSession?.resolvedSegments.sorted { $0.startedAt < $1.startedAt } ?? []
        #expect(segments.map(\.resolvedFocusSeconds) == [16 * 60, 9 * 60])
        #expect(firstTodo.recordedFocusSeconds == 16 * 60)
        #expect(secondTodo.recordedFocusSeconds == 9 * 60)
    }

    @Test @MainActor func subMinuteTaskSwitchTransfersElapsedTimeToNewTask() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 8_250)
        let firstDirection = Direction(name: "AWS", type: .neutral)
        let secondDirection = Direction(name: "読書", type: .neutral)
        let firstTodo = Todo(title: "AWS", direction: firstDirection, measurement: .minutes, plannedAmount: 30)
        let secondTodo = Todo(title: "本を読む", direction: secondDirection, measurement: .minutes, plannedAmount: 20)
        context.insert(firstDirection)
        context.insert(secondDirection)
        context.insert(firstTodo)
        context.insert(secondTodo)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(direction: firstDirection, todo: firstTodo, mode: .twentyFiveFive)
        store.start(direction: firstDirection, todo: firstTodo, modelContext: context, now: start)
        let sessionID = try #require(store.activeSession?.id)

        store.selectContext(
            direction: secondDirection,
            todo: secondTodo,
            modelContext: context,
            now: start.addingTimeInterval(30)
        )

        let activeSegment = try #require(store.activeSession?.resolvedSegments.first)
        #expect(store.activeSession?.id == sessionID)
        #expect(store.activeSession?.resolvedSegments.count == 1)
        #expect(activeSegment.startedAt == start)
        #expect(activeSegment.startFocusSeconds == 0)
        #expect(activeSegment.todo?.id == secondTodo.id)
        #expect(activeSegment.direction?.id == secondDirection.id)

        store.stop(modelContext: context, now: start.addingTimeInterval(2 * 60))

        #expect(firstTodo.recordedFocusSeconds == 0)
        #expect(secondTodo.recordedFocusSeconds == 2 * 60)
    }

    @Test func contextSwitchTransfersOnlyWhenSegmentIsStrictlyUnderOneMinute() {
        let policy = FlowContextSwitchPolicy()

        #expect(policy.shouldTransferCurrentSegment(totalFocusSeconds: 59, segmentStartFocusSeconds: 0))
        #expect(!policy.shouldTransferCurrentSegment(totalFocusSeconds: 60, segmentStartFocusSeconds: 0))
    }

    @Test @MainActor func returningWithinOneMinuteMergesBackIntoPreviousTaskSegment() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 8_400)
        let firstDirection = Direction(name: "AWS", type: .neutral)
        let secondDirection = Direction(name: "読書", type: .neutral)
        let firstTodo = Todo(title: "AWS", direction: firstDirection, measurement: .minutes, plannedAmount: 30)
        let secondTodo = Todo(title: "本を読む", direction: secondDirection, measurement: .minutes, plannedAmount: 20)
        context.insert(firstDirection)
        context.insert(secondDirection)
        context.insert(firstTodo)
        context.insert(secondTodo)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(direction: firstDirection, todo: firstTodo, mode: .twentyFiveFive)
        store.start(direction: firstDirection, todo: firstTodo, modelContext: context, now: start)
        let sessionID = try #require(store.activeSession?.id)

        store.selectContext(
            direction: secondDirection,
            todo: secondTodo,
            modelContext: context,
            now: start.addingTimeInterval(2 * 60)
        )
        store.selectContext(
            direction: firstDirection,
            todo: firstTodo,
            modelContext: context,
            now: start.addingTimeInterval(2 * 60 + 30)
        )

        let activeSegment = try #require(store.activeSession?.resolvedSegments.first)
        #expect(store.activeSession?.id == sessionID)
        #expect(store.activeSession?.resolvedSegments.count == 1)
        #expect(activeSegment.todo?.id == firstTodo.id)
        #expect(activeSegment.startedAt == start)
        #expect(activeSegment.endedAt == nil)

        store.stop(modelContext: context, now: start.addingTimeInterval(3 * 60))

        #expect(firstTodo.recordedFocusSeconds == 3 * 60)
        #expect(secondTodo.recordedFocusSeconds == 0)
    }

    @Test @MainActor func cancellingResultMemoRestoresFlowAndRemovesProvisionalProgress() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 8_500)
        let direction = Direction(name: "執筆", type: .neutral)
        let todo = Todo(title: "本文", direction: direction, measurement: .minutes, plannedAmount: 30)
        context.insert(direction)
        context.insert(todo)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(direction: direction, todo: todo, mode: .twentyFiveFive)
        store.start(direction: direction, todo: todo, modelContext: context, now: start)
        store.stop(modelContext: context, now: start.addingTimeInterval(10 * 60))

        #expect(store.phase == .awaitingResult)
        #expect(todo.recordedFocusSeconds == 10 * 60)
        #expect(store.activeSession?.resolvedSegments.first?.endedAt != nil)

        store.cancelResultMemo(modelContext: context, now: start.addingTimeInterval(10 * 60 + 10))

        #expect(store.phase == .focusing)
        #expect(store.activeSession?.status == .active)
        #expect(store.activeSession?.resolvedSegments.first?.endedAt == nil)
        #expect(todo.recordedFocusSeconds == 0)
        #expect(direction.recordedFocusSeconds == 0)
    }

    @Test @MainActor func startingWorkDuringBreakImmediatelyCreatesNextFlow() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 9_000)
        let breakStartedAt = start.addingTimeInterval(25 * 60)
        let restartedAt = breakStartedAt.addingTimeInterval(2 * 60)
        let direction = Direction(name: "仕事", type: .neutral)
        let todo = Todo(title: "実装", direction: direction)
        context.insert(direction)
        context.insert(todo)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(direction: direction, todo: todo, mode: .twentyFiveFive)
        store.start(direction: direction, todo: todo, modelContext: context, now: start)
        let firstSession = try #require(store.activeSession)
        store.startBreak(modelContext: context, now: breakStartedAt)

        store.startNextFlow(
            direction: direction,
            todo: todo,
            modelContext: context,
            now: restartedAt
        )

        #expect(firstSession.status == .completed)
        #expect(firstSession.endedAt == restartedAt)
        #expect(store.phase == .focusing)
        #expect(store.timerState?.startedAt == restartedAt)
        #expect(store.activeSession?.id != firstSession.id)
        #expect(store.activeSession?.seriesID == firstSession.seriesID)

        let breaks = try context.fetch(FetchDescriptor<FlowBreak>())
        #expect(breaks.count == 1)
        #expect(breaks[0].previousSessionID == firstSession.id)
        #expect(breaks[0].nextSessionID == store.activeSession?.id)
        #expect(breaks[0].connectedUntil == restartedAt)
    }

    @Test @MainActor func destroyingDuringBreakDeletesOnlyBreak() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 10_000)
        let breakStartedAt = start.addingTimeInterval(25 * 60)
        let direction = Direction(name: "仕事", type: .neutral)
        let todo = Todo(title: "実装", direction: direction, measurement: .minutes, plannedAmount: 60)
        context.insert(direction)
        context.insert(todo)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(direction: direction, todo: todo, mode: .twentyFiveFive)
        store.start(direction: direction, todo: todo, modelContext: context, now: start)
        let sessionID = try #require(store.activeSession?.id)
        store.startBreak(modelContext: context, now: breakStartedAt)

        store.destroy(modelContext: context, now: breakStartedAt.addingTimeInterval(60))

        let sessions = try context.fetch(FetchDescriptor<FlowSession>())
        let flowBreak = try #require(context.fetch(FetchDescriptor<FlowBreak>()).first)
        #expect(sessions.map(\.id) == [sessionID])
        #expect(sessions.first?.status == .completed)
        #expect(flowBreak.deletedAt == breakStartedAt.addingTimeInterval(60))
        #expect(todo.recordedFocusSeconds == 25 * 60)
        #expect(todo.actualProgress == 25)
        #expect(direction.recordedFocusSeconds == 25 * 60)
        #expect(store.timerState == nil)
    }

    @Test @MainActor func destroyingCreditedFlowRollsBackTaskAndDirectionProgress() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 11_000)
        let direction = Direction(name: "仕事", type: .neutral)
        let todo = Todo(title: "実装", direction: direction, measurement: .minutes, plannedAmount: 25)
        context.insert(direction)
        context.insert(todo)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(direction: direction, todo: todo, mode: .twentyFiveFive)
        store.start(direction: direction, todo: todo, modelContext: context, now: start)
        store.stop(modelContext: context, now: start.addingTimeInterval(25 * 60))
        #expect(todo.isCompleted)

        store.destroy(modelContext: context, now: start.addingTimeInterval(25 * 60 + 1))

        #expect(try context.fetch(FetchDescriptor<FlowSession>()).isEmpty)
        #expect(todo.recordedFocusSeconds == 0)
        #expect(todo.actualProgress == 0)
        #expect(!todo.isCompleted)
        #expect(direction.recordedFocusSeconds == 0)
        #expect(store.timerState == nil)
    }

    @Test @MainActor func startingAfterContinuationWindowCreatesNewSeries() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 12_000)
        let breakStartedAt = start.addingTimeInterval(25 * 60)
        let restartedAt = breakStartedAt.addingTimeInterval(7 * 60 + 31)
        let direction = Direction(name: "仕事", type: .neutral)
        context.insert(direction)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(direction: direction, todo: nil, mode: .twentyFiveFive)
        store.start(direction: direction, todo: nil, modelContext: context, now: start)
        let firstSeriesID = try #require(store.activeSession?.seriesID)
        store.startBreak(modelContext: context, now: breakStartedAt)
        store.startNextFlow(direction: direction, todo: nil, modelContext: context, now: restartedAt)

        #expect(store.activeSession?.seriesID != firstSeriesID)
        let flowBreak = try #require(context.fetch(FetchDescriptor<FlowBreak>()).first)
        #expect(flowBreak.nextSessionID == nil)
    }

    @Test @MainActor func fourthAccumulatedBlockStartsLongBreak() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 20_000)
        let direction = Direction(name: "仕事", type: .neutral)
        context.insert(direction)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(direction: direction, todo: nil, mode: .twentyFiveFive)
        store.start(direction: direction, todo: nil, modelContext: context, now: start)
        let seriesID = try #require(store.activeSession?.seriesID)
        let prior = FlowSession(
            seriesID: seriesID,
            direction: direction,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: start.addingTimeInterval(-75 * 60),
            plannedEndAt: start,
            endedAt: start,
            plannedFocusDurationSeconds: 75 * 60,
            actualFocusDurationSeconds: 75 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        context.insert(prior)

        store.startBreak(modelContext: context, now: start.addingTimeInterval(25 * 60))

        #expect(store.timerState?.plannedBreakDurationSeconds == 20 * 60)
        #expect(store.timerState?.isLongBreak == true)
        let flowBreak = try #require(context.fetch(FetchDescriptor<FlowBreak>()).first)
        #expect(flowBreak.isLongBreak)
        #expect(flowBreak.continuationDeadline == start.addingTimeInterval(25 * 60 + 30 * 60))
    }

    @Test @MainActor func flowNotificationsWarnAfterOneActiveHourAndAccountForPause() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 25_000)
        let direction = Direction(name: "仕事", type: .neutral)
        let notifications = TestFlowNotificationService()
        context.insert(direction)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: notifications)
        store.configure(direction: direction, todo: nil, mode: .twentyFiveFive)
        store.start(direction: direction, todo: nil, modelContext: context, now: start)

        #expect(notifications.focusFinishedDates.last == start.addingTimeInterval(25 * 60))
        #expect(notifications.runningTooLong.last?.phase == .focus)
        #expect(notifications.runningTooLong.last?.fireDate == start.addingTimeInterval(60 * 60))

        store.pause(modelContext: context, now: start.addingTimeInterval(10 * 60))
        store.resume(modelContext: context, now: start.addingTimeInterval(20 * 60))

        #expect(notifications.focusFinishedDates.last == start.addingTimeInterval(35 * 60))
        #expect(notifications.runningTooLong.last?.phase == .focus)
        #expect(notifications.runningTooLong.last?.fireDate == start.addingTimeInterval(70 * 60))
    }

    @Test @MainActor func breakNotificationsWarnAfterOneActiveHourAndResumeAsBreak() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 28_000)
        let breakStart = start.addingTimeInterval(25 * 60)
        let direction = Direction(name: "仕事", type: .neutral)
        let notifications = TestFlowNotificationService()
        context.insert(direction)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: notifications)
        store.configure(direction: direction, todo: nil, mode: .twentyFiveFive)
        store.start(direction: direction, todo: nil, modelContext: context, now: start)
        store.startBreak(modelContext: context, now: breakStart)

        #expect(notifications.breakFinishedDates.last == breakStart.addingTimeInterval(5 * 60))
        #expect(notifications.runningTooLong.last?.phase == .breakTime)
        #expect(notifications.runningTooLong.last?.fireDate == breakStart.addingTimeInterval(60 * 60))

        let focusScheduleCount = notifications.focusFinishedDates.count
        store.pause(modelContext: context, now: breakStart.addingTimeInterval(60))
        store.resume(modelContext: context, now: breakStart.addingTimeInterval(3 * 60))

        #expect(notifications.focusFinishedDates.count == focusScheduleCount)
        #expect(notifications.breakFinishedDates.last == breakStart.addingTimeInterval(7 * 60))
        #expect(notifications.runningTooLong.last?.phase == .breakTime)
        #expect(notifications.runningTooLong.last?.fireDate == breakStart.addingTimeInterval(62 * 60))
    }

    @Test @MainActor func activeFlowPublishesLiveActivityContextAndPauseState() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 30_000)
        let direction = Direction(
            name: "開発",
            type: .neutral,
            symbolName: "💻",
            colorHex: "#34C759"
        )
        let todo = Todo(title: "Live Activity", direction: direction)
        let liveActivities = TestLiveActivityService()
        context.insert(direction)
        context.insert(todo)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(
            defaults: defaults,
            notifications: TestFlowNotificationService(),
            liveActivities: liveActivities
        )
        store.configure(direction: direction, todo: todo, mode: .twentyFiveFive)
        store.start(direction: direction, todo: todo, modelContext: context, now: start)

        let started = try #require(liveActivities.started.last)
        #expect(started.taskEmoji == "💻")
        #expect(started.taskTitle == "Live Activity")
        #expect(started.directionName == "開発")
        #expect(started.directionColorHex == "#34C759")
        #expect(started.modeName == "Focus")
        #expect(started.status == .focus)
        #expect(started.remainingSeconds == 25 * 60)
        #expect(started.progress == 0)

        store.pause(modelContext: context, now: start.addingTimeInterval(5 * 60))

        let paused = try #require(liveActivities.updated.last)
        #expect(paused.status == .paused)
        #expect(paused.timerKind == .focus)
        #expect(paused.remainingSeconds == 20 * 60)
        #expect(abs(paused.progress - 0.2) < 0.000_001)

        store.destroy(modelContext: context, now: start.addingTimeInterval(5 * 60))
        #expect(liveActivities.endCount == 1)
    }

    @Test @MainActor func breakPublishesCountdownLiveActivityState() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 40_000)
        let breakStartedAt = start.addingTimeInterval(25 * 60)
        let direction = Direction(name: "読書", type: .habit, symbolName: "📚")
        let liveActivities = TestLiveActivityService()
        context.insert(direction)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(
            defaults: defaults,
            notifications: TestFlowNotificationService(),
            liveActivities: liveActivities
        )
        store.configure(direction: direction, todo: nil, mode: .twentyFiveFive)
        store.start(direction: direction, todo: nil, modelContext: context, now: start)
        store.startBreak(modelContext: context, now: breakStartedAt)

        let resting = try #require(liveActivities.updated.last)
        #expect(resting.status == .breakTime)
        #expect(resting.timerKind == .breakTime)
        #expect(resting.taskTitle == "読書")
        #expect(resting.remainingSeconds == 5 * 60)
        #expect(resting.progress == 1)
        #expect(resting.plannedEndAt == breakStartedAt.addingTimeInterval(5 * 60))

        store.skipBreak(modelContext: context, now: breakStartedAt.addingTimeInterval(60))
        #expect(liveActivities.endCount >= 1)
    }

    @Test func persistedPausedFlowReconstructsExactTimerState() throws {
        let start = Date(timeIntervalSince1970: 50_000)
        let pausedAt = start.addingTimeInterval(8 * 60)
        let direction = Direction(name: "開発", type: .neutral)
        let session = FlowSession(
            direction: direction,
            mode: .twentyFiveFive,
            phase: .paused,
            status: .paused,
            startedAt: start,
            plannedEndAt: start.addingTimeInterval(25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60,
            pausedAt: pausedAt,
            phaseBeforePause: .focusing,
            wasPaused: true,
            updatedAt: pausedAt
        )

        let state = try #require(session.reconstructableTimerState)

        #expect(state.phase == .paused)
        #expect(state.pausedAt == pausedAt)
        #expect(state.phaseBeforePause == .focusing)
        #expect(state.plannedEndAt == start.addingTimeInterval(25 * 60))
        #expect(FlowTimerEngine().remainingSeconds(
            for: state,
            now: pausedAt.addingTimeInterval(10 * 60)
        ) == 17 * 60)
    }

    @Test @MainActor func activeFlowStoreAdoptsPersistedRuntimeFromAnotherClient() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 60_000)
        let direction = Direction(name: "開発", type: .neutral, symbolName: "💻")
        let todo = Todo(title: "同期", direction: direction)
        let session = FlowSession(
            direction: direction,
            todo: todo,
            mode: .twentyFiveFive,
            startedAt: start,
            plannedEndAt: start.addingTimeInterval(25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60,
            createdAt: start,
            updatedAt: start
        )
        context.insert(direction)
        context.insert(todo)
        context.insert(session)
        try context.save()

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let liveActivities = TestLiveActivityService()
        let store = ActiveFlowStore(
            defaults: defaults,
            notifications: TestFlowNotificationService(),
            liveActivities: liveActivities
        )

        store.synchronizeFromPersistence(
            modelContext: context,
            now: start.addingTimeInterval(4 * 60)
        )

        #expect(store.activeSession?.id == session.id)
        #expect(store.timerState?.startedAt == start)
        #expect(store.selectedDirectionID == direction.id)
        #expect(store.selectedTodoID == todo.id)
        #expect(store.selectedMode == .twentyFiveFive)
        #expect(liveActivities.updated.last?.taskTitle == "同期")
    }

    @Test @MainActor func activeFlowStoreAppliesNewerRemotePauseRevision() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 70_000)
        let pausedAt = start.addingTimeInterval(6 * 60)
        let direction = Direction(name: "開発", type: .neutral)
        let session = FlowSession(
            direction: direction,
            mode: .twentyFiveFive,
            startedAt: start,
            plannedEndAt: start.addingTimeInterval(25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60,
            createdAt: start,
            updatedAt: start
        )
        context.insert(direction)
        context.insert(session)
        try context.save()

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(
            defaults: defaults,
            notifications: TestFlowNotificationService()
        )
        store.synchronizeFromPersistence(modelContext: context, now: start)

        let pausedState = FlowTimerEngine().pause(
            try #require(session.reconstructableTimerState),
            now: pausedAt
        )
        session.apply(timerState: pausedState, now: pausedAt)
        try context.save()

        store.synchronizeFromPersistence(modelContext: context, now: pausedAt)

        #expect(store.phase == .paused)
        #expect(store.timerState?.pausedAt == pausedAt)
        #expect(store.timerState?.phaseBeforePause == .focusing)
    }

    @Test @MainActor func activeFlowStoreClearsRuntimeAfterRemoteCompletion() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 75_000)
        let completedAt = start.addingTimeInterval(12 * 60)
        let direction = Direction(name: "開発", type: .neutral)
        let session = FlowSession(
            direction: direction,
            mode: .sprint,
            startedAt: start,
            plannedEndAt: completedAt,
            plannedFocusDurationSeconds: 12 * 60,
            plannedBreakDurationSeconds: 3 * 60,
            createdAt: start,
            updatedAt: start
        )
        context.insert(direction)
        context.insert(session)
        try context.save()

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let liveActivities = TestLiveActivityService()
        let store = ActiveFlowStore(
            defaults: defaults,
            notifications: TestFlowNotificationService(),
            liveActivities: liveActivities
        )
        store.synchronizeFromPersistence(modelContext: context, now: start)
        #expect(store.activeSession?.id == session.id)

        session.complete(now: completedAt)
        try context.save()
        store.synchronizeFromPersistence(modelContext: context, now: completedAt)

        #expect(store.activeSession == nil)
        #expect(store.timerState == nil)
        #expect(liveActivities.endCount == 1)
    }

    @Test @MainActor func syncCoordinatorInterruptsOlderConcurrentActiveFlow() throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 80_000)
        let conflictTime = start.addingTimeInterval(60)
        let direction = Direction(name: "開発", type: .neutral)
        let older = FlowSession(
            direction: direction,
            mode: .sprint,
            startedAt: start,
            plannedEndAt: start.addingTimeInterval(12 * 60),
            plannedFocusDurationSeconds: 12 * 60,
            plannedBreakDurationSeconds: 3 * 60,
            runtimeRevision: 1,
            createdAt: start,
            updatedAt: start
        )
        let newer = FlowSession(
            direction: direction,
            mode: .fiftyTen,
            startedAt: conflictTime,
            plannedEndAt: conflictTime.addingTimeInterval(50 * 60),
            plannedFocusDurationSeconds: 50 * 60,
            plannedBreakDurationSeconds: 10 * 60,
            runtimeRevision: 2,
            createdAt: conflictTime,
            updatedAt: conflictTime
        )
        context.insert(direction)
        context.insert(older)
        context.insert(newer)
        try context.save()

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(
            defaults: defaults,
            notifications: TestFlowNotificationService()
        )
        let resolvedAt = conflictTime.addingTimeInterval(5)

        store.synchronizeFromPersistence(modelContext: context, now: resolvedAt)

        #expect(store.activeSession?.id == newer.id)
        #expect(store.selectedMode == .fiftyTen)
        #expect(older.status == .interrupted)
        #expect(older.phase == .completed)
        #expect(older.endedAt == conflictTime)
        #expect(older.updatedAt == resolvedAt)
    }

    @Test func liveActivityTimeFormatterClampsOvertime() {
        #expect(FlowLiveActivityFormatter.timeText(seconds: 65) == "01:05")
        #expect(FlowLiveActivityFormatter.timeText(seconds: -1) == "00:00")
    }
}

private final class TestFlowNotificationService: FlowNotificationService {
    private(set) var focusFinishedDates: [Date] = []
    private(set) var breakFinishedDates: [Date] = []
    private(set) var runningTooLong: [(phase: FlowNotificationPhase, fireDate: Date)] = []

    func requestAuthorizationIfNeeded() {}
    func scheduleFocusFinished(mode: FlowMode, focusedSeconds: Int, fireDate: Date) {
        focusFinishedDates.append(fireDate)
    }
    func scheduleBreakFinished(fireDate: Date) {
        breakFinishedDates.append(fireDate)
    }
    func scheduleRunningTooLong(phase: FlowNotificationPhase, fireDate: Date) {
        runningTooLong.append((phase, fireDate))
    }
    func cancelPendingFlowNotifications() {}
    func clearBadge() {}
}

@MainActor
private final class TestLiveActivityService: LiveActivityService {
    private(set) var started: [FlowLiveActivityContent] = []
    private(set) var updated: [FlowLiveActivityContent] = []
    private(set) var endCount = 0

    func start(content: FlowLiveActivityContent) {
        started.append(content)
    }

    func update(content: FlowLiveActivityContent) {
        updated.append(content)
    }

    func end() {
        endCount += 1
    }
}
