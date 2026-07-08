//
//  ActiveFlowStore.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import Foundation
import Combine
import SwiftData

@MainActor
final class ActiveFlowStore: ObservableObject {
    @Published var selectedDirectionID: UUID?
    @Published var selectedTodoID: UUID?
    @Published var selectedMode: FlowMode
    @Published var intent: String
    @Published var timerState: FlowTimerState? {
        didSet {
            synchronizeDisplayClock()
        }
    }
    @Published var activeSession: FlowSession?
    @Published private(set) var displayDate: Date = .now

    private let engine = FlowTimerEngine()
    private let progress = FlowProgressCalculator()
    private let notifications: FlowNotificationService
    private let defaults: UserDefaults
    private var didApplyProgress = false
    private var displayClock: AnyCancellable?

    init(
        defaults: UserDefaults = .standard,
        notifications: FlowNotificationService? = nil
    ) {
        self.defaults = defaults
        self.notifications = notifications ?? LocalFlowNotificationService()
        selectedDirectionID = defaults.uuid(forKey: "flow.selectedDirectionID")
        selectedTodoID = defaults.uuid(forKey: "flow.selectedTodoID")
        selectedMode = defaults.flowMode(forKey: "flow.selectedMode") ?? .twentyFiveFive
        intent = defaults.string(forKey: "flow.lastIntent") ?? ""
    }

    var phase: FlowPhase {
        timerState?.phase ?? (selectedDirectionID == nil ? .idle : .configured)
    }

    var canStart: Bool {
        selectedDirectionID != nil && timerState == nil
    }

    func configure(direction: Direction?, todo: Todo?, intent: String? = nil, mode: FlowMode? = nil) {
        selectedDirectionID = direction?.id
        selectedTodoID = todo?.id

        if let intent {
            self.intent = intent
        }

        if let mode {
            selectedMode = mode
        }

        persistConfiguration()
    }

    func start(direction: Direction, todo: Todo?, modelContext: ModelContext, now: Date = .now) {
        let state = engine.start(mode: selectedMode, now: now)
        let session = FlowSession(
            direction: direction,
            todo: todo,
            intent: intent.trimmingCharacters(in: .whitespacesAndNewlines),
            mode: selectedMode,
            startedAt: state.startedAt,
            plannedEndAt: state.plannedEndAt,
            plannedFocusDurationSeconds: state.plannedFocusDurationSeconds,
            plannedBreakDurationSeconds: state.plannedBreakDurationSeconds,
            createdAt: now,
            updatedAt: now
        )

        modelContext.insert(session)
        activeSession = session
        timerState = state
        didApplyProgress = false
        persistConfiguration()
        notifications.requestAuthorizationIfNeeded()
        notifications.scheduleFocusFinished(
            mode: state.mode,
            focusedSeconds: state.plannedFocusDurationSeconds,
            fireDate: state.plannedEndAt
        )
    }

    func refresh(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        let next = engine.advanceIfNeeded(timerState, now: now)
        guard next != timerState else { return }
        apply(next, modelContext: modelContext, now: now)
    }

    func pause(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        notifications.cancelPendingFlowNotifications()
        apply(engine.pause(timerState, now: now), modelContext: modelContext, now: now)
    }

    func resume(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        let next = engine.resume(timerState, now: now)
        notifications.scheduleFocusFinished(
            mode: next.mode,
            focusedSeconds: next.plannedFocusDurationSeconds,
            fireDate: next.plannedEndAt
        )
        apply(next, modelContext: modelContext, now: now)
    }

    func finish(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        notifications.cancelPendingFlowNotifications()
        apply(engine.finish(timerState, now: now), modelContext: modelContext, now: now)
    }

    func completeResult(_ result: String?, modelContext: ModelContext, now: Date = .now) {
        activeSession?.setResult(result, now: now)

        if let timerState {
            apply(engine.completeResult(timerState, now: now), modelContext: modelContext, now: now)
        }

        activeSession = nil
        self.timerState = nil
        didApplyProgress = false
    }

    func extendAdaptive(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        let next = engine.extendAdaptive(timerState, now: now)
        notifications.scheduleFocusFinished(
            mode: next.mode,
            focusedSeconds: next.plannedFocusDurationSeconds,
            fireDate: next.plannedEndAt
        )
        apply(next, modelContext: modelContext, now: now)
    }

    func startBreak(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        let next = engine.startBreak(timerState, now: now)
        apply(next, modelContext: modelContext, now: now)
    }

