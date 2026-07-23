//
//  FlowTimerEngine.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import Foundation

struct FlowTimerEngine {
    static let minimumCreditableFocusDurationSeconds = 60
    static let seekStepSeconds = 5 * 60
    static let minimumRemainingFocusSeconds = 60

    func start(mode: FlowMode, now: Date) -> FlowTimerState {
        FlowTimerState(
            mode: mode,
            phase: .focusing,
            startedAt: now,
            plannedEndAt: now.addingTimeInterval(TimeInterval(mode.initialFocusDurationSeconds)),
            plannedFocusDurationSeconds: mode.initialFocusDurationSeconds,
            plannedBreakDurationSeconds: mode.breakDurationSeconds
        )
    }

    func pause(_ state: FlowTimerState, now: Date) -> FlowTimerState {
        guard state.phase == .focusing || state.phase == .breakTime else {
            return state
        }

        var next = state
        next.phaseBeforePause = state.phase
        next.phase = .paused
        next.pausedAt = now
        next.wasPaused = true
        next.interruptionCount += 1
        return next
    }

    func resume(_ state: FlowTimerState, now: Date) -> FlowTimerState {
        guard state.phase == .paused, let pausedAt = state.pausedAt else {
            return state
        }

        let pauseDuration = max(0, Int(now.timeIntervalSince(pausedAt)))
        var next = state
        next.phase = state.phaseBeforePause ?? .focusing
        next.phaseBeforePause = nil
        next.pausedAt = nil
        next.accumulatedPauseDurationSeconds += pauseDuration
        next.plannedEndAt = state.plannedEndAt.addingTimeInterval(TimeInterval(pauseDuration))
        return next
    }

    func finish(_ state: FlowTimerState, now: Date) -> FlowTimerState {
        var next = state
        next.phase = .awaitingResult
        next.endedAt = now
        next.completedAt = now
        next.actualFocusDurationSeconds = creditableFocusDuration(actualFocusDuration(for: state, now: now))
        return next
    }

    func completeResult(_ state: FlowTimerState, now: Date) -> FlowTimerState {
        var next = state
        next.phase = .completed
        next.completedAt = state.completedAt ?? now
        return next
    }

    func advanceIfNeeded(_ state: FlowTimerState, now: Date) -> FlowTimerState {
        guard state.phase == .focusing || state.phase == .breakTime else {
            return state
        }

        guard now >= state.plannedEndAt else {
            return state
        }

        var next = state

        if state.phase == .breakTime {
            return state
        }

        if state.mode == .adaptive {
            next.phase = .awaitingExtensionDecision
            next.actualFocusDurationSeconds = state.plannedFocusDurationSeconds
            return next
        }

        return state
    }

    func startBreak(
        _ state: FlowTimerState,
        now: Date,
        plannedBreakDurationSeconds: Int? = nil
    ) -> FlowTimerState {
        let elapsedFocusSeconds = elapsedFocusDuration(for: state, now: now)
        let actualFocusSeconds = creditableFocusDuration(normalizedFocusDurationForBreak(elapsedFocusSeconds))
        let breakSeconds = plannedBreakDurationSeconds ?? breakDurationForBreak(elapsedFocusSeconds)

        var next = state
        next.actualFocusDurationSeconds = actualFocusSeconds
        next.plannedBreakDurationSeconds = breakSeconds
        next.phase = .breakTime
        next.breakStartedAt = now
        next.plannedEndAt = now.addingTimeInterval(TimeInterval(breakSeconds))
        return next
    }

    func skipBreak(_ state: FlowTimerState, now: Date) -> FlowTimerState {
        var next = state
        next.phase = .completed
        next.endedAt = now
        next.completedAt = now
        return next
    }

    func extendAdaptive(_ state: FlowTimerState, now: Date) -> FlowTimerState {
        guard state.mode == .adaptive,
              state.phase == .awaitingExtensionDecision,
              let nextDuration = state.nextAdaptiveFocusDurationSeconds else {
            return state
        }

        let addedSeconds = nextDuration - state.plannedFocusDurationSeconds
        var next = state
        next.phase = .focusing
        next.plannedFocusDurationSeconds = nextDuration
        next.plannedBreakDurationSeconds = FlowMode.adaptiveBreakDurationSeconds(forFocusSeconds: nextDuration)
        next.plannedEndAt = now.addingTimeInterval(TimeInterval(addedSeconds))
        return next
    }

    /// Adds five minutes to the current focus plan without changing elapsed time.
    func seekForward(_ state: FlowTimerState, now: Date) -> FlowTimerState {
        guard isActiveFocus(state) else { return state }
        return applyPlannedFocusDuration(
            state.plannedFocusDurationSeconds + Self.seekStepSeconds,
            to: state
        )
    }

