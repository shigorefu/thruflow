//
//  FlowTests.swift
//  ThruFlowTests
//
//

import CoreData
import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import ThruFlow

struct FlowTests {
    @Test @MainActor func timerPrimaryControlUsesSemanticPhaseColors() {
        #expect(FlowTimerPrimaryTintRole(phase: .focusing, isFocusOvertime: false) == .area)
        #expect(FlowTimerPrimaryTintRole(phase: .focusing, isFocusOvertime: true) == .area)
        #expect(FlowTimerPrimaryTintRole(phase: .paused, isFocusOvertime: false) == .paused)
        #expect(FlowTimerPrimaryTintRole(phase: .breakTime, isFocusOvertime: false) == .breakTime)
    }

    @Test @MainActor func sprintUsesNewRawValueAndReadsLegacyPersistenceValue() throws {
        #expect(FlowMode.sprint.rawValue == "sprint")
        #expect(FlowMode.persistedMode(rawValue: "sprint") == .sprint)
        #expect(FlowMode.persistedMode(rawValue: "twelveThree") == .sprint)

        let legacyData = Data("\"twelveThree\"".utf8)
        #expect(try JSONDecoder().decode(FlowMode.self, from: legacyData) == .sprint)
        #expect(String(decoding: try JSONEncoder().encode(FlowMode.sprint), as: UTF8.self) == "\"sprint\"")
    }

    @Test func blockDisplayUsesProductValues() {
        #expect(BlockUnit.displayText(forFocusedSeconds: 11 * 60) == String(localized: "0 Block"))
        #expect(BlockUnit.displayText(forFocusedSeconds: 12 * 60) == String(localized: "0.5 Block"))
        #expect(BlockUnit.displayText(forFocusedSeconds: 24 * 60) == String(localized: "1 Block"))
        #expect(BlockUnit.displayText(forFocusedSeconds: 25 * 60) == String(localized: "1 Block"))
        #expect(
            BlockUnit.displayText(forFocusedSeconds: 37 * 60) ==
                String(localized: "\(1.5, format: .number.precision(.fractionLength(0...1))) Blocks")
        )
        #expect(BlockUnit.displayText(forFocusedSeconds: 50 * 60) == String(localized: "\(2) Blocks"))
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

    @Test func focusProgressStaysAttachedToItsAreaAndTodo() {
        let reading = Area(
            name: "読書",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .daily,
            goalUnit: .focusBlocks,
            goalSchedule: .everyDay
        )
        let anki = Area(
            name: "Anki",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .daily,
            goalUnit: .focusBlocks,
            goalSchedule: .everyDay
        )
        let readingTodo = Todo(title: "第8章", area: reading, measurement: .focusBlocks, plannedAmount: 1)
        let ankiTodo = Todo(title: "復習", area: anki, measurement: .focusBlocks, plannedAmount: 1)
        let calculator = FlowProgressCalculator()

        calculator.applyFocusDuration(seconds: 12 * 60, area: reading, todo: readingTodo)
        calculator.applyFocusDuration(seconds: 13 * 60, area: anki, todo: ankiTodo)

        #expect(reading.recordedFocusSeconds == 12 * 60)
        #expect(anki.recordedFocusSeconds == 13 * 60)
        #expect(readingTodo.recordedFocusSeconds == 12 * 60)
        #expect(ankiTodo.recordedFocusSeconds == 13 * 60)
        #expect(readingTodo.actualProgress == 0)
        #expect(ankiTodo.actualProgress == 0)
    }

    @Test func todoReceivesFullBlockAfterAccumulatedFocusMinutesReachTwentyFive() {
        let area = Area(
            name: "仕事",
            type: .neutral,
            goalTarget: 2,
            goalPeriod: .daily,
            goalUnit: .focusBlocks,
            goalSchedule: .everyDay
        )
        let todo = Todo(title: "資料", area: area, measurement: .focusBlocks, plannedAmount: 2)
        let calculator = FlowProgressCalculator()

        calculator.applyFocusDuration(seconds: 12 * 60, area: area, todo: todo)
        calculator.applyFocusDuration(seconds: 13 * 60, area: area, todo: todo)

        #expect(todo.recordedFocusSeconds == 25 * 60)
        #expect(todo.actualProgress == 1)
        #expect(area.recordedFocusSeconds == 25 * 60)
    }

