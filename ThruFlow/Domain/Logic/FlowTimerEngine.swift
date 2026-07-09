//
//  FlowTimerEngine.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import Foundation

struct FlowTimerEngine {
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
        next.actualFocusDurationSeconds = actualFocusDuration(for: state, now: now)
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

    func startBreak(_ state: FlowTimerState, now: Date) -> FlowTimerState {
        let actualFocusSeconds = normalizedFocusDurationForBreak(from: state, now: now)
        let breakSeconds = FlowMode.adaptiveBreakDurationSeconds(forFocusSeconds: actualFocusSeconds)

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

    /// Increases the current block size by one step (12 -> 25 -> 50 -> 75 -> ...),
    /// keeping already-elapsed focus time intact by pushing the planned end forward.
    func seekForward(_ state: FlowTimerState, now: Date) -> FlowTimerState {
        guard state.phase == .focusing || state.phase == .paused else { return state }
        return applyPlannedFocusDuration(
            Self.nextBlockDurationSeconds(after: state.plannedFocusDurationSeconds),
            to: state
        )
    }

    /// Decreases the current block size by one step (... -> 50 -> 25 -> 12),
    /// never going below the smallest block size.
    func seekBackward(_ state: FlowTimerState, now: Date) -> FlowTimerState {
        guard state.phase == .focusing || state.phase == .paused else { return state }
        return applyPlannedFocusDuration(
            Self.previousBlockDurationSeconds(before: state.plannedFocusDurationSeconds),
            to: state
        )
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

    static func nextBlockDurationSeconds(after seconds: Int) -> Int {
        switch seconds {
        case ..<(12 * 60):
            12 * 60
        case (12 * 60)..<(25 * 60):
            25 * 60
        case (25 * 60)..<(50 * 60):
            50 * 60
        default:
            seconds + 25 * 60
        }
    }

    static func previousBlockDurationSeconds(before seconds: Int) -> Int {
        switch seconds {
        case ...(12 * 60):
            12 * 60
        case (12 * 60 + 1)...(25 * 60):
            12 * 60
        case (25 * 60 + 1)...(50 * 60):
            25 * 60
        case (50 * 60 + 1)...(75 * 60):
            50 * 60
        default:
            seconds - 25 * 60
        }
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

    private func normalizedFocusDurationForBreak(from state: FlowTimerState, now: Date) -> Int {
        let elapsed = elapsedFocusDuration(for: state, now: now)

        switch elapsed {
        case (49 * 60)...:
            return max(50 * 60, elapsed)
        case (24 * 60)...:
            return 25 * 60
        default:
            return elapsed
        }
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