    func seekForward(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        let next = engine.seekForward(timerState, now: now)
        guard next != timerState else { return }
        notifications.scheduleFocusFinished(
            mode: next.mode,
            focusedSeconds: next.plannedFocusDurationSeconds,
            fireDate: next.plannedEndAt
        )
        apply(next, modelContext: modelContext, now: now)
    }

    func seekBackward(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        let next = engine.seekBackward(timerState, now: now)
        guard next != timerState else { return }
        notifications.scheduleFocusFinished(
            mode: next.mode,
            focusedSeconds: next.plannedFocusDurationSeconds,
            fireDate: next.plannedEndAt
        )
        apply(next, modelContext: modelContext, now: now)
    }

    func stop(modelContext: ModelContext, now: Date = .now) {
        notifications.cancelPendingFlowNotifications()

        if let timerState {
            let finished = engine.finish(timerState, now: now)
            let completed = engine.completeResult(finished, now: now)
            activeSession?.apply(timerState: completed, now: now)
            applyProgressIfNeeded(
                seconds: finished.actualFocusDurationSeconds ?? engine.actualFocusDuration(for: timerState, now: now),
                now: now
            )
        }

        activeSession = nil
        timerState = nil
        didApplyProgress = false
        try? modelContext.save()
    }

    func destroy(modelContext: ModelContext, now: Date = .now) {
        notifications.cancelPendingFlowNotifications()

        if let activeSession {
            modelContext.delete(activeSession)
        }

        activeSession = nil
        timerState = nil
        didApplyProgress = false
        try? modelContext.save()
    }

    func skipBreak(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        notifications.cancelPendingFlowNotifications()
        apply(engine.skipBreak(timerState, now: now), modelContext: modelContext, now: now)
        activeSession = nil
        self.timerState = nil
        didApplyProgress = false
    }

    func remainingText(now: Date = .now) -> String {
        guard let timerState else { return "--:--" }
        let seconds = engine.remainingSeconds(for: timerState, now: now)
        return Self.timeText(seconds: seconds)
    }

    func actualFocusSeconds(now: Date = .now) -> Int {
        guard let timerState else { return 0 }
        return engine.actualFocusDuration(for: timerState, now: now)
    }

    private func apply(_ state: FlowTimerState, modelContext: ModelContext, now: Date) {
        guard state != timerState else { return }

        let previousPhase = timerState?.phase
        timerState = state
        activeSession?.apply(timerState: state, now: now)

        if state.phase == .breakTime || state.phase == .awaitingResult || state.phase == .completed {
            applyProgressIfNeeded(seconds: state.actualFocusDurationSeconds ?? engine.actualFocusDuration(for: state, now: now), now: now)
        }

        if state.phase == .breakTime && previousPhase != .breakTime {
            notifications.scheduleBreakFinished(fireDate: state.plannedEndAt)
        }

        try? modelContext.save()
    }

    private func synchronizeDisplayClock() {
        displayDate = .now

        guard timerState != nil else {
            displayClock?.cancel()
            displayClock = nil
            return
        }

        guard displayClock == nil else { return }

        displayClock = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.displayDate = date
            }
    }

    private func applyProgressIfNeeded(seconds: Int, now: Date) {
        guard !didApplyProgress else { return }
        progress.applyFocusDuration(
            seconds: seconds,
            direction: activeSession?.direction,
            todo: activeSession?.todo,
            now: now
        )
        didApplyProgress = true
    }

    private func persistConfiguration() {
        defaults.set(uuid: selectedDirectionID, forKey: "flow.selectedDirectionID")
        defaults.set(uuid: selectedTodoID, forKey: "flow.selectedTodoID")
        defaults.set(selectedMode.rawValue, forKey: "flow.selectedMode")
        defaults.set(intent, forKey: "flow.lastIntent")
    }

    static func timeText(seconds: Int) -> String {
        let clampedSeconds = max(0, seconds)
        return String(format: "%02d:%02d", clampedSeconds / 60, clampedSeconds % 60)
    }
}

private extension UserDefaults {
    func uuid(forKey key: String) -> UUID? {
        guard let value = string(forKey: key) else { return nil }
        return UUID(uuidString: value)
    }

    func set(uuid: UUID?, forKey key: String) {
        set(uuid?.uuidString, forKey: key)
    }

    func flowMode(forKey key: String) -> FlowMode? {
        guard let value = string(forKey: key) else { return nil }
        return FlowMode(rawValue: value)
    }
}