    @Test func twoHalfBlocksCompleteOneBlockTodo() {
        let area = Area(name: "読書", type: .habit)
        let todo = Todo(title: "タスク", area: area, measurement: .focusBlocks, plannedAmount: 2)
        let calculator = FlowProgressCalculator()

        calculator.applyFocusDuration(seconds: 12 * 60, area: area, todo: todo)
        calculator.applyFocusDuration(seconds: 12 * 60, area: area, todo: todo)

        #expect(todo.recordedFocusSeconds == 24 * 60)
        #expect(todo.actualProgress == 1)
        #expect(todo.status == .active)
        let expectedProgress = "\(String(localized: "1 Block")) / \(String(localized: "\(2) Blocks"))"
        #expect(TodoProgressCalculator().summary(
            measurement: todo.measurement,
            plannedAmount: todo.plannedAmount,
            actualProgress: todo.actualProgress,
            focusDurationSeconds: todo.focusDurationSeconds
        ) == expectedProgress)
    }

    @Test func manualBlockTodoProgressUsesTodoMeasurementWithoutAreaGoal() {
        let area = Area(name: "仕事", type: .neutral)
        let todo = Todo(title: "実装", area: area, measurement: .focusBlocks, plannedAmount: 2)
        let calculator = FlowProgressCalculator()

        calculator.applyFocusDuration(seconds: 25 * 60, area: area, todo: todo)

        #expect(area.recordedFocusSeconds == 25 * 60)
        #expect(todo.recordedFocusSeconds == 25 * 60)
        #expect(todo.actualProgress == 1)
        #expect(todo.status == .active)
    }

    @Test func occurrenceAreaDoesNotWriteFlowProgressToTodo() {
        let area = Area(
            name: "筋トレ",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .daily,
            goalUnit: .occurrences,
            goalSchedule: .everyDay
        )
        let todo = Todo(title: "筋トレ", area: area, measurement: .checkbox)
        let calculator = FlowProgressCalculator()

        calculator.applyFocusDuration(seconds: 25 * 60, area: area, todo: todo)

        #expect(area.recordedFocusSeconds == 25 * 60)
        #expect(todo.recordedFocusSeconds == 0)
        #expect(todo.actualProgress == 0)
    }

    @Test func minuteAreaWritesFocusedMinutesToTodo() {
        let area = Area(
            name: "日本語",
            type: .habit,
            goalTarget: 30,
            goalPeriod: .daily,
            goalUnit: .minutes,
            goalSchedule: .everyDay
        )
        let todo = Todo(title: "日本語", area: area, measurement: .minutes, plannedAmount: 30)
        let calculator = FlowProgressCalculator()

        calculator.applyFocusDuration(seconds: 12 * 60, area: area, todo: todo)

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
        let writing = Area(name: "執筆", type: .neutral)
        let review = Area(name: "レビュー", type: .neutral)
        let writingTodo = Todo(title: "本文", area: writing, measurement: .minutes, plannedAmount: 30)
        let reviewTodo = Todo(title: "確認", area: review, measurement: .minutes, plannedAmount: 20)
        let session = FlowSession(
            area: review,
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
            area: writing,
            todo: writingTodo,
            startedAt: start,
            startFocusSeconds: 0
        )
        first.close(at: start.addingTimeInterval(16 * 60), totalFocusSeconds: 16 * 60)
        let second = FlowSegment(
            session: session,
            area: review,
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
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 8_000)
        let firstArea = Area(name: "執筆", type: .neutral)
        let secondArea = Area(name: "確認", type: .neutral)
        let firstTodo = Todo(title: "本文", area: firstArea, measurement: .minutes, plannedAmount: 30)
        let secondTodo = Todo(title: "レビュー", area: secondArea, measurement: .minutes, plannedAmount: 20)
        context.insert(firstArea)
        context.insert(secondArea)
        context.insert(firstTodo)
        context.insert(secondTodo)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(area: firstArea, todo: firstTodo, mode: .twentyFiveFive)
        store.start(area: firstArea, todo: firstTodo, modelContext: context, now: start)
        store.selectContext(
            area: secondArea,
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
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 8_250)
        let firstArea = Area(name: "AWS", type: .neutral)
        let secondArea = Area(name: "読書", type: .neutral)
        let firstTodo = Todo(title: "AWS", area: firstArea, measurement: .minutes, plannedAmount: 30)
        let secondTodo = Todo(title: "本を読む", area: secondArea, measurement: .minutes, plannedAmount: 20)
        context.insert(firstArea)
        context.insert(secondArea)
        context.insert(firstTodo)
        context.insert(secondTodo)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(area: firstArea, todo: firstTodo, mode: .twentyFiveFive)
        store.start(area: firstArea, todo: firstTodo, modelContext: context, now: start)
        let sessionID = try #require(store.activeSession?.id)

        store.selectContext(
            area: secondArea,
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
        #expect(activeSegment.area?.id == secondArea.id)

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
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 8_400)
        let firstArea = Area(name: "AWS", type: .neutral)
        let secondArea = Area(name: "読書", type: .neutral)
        let firstTodo = Todo(title: "AWS", area: firstArea, measurement: .minutes, plannedAmount: 30)
        let secondTodo = Todo(title: "本を読む", area: secondArea, measurement: .minutes, plannedAmount: 20)
        context.insert(firstArea)
        context.insert(secondArea)
        context.insert(firstTodo)
        context.insert(secondTodo)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(area: firstArea, todo: firstTodo, mode: .twentyFiveFive)
        store.start(area: firstArea, todo: firstTodo, modelContext: context, now: start)
        let sessionID = try #require(store.activeSession?.id)

        store.selectContext(
            area: secondArea,
            todo: secondTodo,
            modelContext: context,
            now: start.addingTimeInterval(2 * 60)
        )
        store.selectContext(
            area: firstArea,
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
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 8_500)
        let area = Area(name: "執筆", type: .neutral)
        let todo = Todo(title: "本文", area: area, measurement: .minutes, plannedAmount: 30)
        context.insert(area)
        context.insert(todo)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(area: area, todo: todo, mode: .twentyFiveFive)
        store.start(area: area, todo: todo, modelContext: context, now: start)
        store.stop(modelContext: context, now: start.addingTimeInterval(10 * 60))

        #expect(store.phase == .awaitingResult)
        #expect(todo.recordedFocusSeconds == 10 * 60)
        #expect(store.activeSession?.resolvedSegments.first?.endedAt != nil)

        store.cancelResultMemo(modelContext: context, now: start.addingTimeInterval(10 * 60 + 10))

        #expect(store.phase == .focusing)
        #expect(store.activeSession?.status == .active)
        #expect(store.activeSession?.resolvedSegments.first?.endedAt == nil)
        #expect(todo.recordedFocusSeconds == 0)
        #expect(area.recordedFocusSeconds == 0)
    }

    @Test @MainActor func completingWithoutMemoPreservesExistingTaskMemo() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 8_750)
        let area = Area(name: "執筆", type: .neutral)
        let todo = Todo(
            title: "本文",
            notes: "既存のメモ",
            area: area,
            measurement: .minutes,
            plannedAmount: 30
        )
        context.insert(area)
        context.insert(todo)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(area: area, todo: todo, mode: .twentyFiveFive)
        store.start(area: area, todo: todo, modelContext: context, now: start)
        store.stop(modelContext: context, now: start.addingTimeInterval(10 * 60))
        let session = try #require(store.activeSession)

        store.completeResult(nil, modelContext: context, now: start.addingTimeInterval(10 * 60 + 1))

        #expect(todo.notes == "既存のメモ")
        #expect(session.result == nil)
        #expect(session.status == .completed)
    }

    @Test @MainActor func startingBreakWithoutMemoPreservesExistingTaskMemo() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 8_900)
        let area = Area(name: "執筆", type: .neutral)
        let todo = Todo(
            title: "本文",
            notes: "既存のメモ",
            area: area,
            measurement: .minutes,
            plannedAmount: 30
        )
        context.insert(area)
        context.insert(todo)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(area: area, todo: todo, mode: .twentyFiveFive)
        store.start(area: area, todo: todo, modelContext: context, now: start)
        store.requestBreakMemo(modelContext: context, now: start.addingTimeInterval(25 * 60))
        let session = try #require(store.activeSession)

        store.completeBreakMemo(nil, modelContext: context, now: start.addingTimeInterval(25 * 60 + 1))

        #expect(todo.notes == "既存のメモ")
        #expect(session.result == nil)
        #expect(store.phase == .breakTime)
    }

    @Test @MainActor func everyEligibleRestPressPublishesANewVisualInteraction() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 8_950)
        let area = Area(name: "執筆", type: .neutral)
        context.insert(area)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())

        store.requestBreakMemo(modelContext: context, now: start)
        #expect(store.flowBreakInteraction == nil)
        #expect(!store.canRequestBreak)

        store.configure(area: area, todo: nil, mode: .twentyFiveFive)
        store.start(area: area, todo: nil, modelContext: context, now: start)
        #expect(store.canRequestBreak)

        let firstRequestAt = start.addingTimeInterval(5 * 60)
        store.requestBreakMemo(modelContext: context, now: firstRequestAt)
        let firstRequest = try #require(store.flowBreakInteraction)
        #expect(firstRequest.sequence == 1)
        #expect(firstRequest.kind == .requested)
        #expect(firstRequest.occurredAt == firstRequestAt)
        #expect(store.phase == .focusing)

        store.cancelBreakMemo()
        #expect(store.flowBreakInteraction == firstRequest)

        let secondRequestAt = firstRequestAt.addingTimeInterval(1)
        store.requestBreakMemo(modelContext: context, now: secondRequestAt)
        let secondRequest = try #require(store.flowBreakInteraction)
        #expect(secondRequest.sequence == 2)
        #expect(secondRequest.kind == .requested)
        #expect(secondRequest.occurredAt == secondRequestAt)

        let breakStartedAt = secondRequestAt.addingTimeInterval(1)
        store.completeBreakMemo(nil, modelContext: context, now: breakStartedAt)
        let breakStarted = try #require(store.flowBreakInteraction)
        #expect(breakStarted.sequence == 3)
        #expect(breakStarted.kind == .started(isLong: false))
        #expect(breakStarted.occurredAt == breakStartedAt)
        #expect(store.flowStreamBreakStyle == .regular)
        #expect(!store.canRequestBreak)

        store.requestBreakMemo(
            modelContext: context,
            now: breakStartedAt.addingTimeInterval(1)
        )
        #expect(store.flowBreakInteraction == breakStarted)
    }

    @Test @MainActor func startingWorkDuringBreakImmediatelyCreatesNextFlow() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 9_000)
        let breakStartedAt = start.addingTimeInterval(25 * 60)
        let restartedAt = breakStartedAt.addingTimeInterval(2 * 60)
        let area = Area(name: "仕事", type: .neutral)
        let todo = Todo(title: "実装", area: area)
        context.insert(area)
        context.insert(todo)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(area: area, todo: todo, mode: .twentyFiveFive)
        store.start(area: area, todo: todo, modelContext: context, now: start)
        let firstSession = try #require(store.activeSession)
        store.startBreak(modelContext: context, now: breakStartedAt)
        #expect(store.flowBreakInteraction?.kind == .started(isLong: false))

        store.startNextFlow(
            area: area,
            todo: todo,
            modelContext: context,
            now: restartedAt
        )

        #expect(firstSession.status == .completed)
        #expect(firstSession.endedAt == restartedAt)
        #expect(store.phase == .focusing)
        #expect(store.flowBreakInteraction == nil)
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
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 10_000)
        let breakStartedAt = start.addingTimeInterval(25 * 60)
        let area = Area(name: "仕事", type: .neutral)
        let todo = Todo(title: "実装", area: area, measurement: .minutes, plannedAmount: 60)
        context.insert(area)
        context.insert(todo)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(area: area, todo: todo, mode: .twentyFiveFive)
        store.start(area: area, todo: todo, modelContext: context, now: start)
        let sessionID = try #require(store.activeSession?.id)
        store.startBreak(modelContext: context, now: breakStartedAt)
        #expect(store.flowBreakInteraction?.kind == .started(isLong: false))

        store.destroy(modelContext: context, now: breakStartedAt.addingTimeInterval(60))

        let sessions = try context.fetch(FetchDescriptor<FlowSession>())
        let flowBreak = try #require(context.fetch(FetchDescriptor<FlowBreak>()).first)
        #expect(sessions.map(\.id) == [sessionID])
        #expect(sessions.first?.status == .completed)
        #expect(flowBreak.deletedAt == breakStartedAt.addingTimeInterval(60))
        #expect(store.flowBreakInteraction == nil)
        #expect(todo.recordedFocusSeconds == 25 * 60)
        #expect(todo.actualProgress == 25)
        #expect(area.recordedFocusSeconds == 25 * 60)
        #expect(store.timerState == nil)
    }

    @Test @MainActor func destroyingCreditedFlowRollsBackTaskAndAreaProgress() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 11_000)
        let area = Area(name: "仕事", type: .neutral)
        let todo = Todo(title: "実装", area: area, measurement: .minutes, plannedAmount: 25)
        context.insert(area)
        context.insert(todo)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(area: area, todo: todo, mode: .twentyFiveFive)
        store.start(area: area, todo: todo, modelContext: context, now: start)
        store.stop(modelContext: context, now: start.addingTimeInterval(25 * 60))
        #expect(todo.isCompleted)

        store.destroy(modelContext: context, now: start.addingTimeInterval(25 * 60 + 1))

        #expect(try context.fetch(FetchDescriptor<FlowSession>()).isEmpty)
        #expect(todo.recordedFocusSeconds == 0)
        #expect(todo.actualProgress == 0)
        #expect(!todo.isCompleted)
        #expect(area.recordedFocusSeconds == 0)
        #expect(store.timerState == nil)
    }

    @Test @MainActor func startingAfterContinuationWindowCreatesNewSeries() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 12_000)
        let breakStartedAt = start.addingTimeInterval(25 * 60)
        let restartedAt = breakStartedAt.addingTimeInterval(7 * 60 + 31)
        let area = Area(name: "仕事", type: .neutral)
        context.insert(area)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(area: area, todo: nil, mode: .twentyFiveFive)
        store.start(area: area, todo: nil, modelContext: context, now: start)
        let firstSeriesID = try #require(store.activeSession?.seriesID)
        store.startBreak(modelContext: context, now: breakStartedAt)
        store.startNextFlow(area: area, todo: nil, modelContext: context, now: restartedAt)

        #expect(store.activeSession?.seriesID != firstSeriesID)
        let flowBreak = try #require(context.fetch(FetchDescriptor<FlowBreak>()).first)
        #expect(flowBreak.nextSessionID == nil)
    }

    @Test @MainActor func fourthAccumulatedBlockStartsLongBreak() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 20_000)
        let area = Area(name: "仕事", type: .neutral)
        context.insert(area)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(area: area, todo: nil, mode: .twentyFiveFive)
        store.start(area: area, todo: nil, modelContext: context, now: start)
        let seriesID = try #require(store.activeSession?.seriesID)
        let prior = FlowSession(
            seriesID: seriesID,
            area: area,
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
        #expect(store.flowBreakInteraction?.kind == .started(isLong: true))
        #expect(store.flowStreamBreakStyle == .long)
        let flowBreak = try #require(context.fetch(FetchDescriptor<FlowBreak>()).first)
        #expect(flowBreak.isLongBreak)
        #expect(flowBreak.continuationDeadline == start.addingTimeInterval(25 * 60 + 30 * 60))
    }

    @Test @MainActor func flowNotificationsWarnAfterOneActiveHourAndAccountForPause() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 25_000)
        let area = Area(name: "仕事", type: .neutral)
        let notifications = TestFlowNotificationService()
        context.insert(area)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: notifications)
        store.configure(area: area, todo: nil, mode: .twentyFiveFive)
        store.start(area: area, todo: nil, modelContext: context, now: start)

        #expect(notifications.focusFinishedDates.last == start.addingTimeInterval(25 * 60))
        #expect(notifications.runningTooLong.last?.phase == .focus)
        #expect(notifications.runningTooLong.last?.fireDate == start.addingTimeInterval(60 * 60))

        store.pause(modelContext: context, now: start.addingTimeInterval(10 * 60))
        store.resume(modelContext: context, now: start.addingTimeInterval(20 * 60))

        #expect(notifications.focusFinishedDates.last == start.addingTimeInterval(35 * 60))
        #expect(notifications.runningTooLong.last?.phase == .focus)
        #expect(notifications.runningTooLong.last?.fireDate == start.addingTimeInterval(70 * 60))
    }

    @Test func staleNotificationRegistrationCannotSurviveCancellation() throws {
        let suiteName = "FlowNotificationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let center = TestFlowUserNotificationCenter()
        let service = LocalFlowNotificationService(center: center, defaults: defaults)

        service.scheduleRunningTooLong(
            phase: .focus,
            fireDate: Date.now.addingTimeInterval(60 * 60)
        )
        let staleIdentifier = try #require(center.requestedIdentifiers.last)

        service.cancelPendingFlowNotifications()
        service.scheduleRunningTooLong(
            phase: .focus,
            fireDate: Date.now.addingTimeInterval(60 * 60)
        )
        let currentIdentifier = try #require(center.requestedIdentifiers.last)

        #expect(staleIdentifier != currentIdentifier)
        center.completeAdd(for: staleIdentifier)
        #expect(!center.pendingIdentifiers.contains(staleIdentifier))
        #expect(center.pendingIdentifiers.contains(currentIdentifier))
        #expect(!center.removedPendingBatches.contains([currentIdentifier]))
    }

    @Test @MainActor func breakNotificationsWarnAfterOneActiveHourAndResumeAsBreak() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 28_000)
        let breakStart = start.addingTimeInterval(25 * 60)
        let area = Area(name: "仕事", type: .neutral)
        let notifications = TestFlowNotificationService()
        context.insert(area)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: notifications)
        store.configure(area: area, todo: nil, mode: .twentyFiveFive)
        store.start(area: area, todo: nil, modelContext: context, now: start)
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

    @Test @MainActor func applicationDataResetClearsAndPersistsTimerConfiguration() {
        let suiteName = "FlowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let area = Area(name: "仕事", type: .neutral)
        let todo = Todo(title: "実装", area: area)
        let notifications = TestFlowNotificationService()
        let liveActivities = TestLiveActivityService()
        let store = ActiveFlowStore(
            defaults: defaults,
            notifications: notifications,
            liveActivities: liveActivities
        )
        store.configure(
            area: area,
            todo: todo,
            intent: "次の作業",
            mode: .fiftyTen
        )

        store.resetAfterApplicationDataReset()

        #expect(store.selectedAreaID == nil)
        #expect(store.selectedTodoID == nil)
        #expect(store.selectedMode == .twentyFiveFive)
        #expect(store.intent.isEmpty)
        #expect(store.phase == .idle)
        #expect(notifications.cancelCount == 1)
        #expect(notifications.clearBadgeCount == 1)
        #expect(liveActivities.endCount == 1)

        let restored = ActiveFlowStore(
            defaults: defaults,
            notifications: TestFlowNotificationService()
        )
        #expect(restored.selectedAreaID == nil)
        #expect(restored.selectedTodoID == nil)
        #expect(restored.selectedMode == .twentyFiveFive)
        #expect(restored.intent.isEmpty)
    }

    @Test @MainActor func idleSelectionMovesFromYesterdayToTodaysTaskInTheSameArea() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let yesterday = Date(timeIntervalSince1970: 1_800_000_000)
        let today = calendar.date(byAdding: .day, value: 1, to: yesterday)!
        let area = Area(name: "筋トレ", type: .habit)
        let oldTodo = Todo(title: "筋トレ B", area: area, scheduledDate: yesterday)
        let currentTodo = Todo(title: "筋トレ C", area: area, scheduledDate: today)
        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(area: area, todo: oldTodo)

        let changed = store.reconcileSelectedTodoForCurrentDay(
            todos: [oldTodo, currentTodo],
            areas: [area],
            now: today,
            calendar: calendar
        )

        #expect(changed)
        #expect(store.selectedAreaID == area.id)
        #expect(store.selectedTodoID == currentTodo.id)
    }

    @Test @MainActor func idleSelectionClearsYesterdayTaskWhenTodayHasNoTasks() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let yesterday = Date(timeIntervalSince1970: 1_800_000_000)
        let today = calendar.date(byAdding: .day, value: 1, to: yesterday)!
        let area = Area(name: "開発", type: .neutral)
        let oldTodo = Todo(title: "昨日の作業", area: area, scheduledDate: yesterday)
        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(area: area, todo: oldTodo)

        let changed = store.reconcileSelectedTodoForCurrentDay(
            todos: [oldTodo],
            areas: [area],
            now: today,
            calendar: calendar
        )

        #expect(changed)
        #expect(store.selectedAreaID == area.id)
        #expect(store.selectedTodoID == nil)
    }

    @Test @MainActor func runningFlowKeepsItsTaskAcrossTheDayBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let yesterday = Date(timeIntervalSince1970: 1_800_000_000)
        let today = calendar.date(byAdding: .day, value: 1, to: yesterday)!
        let area = Area(name: "夜間作業", type: .neutral)
        let oldTodo = Todo(title: "継続中", area: area, scheduledDate: yesterday)
        let currentTodo = Todo(title: "今日の作業", area: area, scheduledDate: today)
        context.insert(area)
        context.insert(oldTodo)
        context.insert(currentTodo)
        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(defaults: defaults, notifications: TestFlowNotificationService())
        store.configure(area: area, todo: oldTodo)
        store.start(area: area, todo: oldTodo, modelContext: context, now: yesterday)

        let changed = store.reconcileSelectedTodoForCurrentDay(
            todos: [oldTodo, currentTodo],
            areas: [area],
            now: today,
            calendar: calendar
        )

        #expect(!changed)
        #expect(store.selectedTodoID == oldTodo.id)
        #expect(store.activeSession?.todo?.id == oldTodo.id)
    }

    @Test @MainActor func activeFlowPublishesLiveActivityContextAndPauseState() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 30_000)
        let area = Area(
            name: "開発",
            type: .neutral,
            symbolName: "💻",
            colorHex: "#34C759"
        )
        let todo = Todo(title: "Live Activity", area: area)
        let liveActivities = TestLiveActivityService()
        context.insert(area)
        context.insert(todo)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(
            defaults: defaults,
            notifications: TestFlowNotificationService(),
            liveActivities: liveActivities
        )
        store.configure(area: area, todo: todo, mode: .twentyFiveFive)
        store.start(area: area, todo: todo, modelContext: context, now: start)

        let started = try #require(liveActivities.started.last)
        #expect(started.taskEmoji == "💻")
        #expect(started.taskTitle == "Live Activity")
        #expect(started.areaName == "開発")
        #expect(started.areaColorHex == "#34C759")
        #expect(started.modeName == FlowMode.twentyFiveFive.displayName)
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
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 40_000)
        let breakStartedAt = start.addingTimeInterval(25 * 60)
        let area = Area(name: "読書", type: .habit, symbolName: "📚")
        let liveActivities = TestLiveActivityService()
        context.insert(area)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(
            defaults: defaults,
            notifications: TestFlowNotificationService(),
            liveActivities: liveActivities
        )
        store.configure(area: area, todo: nil, mode: .twentyFiveFive)
        store.start(area: area, todo: nil, modelContext: context, now: start)
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

    @Test @MainActor func activeFlowPublishesLiveActivityOvertimeBoundaryOnce() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 45_000)
        let area = Area(name: "開発", type: .neutral, symbolName: "💻")
        let liveActivities = TestLiveActivityService()
        context.insert(area)

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let store = ActiveFlowStore(
            defaults: defaults,
            notifications: TestFlowNotificationService(),
            liveActivities: liveActivities
        )
        store.configure(area: area, todo: nil, mode: .sprint)
        store.start(area: area, todo: nil, modelContext: context, now: start)

        let plannedEndAt = start.addingTimeInterval(12 * 60)
        store.refreshLiveActivityTimeBoundary(now: plannedEndAt)
        #expect(liveActivities.updated.isEmpty)

        store.refreshLiveActivityTimeBoundary(now: plannedEndAt.addingTimeInterval(1))
        let overtime = try #require(liveActivities.updated.last)
        #expect(overtime.remainingSeconds == -1)

        store.refreshLiveActivityTimeBoundary(now: plannedEndAt.addingTimeInterval(2))
        #expect(liveActivities.updated.count == 1)
    }

    @Test func persistedPausedFlowReconstructsExactTimerState() throws {
        let start = Date(timeIntervalSince1970: 50_000)
        let pausedAt = start.addingTimeInterval(8 * 60)
        let area = Area(name: "開発", type: .neutral)
        let session = FlowSession(
            area: area,
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
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 60_000)
        let area = Area(name: "開発", type: .neutral, symbolName: "💻")
        let todo = Todo(title: "同期", area: area)
        let session = FlowSession(
            area: area,
            todo: todo,
            mode: .twentyFiveFive,
            startedAt: start,
            plannedEndAt: start.addingTimeInterval(25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60,
            createdAt: start,
            updatedAt: start
        )
        context.insert(area)
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
        #expect(store.selectedAreaID == area.id)
        #expect(store.selectedTodoID == todo.id)
        #expect(store.selectedMode == .twentyFiveFive)
        #expect(liveActivities.updated.last?.taskTitle == "同期")
    }

    @Test @MainActor func activeFlowStoreAppliesNewerRemotePauseRevision() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 70_000)
        let pausedAt = start.addingTimeInterval(6 * 60)
        let area = Area(name: "開発", type: .neutral)
        let session = FlowSession(
            area: area,
            mode: .twentyFiveFive,
            startedAt: start,
            plannedEndAt: start.addingTimeInterval(25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60,
            createdAt: start,
            updatedAt: start
        )
        context.insert(area)
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
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 75_000)
        let completedAt = start.addingTimeInterval(12 * 60)
        let area = Area(name: "開発", type: .neutral)
        let session = FlowSession(
            area: area,
            mode: .sprint,
            startedAt: start,
            plannedEndAt: completedAt,
            plannedFocusDurationSeconds: 12 * 60,
            plannedBreakDurationSeconds: 3 * 60,
            createdAt: start,
            updatedAt: start
        )
        context.insert(area)
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

    @Test @MainActor func remotePersistenceChangeCancelsNotificationsWhilePollingIsStopped() async throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 77_000)
        let completedAt = start.addingTimeInterval(6 * 60)
        let area = Area(name: "開発", type: .neutral)
        let session = FlowSession(
            area: area,
            mode: .sprint,
            startedAt: start,
            plannedEndAt: start.addingTimeInterval(12 * 60),
            plannedFocusDurationSeconds: 12 * 60,
            plannedBreakDurationSeconds: 3 * 60,
            createdAt: start,
            updatedAt: start
        )
        context.insert(area)
        context.insert(session)
        try context.save()

        let defaults = UserDefaults(suiteName: "FlowTests.\(UUID().uuidString)")!
        let notifications = TestFlowNotificationService()
        let persistenceNotificationCenter = NotificationCenter()
        let store = ActiveFlowStore(
            defaults: defaults,
            notifications: notifications,
            persistenceNotificationCenter: persistenceNotificationCenter
        )
        store.beginSynchronization(modelContext: context, now: start)
        store.endSynchronization()
        let cancelCountBeforeRemoteCompletion = notifications.cancelCount

        session.complete(now: completedAt)
        try context.save()
        persistenceNotificationCenter.post(
            name: .NSPersistentStoreRemoteChange,
            object: nil
        )
        try await Task.sleep(for: .milliseconds(50))

        #expect(store.activeSession == nil)
        #expect(store.timerState == nil)
        #expect(notifications.cancelCount == cancelCountBeforeRemoteCompletion + 1)
    }

    @Test @MainActor func syncCoordinatorInterruptsOlderConcurrentActiveFlow() throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 80_000)
        let conflictTime = start.addingTimeInterval(60)
        let area = Area(name: "開発", type: .neutral)
        let older = FlowSession(
            area: area,
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
            area: area,
            mode: .fiftyTen,
            startedAt: conflictTime,
            plannedEndAt: conflictTime.addingTimeInterval(50 * 60),
            plannedFocusDurationSeconds: 50 * 60,
            plannedBreakDurationSeconds: 10 * 60,
            runtimeRevision: 2,
            createdAt: conflictTime,
            updatedAt: conflictTime
        )
        context.insert(area)
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

    @Test func liveActivityTimeFormatterSupportsOvertime() {
        #expect(FlowLiveActivityFormatter.timeText(seconds: 65) == "01:05")
        #expect(FlowLiveActivityFormatter.timeText(seconds: -1) == "00:00")
        #expect(
            FlowLiveActivityFormatter.timeText(
                seconds: -1,
                allowsOvertime: true
            ) == "+00:01"
        )
    }

}

