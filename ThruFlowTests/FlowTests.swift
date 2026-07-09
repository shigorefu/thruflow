//
//  FlowTests.swift
//  ThruFlowTests
//
//  Created by Codex on 2026/07/08.
//

import Foundation
import Testing
@testable import ThruFlow

struct FlowTests {
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

    @Test func seekForwardStepsThroughTwelveTwentyFiveFiftyThenAddsWholeBlocks() {
        let engine = FlowTimerEngine()
        let start = Date(timeIntervalSince1970: 4_000)

        let twelve = engine.start(mode: .twelveThree, now: start)
        let twentyFive = engine.seekForward(twelve, now: start)
        let fifty = engine.seekForward(twentyFive, now: start)
        let seventyFive = engine.seekForward(fifty, now: start)

        #expect(twentyFive.plannedFocusDurationSeconds == 25 * 60)
        #expect(twentyFive.plannedBreakDurationSeconds == 5 * 60)
        #expect(fifty.plannedFocusDurationSeconds == 50 * 60)
        #expect(fifty.plannedBreakDurationSeconds == 10 * 60)
        #expect(seventyFive.plannedFocusDurationSeconds == 75 * 60)
        #expect(seventyFive.plannedEndAt == fifty.plannedEndAt.addingTimeInterval(25 * 60))
    }

    @Test func seekBackwardStepsDownAndStopsAtSmallestBlock() {
        let engine = FlowTimerEngine()
        let start = Date(timeIntervalSince1970: 5_000)

        let fifty = engine.start(mode: .fiftyTen, now: start)
        let twentyFive = engine.seekBackward(fifty, now: start)
        let twelve = engine.seekBackward(twentyFive, now: start)
        let stillTwelve = engine.seekBackward(twelve, now: start)

        #expect(twentyFive.plannedFocusDurationSeconds == 25 * 60)
        #expect(twelve.plannedFocusDurationSeconds == 12 * 60)
        #expect(stillTwelve.plannedFocusDurationSeconds == 12 * 60)
        #expect(stillTwelve.plannedEndAt == twelve.plannedEndAt)
    }

    @Test func seekIsIgnoredOutsideFocusingOrPausedPhases() {
        let engine = FlowTimerEngine()
        let start = Date(timeIntervalSince1970: 6_000)

        let initial = engine.start(mode: .twentyFiveFive, now: start)
        let inBreak = engine.startBreak(initial, now: start.addingTimeInterval(26 * 60))
        let unchanged = engine.seekForward(inBreak, now: start.addingTimeInterval(26 * 60))

        #expect(inBreak.phase == .breakTime)
        #expect(unchanged == inBreak)
    }
}
