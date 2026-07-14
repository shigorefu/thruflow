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
    @Published private(set) var isAwaitingBreakMemo = false

    private let engine = FlowTimerEngine()
    private let progress = FlowProgressCalculator()
    private let seriesPolicy = FlowSeriesPolicy()
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

    var canChangeMode: Bool {
        guard let timerState else { return true }
        return timerState.phase == .focusing ||
            (timerState.phase == .paused && timerState.phaseBeforePause != .breakTime)
    }

    var isBreakPhase: Bool {
        guard let timerState else { return false }
        return timerState.phase == .breakTime ||
            (timerState.phase == .paused && timerState.phaseBeforePause == .breakTime)
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
        let sessionID = UUID()
        let pendingBreak = eligiblePendingBreak(modelContext: modelContext, at: now)
        let seriesID = pendingBreak?.seriesID ?? sessionID
        let session = FlowSession(
            id: sessionID,
            seriesID: seriesID,
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
        let segment = FlowSegment(
            session: session,
            direction: direction,
            todo: todo,
            startedAt: now,
            startFocusSeconds: 0
        )
        modelContext.insert(segment)
        if !session.segments.contains(where: { $0.id == segment.id }) {
            session.segments.append(segment)
        }
        pendingBreak?.connect(to: sessionID, at: now)
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
        try? modelContext.save()
    }

    func selectContext(
        direction: Direction?,
        todo: Todo?,
        modelContext: ModelContext,
        now: Date = .now
    ) {
        guard let direction else { return }

        if let state = timerState,
           state.phase == .focusing || state.phase == .paused || state.phase == .awaitingExtensionDecision,
           let session = activeSession {
            let currentTodoID = session.segments.last(where: { $0.endedAt == nil })?.todo?.id
            let currentDirectionID = session.segments.last(where: { $0.endedAt == nil })?.direction?.id

            if currentTodoID != todo?.id || currentDirectionID != direction.id {
                let focusedSeconds = engine.actualFocusDuration(for: state, now: now)
                closeCurrentSegment(at: now, totalFocusSeconds: focusedSeconds)

                let segment = FlowSegment(
                    session: session,
                    direction: direction,
                    todo: todo,
                    startedAt: now,
                    startFocusSeconds: focusedSeconds
                )
                modelContext.insert(segment)
                if !session.segments.contains(where: { $0.id == segment.id }) {
                    session.segments.append(segment)
                }
                session.direction = direction
                session.todo = todo
                session.updatedAt = now
            }
        }

        configure(direction: direction, todo: todo)
        try? modelContext.save()
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
        if timerState.phase == .breakTime {
            completeBreak(modelContext: modelContext, now: now)
            return
        }

        guard !discardShortFlowIfNeeded(timerState, modelContext: modelContext, now: now) else { return }
        apply(engine.finish(timerState, now: now), modelContext: modelContext, now: now)
    }

    func completeResult(_ result: String?, modelContext: ModelContext, now: Date = .now) {
        activeSession?.todo?.setMemo(result, now: now)
        activeSession?.complete(now: now)

        if let timerState {
            apply(engine.completeResult(timerState, now: now), modelContext: modelContext, now: now)
        }

        activeSession = nil
        self.timerState = nil
        didApplyProgress = false
        isAwaitingBreakMemo = false
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
        notifications.cancelPendingFlowNotifications()
        guard !discardShortFlowIfNeeded(timerState, modelContext: modelContext, now: now) else { return }
        beginBreak(from: timerState, modelContext: modelContext, now: now)
    }

    func requestBreakMemo(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        guard timerState.phase == .focusing || timerState.phase == .awaitingExtensionDecision else { return }
        guard !discardShortFlowIfNeeded(timerState, modelContext: modelContext, now: now) else { return }
        isAwaitingBreakMemo = true
    }

    func completeBreakMemo(_ result: String?, modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        guard isAwaitingBreakMemo else { return }
        guard timerState.phase == .focusing || timerState.phase == .awaitingExtensionDecision else {
            isAwaitingBreakMemo = false
            return
        }

        guard !discardShortFlowIfNeeded(timerState, modelContext: modelContext, now: now) else { return }
        activeSession?.todo?.setMemo(result, now: now)
        isAwaitingBreakMemo = false
        notifications.cancelPendingFlowNotifications()
        beginBreak(from: timerState, modelContext: modelContext, now: now)
    }

    func cancelBreakMemo() {
        isAwaitingBreakMemo = false
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

    func selectMode(_ mode: FlowMode, modelContext: ModelContext, now: Date = .now) {
        guard mode != selectedMode else { return }

        selectedMode = mode
        persistConfiguration()

        guard let timerState else { return }
        let next = engine.changeMode(mode, for: timerState)
        guard next != timerState else { return }

        notifications.cancelPendingFlowNotifications()
        if next.phase == .focusing {
            notifications.scheduleFocusFinished(
                mode: next.mode,
                focusedSeconds: next.plannedFocusDurationSeconds,
                fireDate: next.plannedEndAt
            )
        }
        apply(next, modelContext: modelContext, now: now)
    }

    func stop(modelContext: ModelContext, now: Date = .now) {
        notifications.cancelPendingFlowNotifications()

        guard let timerState else { return }
        if timerState.phase == .breakTime {
            completeBreak(modelContext: modelContext, now: now)
            return
        }

        guard !discardShortFlowIfNeeded(timerState, modelContext: modelContext, now: now) else { return }
        apply(engine.finish(timerState, now: now), modelContext: modelContext, now: now)
    }

    func destroy(modelContext: ModelContext, now: Date = .now) {
        notifications.cancelPendingFlowNotifications()

        if let activeSession {
            openBreak(for: activeSession.id, modelContext: modelContext)?.deletedAt = now
            modelContext.delete(activeSession)
        }

        activeSession = nil
        timerState = nil
        didApplyProgress = false
        isAwaitingBreakMemo = false
        try? modelContext.save()
    }

    func skipBreak(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        notifications.cancelPendingFlowNotifications()
        guard timerState.phase == .breakTime else { return }
        completeBreak(modelContext: modelContext, now: now)
    }

    func startNextFlow(
        direction: Direction,
        todo: Todo?,
        modelContext: ModelContext,
        now: Date = .now
    ) {
        guard timerState?.phase == .breakTime else { return }

        notifications.cancelPendingFlowNotifications()
        completeBreak(modelContext: modelContext, now: now)
        configure(direction: direction, todo: todo)
        start(direction: direction, todo: todo, modelContext: modelContext, now: now)
    }

    private func completeBreak(modelContext: ModelContext, now: Date) {
        guard let timerState else { return }
        if let activeSession {
            openBreak(for: activeSession.id, modelContext: modelContext)?.stopTimer(at: now)
        }
        apply(engine.skipBreak(timerState, now: now), modelContext: modelContext, now: now)
        activeSession = nil
        self.timerState = nil
        didApplyProgress = false
        isAwaitingBreakMemo = false
        try? modelContext.save()
    }

    private func beginBreak(
        from state: FlowTimerState,
        modelContext: ModelContext,
        now: Date
    ) {
        guard let activeSession else { return }

        let focusedSeconds = engine.actualFocusDuration(for: state, now: now)
        let seriesID = activeSession.seriesID ?? activeSession.id
        let priorSeriesSeconds = sessions(modelContext: modelContext)
            .filter { $0.id != activeSession.id && ($0.seriesID ?? $0.id) == seriesID }
            .reduce(0) { $0 + $1.resolvedActualFocusDurationSeconds }
        let completedLongBreaks = flowBreaks(modelContext: modelContext)
            .filter { $0.seriesID == seriesID && $0.isLongBreak && !$0.isDeleted }
            .count
        let usesLongBreak = seriesPolicy.shouldUseLongBreak(
            totalSeriesFocusSeconds: priorSeriesSeconds + focusedSeconds,
            completedLongBreakCount: completedLongBreaks
        )
        let regularBreakState = engine.startBreak(state, now: now)
        let plannedBreakSeconds = usesLongBreak
            ? FlowSeriesPolicy.longBreakDurationSeconds
            : regularBreakState.plannedBreakDurationSeconds
        let next = engine.startBreak(
            state,
            now: now,
            plannedBreakDurationSeconds: plannedBreakSeconds
        )
        let flowBreak = FlowBreak(
            seriesID: seriesID,
            previousSessionID: activeSession.id,
            startedAt: now,
            plannedDurationSeconds: plannedBreakSeconds,
            isLongBreak: usesLongBreak
        )

        modelContext.insert(flowBreak)
        apply(next, modelContext: modelContext, now: now)
    }

    private func eligiblePendingBreak(modelContext: ModelContext, at date: Date) -> FlowBreak? {
        flowBreaks(modelContext: modelContext)
            .filter { flowBreak in
                flowBreak.timerStoppedAt != nil && seriesPolicy.canContinueSeries(after: flowBreak, at: date)
            }
            .max { $0.startedAt < $1.startedAt }
    }

    private func openBreak(for sessionID: UUID, modelContext: ModelContext) -> FlowBreak? {
        flowBreaks(modelContext: modelContext)
            .filter {
                $0.previousSessionID == sessionID &&
                    $0.timerStoppedAt == nil &&
                    !$0.isDeleted
            }
            .max { $0.startedAt < $1.startedAt }
    }

    private func sessions(modelContext: ModelContext) -> [FlowSession] {
        (try? modelContext.fetch(FetchDescriptor<FlowSession>())) ?? []
    }

    private func flowBreaks(modelContext: ModelContext) -> [FlowBreak] {
        (try? modelContext.fetch(FetchDescriptor<FlowBreak>())) ?? []
    }

    func remainingText(now: Date = .now) -> String {
        guard let timerState else { return "--:--" }
        let seconds = engine.remainingSeconds(for: timerState, now: now)
        if isBreakPhase {
            return Self.timeText(seconds: seconds, allowsOvertime: true)
        }
        return Self.timeText(seconds: seconds, allowsOvertime: timerState.phase == .focusing)
    }

    func actualFocusSeconds(now: Date = .now) -> Int {
        guard let timerState else { return 0 }
        return engine.actualFocusDuration(for: timerState, now: now)
    }

    func phaseProgress(now: Date = .now) -> Double {
        guard let timerState else { return 0 }

        let duration = isBreakPhase
            ? timerState.plannedBreakDurationSeconds
            : timerState.plannedFocusDurationSeconds

        guard duration > 0 else { return 0 }
        let remaining = engine.remainingSeconds(for: timerState, now: now)

        if isBreakPhase {
            return min(max(Double(remaining) / Double(duration), 0), 1)
        }

        return min(max(1 - (Double(remaining) / Double(duration)), 0), 1)
    }

    func isFocusOvertime(now: Date = .now) -> Bool {
        guard let timerState, timerState.phase == .focusing else { return false }
        return engine.remainingSeconds(for: timerState, now: now) <= 0
    }

    private func apply(_ state: FlowTimerState, modelContext: ModelContext, now: Date) {
        guard state != timerState else { return }

        let previousPhase = timerState?.phase
        timerState = state
        activeSession?.apply(timerState: state, now: now)

        if state.phase == .breakTime || state.phase == .awaitingResult || state.phase == .completed {
            let focusedSeconds = state.actualFocusDurationSeconds ?? engine.actualFocusDuration(for: state, now: now)
            closeCurrentSegment(at: now, totalFocusSeconds: focusedSeconds)
            applyProgressIfNeeded(seconds: focusedSeconds, now: now)
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

        if let activeSession {
            progress.applySession(activeSession, fallbackSeconds: seconds, now: now)
        }
        didApplyProgress = true
    }

    private func closeCurrentSegment(at date: Date, totalFocusSeconds: Int) {
        activeSession?.segments
            .last(where: { $0.endedAt == nil })?
            .close(at: date, totalFocusSeconds: totalFocusSeconds)
    }

    private func discardShortFlowIfNeeded(
        _ state: FlowTimerState,
        modelContext: ModelContext,
        now: Date
    ) -> Bool {
        guard engine.actualFocusDuration(for: state, now: now) < FlowTimerEngine.minimumCreditableFocusDurationSeconds else {
            return false
        }

        if let activeSession {
            modelContext.delete(activeSession)
        }

        activeSession = nil
        timerState = nil
        didApplyProgress = false
        isAwaitingBreakMemo = false
        try? modelContext.save()
        return true
    }

    private func persistConfiguration() {
        defaults.set(uuid: selectedDirectionID, forKey: "flow.selectedDirectionID")
        defaults.set(uuid: selectedTodoID, forKey: "flow.selectedTodoID")
        defaults.set(selectedMode.rawValue, forKey: "flow.selectedMode")
        defaults.set(intent, forKey: "flow.lastIntent")
    }

    nonisolated static func timeText(
        seconds: Int,
        allowsOvertime: Bool = false,
        overtimePrefix: String = "+"
    ) -> String {
        if allowsOvertime, seconds < 0 {
            let overtimeSeconds = abs(seconds)
            return String(format: "%@%02d:%02d", overtimePrefix, overtimeSeconds / 60, overtimeSeconds % 60)
        }

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