    /// Removes up to five minutes while keeping at least one minute remaining.
    func seekBackward(_ state: FlowTimerState, now: Date) -> FlowTimerState {
        guard isActiveFocus(state) else { return state }

        let remaining = remainingSeconds(for: state, now: now)
        guard remaining > Self.minimumRemainingFocusSeconds else { return state }

        let reduction = min(
            Self.seekStepSeconds,
            remaining - Self.minimumRemainingFocusSeconds
        )
        return applyPlannedFocusDuration(
            state.plannedFocusDurationSeconds - reduction,
            to: state
        )
    }

    /// Changes the preset without restarting the current Flow. Elapsed focus and
    /// pause accounting remain intact; only the planned duration and end move.
    func changeMode(_ mode: FlowMode, for state: FlowTimerState) -> FlowTimerState {
        let isPausedFocus = state.phase == .paused && state.phaseBeforePause != .breakTime
        guard state.phase == .focusing || isPausedFocus else { return state }

        var next = applyPlannedFocusDuration(mode.initialFocusDurationSeconds, to: state)
        next.mode = mode
        next.plannedBreakDurationSeconds = mode.breakDurationSeconds
        return next
    }

    private func applyPlannedFocusDuration(_ duration: Int, to state: FlowTimerState) -> FlowTimerState {
        guard duration != state.plannedFocusDurationSeconds else { return state }

        let delta = duration - state.plannedFocusDurationSeconds
        var next = state
        next.plannedFocusDurationSeconds = duration
        next.plannedBreakDurationSeconds = FlowMode.adaptiveBreakDurationSeconds(forFocusSeconds: duration)
        next.plannedEndAt = state.plannedEndAt.addingTimeInterval(TimeInterval(delta))
        return next
    }

    func remainingSeconds(for state: FlowTimerState, now: Date) -> Int {
        guard state.phase == .focusing || state.phase == .paused || state.phase == .breakTime else {
            return 0
        }

        let referenceDate = state.phase == .paused ? (state.pausedAt ?? now) : now
        return Int(state.plannedEndAt.timeIntervalSince(referenceDate).rounded(.up))
    }

    func actualFocusDuration(for state: FlowTimerState, now: Date) -> Int {
        if let actualFocusDurationSeconds = state.actualFocusDurationSeconds {
            return actualFocusDurationSeconds
        }

        return elapsedFocusDuration(for: state, now: now)
    }

    func elapsedFocusDuration(for state: FlowTimerState, now: Date) -> Int {
        let referenceDate = state.phase == .paused ? (state.pausedAt ?? now) : now
        let elapsed = max(0, Int(referenceDate.timeIntervalSince(state.startedAt)))
        return max(0, elapsed - state.accumulatedPauseDurationSeconds)
    }

    private func normalizedFocusDurationForBreak(_ elapsed: Int) -> Int {
        switch elapsed {
        case (49 * 60)...:
            return max(elapsed, 50 * 60)
        case (24 * 60)...:
            return max(elapsed, 25 * 60)
        default:
            return elapsed
        }
    }

    private func creditableFocusDuration(_ seconds: Int) -> Int {
        let focusedSeconds = max(0, seconds)
        return focusedSeconds < Self.minimumCreditableFocusDurationSeconds ? 0 : focusedSeconds
    }

    private func breakDurationForBreak(_ elapsedFocusSeconds: Int) -> Int {
        switch elapsedFocusSeconds {
        case (49 * 60)...:
            10 * 60
        case (24 * 60)...:
            5 * 60
        default:
            3 * 60
        }
    }

    private func isActiveFocus(_ state: FlowTimerState) -> Bool {
        state.phase == .focusing ||
            (state.phase == .paused && state.phaseBeforePause == .focusing)
    }
}

struct FlowTimerState: Equatable {
    var mode: FlowMode
    var phase: FlowPhase
    var startedAt: Date
    var plannedEndAt: Date
    var pausedAt: Date?
    var phaseBeforePause: FlowPhase?
    var accumulatedPauseDurationSeconds: Int = 0
    var completedAt: Date?
    var endedAt: Date?
    var plannedFocusDurationSeconds: Int
    var actualFocusDurationSeconds: Int?
    var plannedBreakDurationSeconds: Int
    var breakStartedAt: Date?
    var wasPaused: Bool = false
    var interruptionCount: Int = 0

    var isLongBreak: Bool {
        plannedBreakDurationSeconds == FlowSeriesPolicy.longBreakDurationSeconds &&
            (phase == .breakTime || (phase == .paused && phaseBeforePause == .breakTime))
    }

    var nextAdaptiveFocusDurationSeconds: Int? {
        switch plannedFocusDurationSeconds {
        case 12 * 60:
            return 25 * 60
        case 25 * 60:
            return 50 * 60
        default:
            return nil
        }
    }
}