private final class TestFlowNotificationService: FlowNotificationService {
    private(set) var focusFinishedDates: [Date] = []
    private(set) var breakFinishedDates: [Date] = []
    private(set) var runningTooLong: [(phase: FlowNotificationPhase, fireDate: Date)] = []
    private(set) var cancelCount = 0
    private(set) var clearBadgeCount = 0

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
    func cancelPendingFlowNotifications() {
        cancelCount += 1
    }
    func clearBadge() {
        clearBadgeCount += 1
    }
}

private final class TestFlowUserNotificationCenter: FlowUserNotificationCenter {
    private(set) var requestedIdentifiers: [String] = []
    private(set) var pendingIdentifiers: Set<String> = []
    private(set) var removedPendingBatches: [[String]] = []
    private var addCompletions: [String: (@Sendable (Error?) -> Void)] = [:]

    func requestAuthorization(
        options: UNAuthorizationOptions,
        completionHandler: @escaping @Sendable (Bool, Error?) -> Void
    ) {
        completionHandler(true, nil)
    }

    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?
    ) {
        requestedIdentifiers.append(request.identifier)
        pendingIdentifiers.insert(request.identifier)
        addCompletions[request.identifier] = completionHandler
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedPendingBatches.append(identifiers)
        pendingIdentifiers.subtract(identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {}

    func clearBadge() {}

    func completeAdd(for identifier: String, error: Error? = nil) {
        addCompletions.removeValue(forKey: identifier)?(error)
    }
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
