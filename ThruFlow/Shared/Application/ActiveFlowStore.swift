//
//  ActiveFlowStore.swift
//  ThruFlow
//
//

import Foundation
import Combine
import CoreData
import SwiftData

@MainActor
final class ActiveFlowStore: ObservableObject {
    private static let forgottenTimerReminderSeconds = 60 * 60
    private static let persistenceReconciliationInterval: TimeInterval = 30

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
    // Timer presentation surfaces own their local one-second TimelineView.
    // Publishing this value would invalidate every ActiveFlowStore observer,
    // including the 60 FPS Metal stream, once per second.
    private(set) var displayDate: Date = .now
    @Published private(set) var isAwaitingBreakMemo = false
    @Published private(set) var flowBreakInteraction: FlowBreakInteraction?

    private let engine = FlowTimerEngine()
    private let progressReconciler = FlowProgressReconciler()
    private let historyEditor = FlowHistoryEditor()
    private let seriesPolicy = FlowSeriesPolicy()
    private let contextSwitchPolicy = FlowContextSwitchPolicy()
    private let syncCoordinator = ActiveFlowSyncCoordinator()
    private let notifications: FlowNotificationService
    private let liveActivities: any LiveActivityService
    private let defaults: UserDefaults
    private let persistenceNotificationCenter: NotificationCenter
    private var didApplyProgress = false
    private var stateBeforeResultPrompt: FlowTimerState?
    private var displayClock: AnyCancellable?
    private var synchronizationClock: AnyCancellable?
    private var persistenceChangeObservers: Set<AnyCancellable> = []
    private var lastAppliedRuntimeVersion: FlowRuntimeVersion?
    private var lastPublishedLiveActivityWasOvertime: Bool?
    private var lastPersistenceReconciliationAt: Date?
    private var nextFlowBreakInteractionSequence: UInt64 = 0

    init(
        defaults: UserDefaults = .standard,
        notifications: FlowNotificationService? = nil,
        liveActivities: (any LiveActivityService)? = nil,
        persistenceNotificationCenter: NotificationCenter = .default
    ) {
        self.defaults = defaults
        self.notifications = notifications ?? LocalFlowNotificationService()
        self.liveActivities = liveActivities ?? NoopLiveActivityService()
        self.persistenceNotificationCenter = persistenceNotificationCenter
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

    var canRequestBreak: Bool {
        timerState?.phase == .focusing || timerState?.phase == .awaitingExtensionDecision
    }

    var flowStreamBreakStyle: FlowStreamBreakStyle {
        guard isBreakPhase else { return .none }
        return timerState?.isLongBreak == true ? .long : .regular
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

    @discardableResult
    func reconcileSelectedTodoForCurrentDay(
        todos: [Todo],
        directions: [Direction],
        now: Date = .now,
        calendar: Calendar = .current,
        dayBoundary: AppDayBoundary = .midnight
    ) -> Bool {
        guard timerState == nil, let selectedTodoID else { return false }

        let filter = TodayTodoFilter(calendar: calendar, dayBoundary: dayBoundary)
        let todayTodos = FlowDashboardTodoSorter().sorted(
            todos.filter { filter.includes($0, now: now) }
        )
        guard !todayTodos.contains(where: { $0.id == selectedTodoID }) else {
            return false
        }

        let previousTodo = todos.first { $0.id == selectedTodoID }
        let preferredDirectionID = previousTodo?.direction?.id ?? selectedDirectionID
        let replacement = todayTodos.first {
            !$0.isCompleted && $0.direction?.id == preferredDirectionID
        } ?? todayTodos.first(where: { !$0.isCompleted })

        let activeDirections = directions.filter { !$0.isArchived }
        let replacementDirection = replacement?.direction
            ?? activeDirections.first(where: { $0.id == preferredDirectionID })
            ?? activeDirections.first
        configure(direction: replacementDirection, todo: replacement)
        return true
    }

    func resetAfterApplicationDataReset() {
        guard timerState == nil else { return }

        notifications.cancelPendingFlowNotifications()
        notifications.clearBadge()
        liveActivities.end()
        selectedDirectionID = nil
        selectedTodoID = nil
        selectedMode = .twentyFiveFive
        intent = ""
        activeSession = nil
        didApplyProgress = false
        isAwaitingBreakMemo = false
        stateBeforeResultPrompt = nil
        lastAppliedRuntimeVersion = nil
        flowBreakInteraction = nil
        persistConfiguration()
    }

    func start(direction: Direction, todo: Todo?, modelContext: ModelContext, now: Date = .now) {
        stateBeforeResultPrompt = nil
        let state = engine.start(mode: selectedMode, now: now)
        let sessionID = UUID()
        let pendingBreak: FlowBreak?
        do {
            pendingBreak = try eligiblePendingBreak(modelContext: modelContext, at: now)
        } catch {
            PersistenceIssueCenter.shared.report(error, operation: .dataLoad)
            return
        }
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
        if !session.resolvedSegments.contains(where: { $0.id == segment.id }) {
            session.resolvedSegments.append(segment)
        }
        pendingBreak?.connect(to: sessionID, at: now)
        activeSession = session
        timerState = state
        didApplyProgress = false
        persistConfiguration()
        guard modelContext.saveReporting(.flowStart) else {
            activeSession = nil
            timerState = nil
            didApplyProgress = false
            return
        }
        notifications.requestAuthorizationIfNeeded()
        replaceNotifications(for: state)
        lastAppliedRuntimeVersion = session.runtimeVersion
        startLiveActivity(now: now)
    }

    func selectContext(
        direction: Direction?,
        todo: Todo?,
        modelContext: ModelContext,
        now: Date = .now
    ) {
        guard let direction else { return }
        let previousDirectionID = selectedDirectionID
        let previousTodoID = selectedTodoID

        if let state = timerState,
           state.phase == .focusing || state.phase == .paused || state.phase == .awaitingExtensionDecision,
           let session = activeSession {
            let currentTodoID = session.resolvedSegments.last(where: { $0.endedAt == nil })?.todo?.id
            let currentDirectionID = session.resolvedSegments.last(where: { $0.endedAt == nil })?.direction?.id

            if currentTodoID != todo?.id || currentDirectionID != direction.id {
                let focusedSeconds = engine.actualFocusDuration(for: state, now: now)
                if let currentSegment = session.resolvedSegments.last(where: { $0.endedAt == nil }),
                   contextSwitchPolicy.shouldTransferCurrentSegment(
                       totalFocusSeconds: focusedSeconds,
                       segmentStartFocusSeconds: currentSegment.startFocusSeconds
                   ) {
                    transferCurrentSegment(
                        currentSegment,
                        to: direction,
                        todo: todo,
                        session: session,
                        modelContext: modelContext
                    )
                } else {
                    closeCurrentSegment(at: now, totalFocusSeconds: focusedSeconds)
                    openSegment(
                        direction: direction,
                        todo: todo,
                        session: session,
                        modelContext: modelContext,
                        now: now,
                        startFocusSeconds: focusedSeconds
                    )
                }
                session.direction = direction
                session.todo = todo
                session.recordRuntimeMutation(now: now)
            }
        }

        configure(direction: direction, todo: todo)
        guard modelContext.saveReporting(.flowUpdate) else {
            selectedDirectionID = previousDirectionID
            selectedTodoID = previousTodoID
            persistConfiguration()
            return
        }
        lastAppliedRuntimeVersion = activeSession?.runtimeVersion
        synchronizeLiveActivity(now: now)
    }

    func beginSynchronization(modelContext: ModelContext, now: Date = .now) {
        observePersistenceChangesIfNeeded(modelContext: modelContext)
        synchronizeFromPersistence(modelContext: modelContext, now: now)
        guard synchronizationClock == nil else { return }

        synchronizationClock = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.synchronizeFromPersistence(modelContext: modelContext, now: date)
            }
    }

    func endSynchronization() {
        synchronizationClock?.cancel()
        synchronizationClock = nil
    }

    private func observePersistenceChangesIfNeeded(modelContext: ModelContext) {
        guard persistenceChangeObservers.isEmpty else { return }

        persistenceNotificationCenter.publisher(
            for: NSPersistentCloudKitContainer.eventChangedNotification
        )
        .compactMap(ActiveFlowPersistenceEvent.completedCloudKitImportDate)
        .receive(on: RunLoop.main)
        .sink { [weak self] importedAt in
            self?.synchronizeFromPersistence(
                modelContext: modelContext,
                now: importedAt
            )
        }
        .store(in: &persistenceChangeObservers)

        persistenceNotificationCenter.publisher(for: .NSPersistentStoreRemoteChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.synchronizeFromPersistence(modelContext: modelContext)
            }
            .store(in: &persistenceChangeObservers)
    }

    func synchronizeFromPersistence(modelContext: ModelContext, now: Date = .now) {
        reconcilePersistenceIfNeeded(modelContext: modelContext, now: now)
        let resolution: ActiveFlowSyncResolution
        do {
            resolution = try syncCoordinator.resolve(modelContext: modelContext)
        } catch {
            PersistenceIssueCenter.shared.report(error, operation: .flowSynchronization)
            return
        }

        if let canonicalSession = resolution.canonicalSession,
           !resolution.supersededSessions.isEmpty {
            syncCoordinator.interruptSuperseded(
                resolution.supersededSessions,
                canonicalSession: canonicalSession,
                now: now
            )
            guard modelContext.saveReporting(.flowSynchronization) else { return }
        }

        guard let canonicalSession = resolution.canonicalSession,
              let synchronizedState = canonicalSession.reconstructableTimerState else {
            clearSynchronizedRuntimeIfNeeded()
            return
        }

        let version = canonicalSession.runtimeVersion
        guard canonicalSession.id != activeSession?.id ||
                version != lastAppliedRuntimeVersion else {
            return
        }

        adopt(
            session: canonicalSession,
            timerState: synchronizedState,
            now: now
        )
    }

    private func reconcilePersistenceIfNeeded(modelContext: ModelContext, now: Date) {
        if let lastPersistenceReconciliationAt,
           now.timeIntervalSince(lastPersistenceReconciliationAt) < Self.persistenceReconciliationInterval {
            return
        }

        do {
            try DefaultDirectionReconciler().reconcile(modelContext: modelContext, now: now)
            try OrphanTodoReconciler().reconcile(modelContext: modelContext, now: now)
            lastPersistenceReconciliationAt = now
        } catch {
            PersistenceIssueCenter.shared.log(error, operation: .flowSynchronization)
        }
    }

    func refresh(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        let next = engine.advanceIfNeeded(timerState, now: now)
        guard next != timerState else { return }
        _ = apply(next, modelContext: modelContext, now: now)
    }

    func pause(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        _ = apply(engine.pause(timerState, now: now), modelContext: modelContext, now: now)
    }

    func resume(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        let next = engine.resume(timerState, now: now)
        _ = apply(next, modelContext: modelContext, now: now)
    }

    func finish(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        if timerState.phase == .breakTime {
            _ = completeBreak(modelContext: modelContext, now: now)
            return
        }

        guard !discardShortFlowIfNeeded(timerState, modelContext: modelContext, now: now) else { return }
        stateBeforeResultPrompt = timerState
        _ = apply(engine.finish(timerState, now: now), modelContext: modelContext, now: now)
    }

    func completeResult(_ result: String?, modelContext: ModelContext, now: Date = .now) {
        let completedSessionID = activeSession?.id
        let normalizedResult = normalizedResult(result)
        activeSession?.result = normalizedResult
        if let normalizedResult {
            activeSession?.todo?.setMemo(normalizedResult, now: now)
        }
        activeSession?.complete(now: now)

        if let timerState {
            guard apply(
                engine.completeResult(timerState, now: now),
                modelContext: modelContext,
                now: now
            ) else { return }
        }

        activeSession = nil
        self.timerState = nil
        didApplyProgress = false
        isAwaitingBreakMemo = false
        stateBeforeResultPrompt = nil
        lastAppliedRuntimeVersion = nil
        liveActivities.end()

        if let completedSessionID {
            TaskCompletionFeedbackPlayer.shared.playFlow(for: completedSessionID, now: now)
            NotificationCenter.default.post(name: .flowDidComplete, object: completedSessionID)
        }
    }

    func cancelResultMemo(modelContext: ModelContext, now: Date = .now) {
        guard timerState?.phase == .awaitingResult,
              let restoredState = stateBeforeResultPrompt,
              let activeSession else {
            return
        }
        let previousState = timerState
        let previousDidApplyProgress = didApplyProgress
        let previousStateBeforeResultPrompt = stateBeforeResultPrompt

        activeSession.resolvedSegments.max(by: { $0.startedAt < $1.startedAt })?.reopen()
        timerState = restoredState
        activeSession.apply(timerState: restoredState, now: now)
        do {
            try progressReconciler.reconcile(
                session: activeSession,
                modelContext: modelContext,
                now: now
            )
        } catch {
            modelContext.rollback()
            timerState = previousState
            PersistenceIssueCenter.shared.report(error, operation: .flowUpdate)
            return
        }
        didApplyProgress = false
        stateBeforeResultPrompt = nil

        guard modelContext.saveReporting(.flowUpdate) else {
            timerState = previousState
            didApplyProgress = previousDidApplyProgress
            stateBeforeResultPrompt = previousStateBeforeResultPrompt
            return
        }
        replaceNotifications(for: restoredState)
        synchronizeLiveActivity(now: now)
    }

    func extendAdaptive(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        let next = engine.extendAdaptive(timerState, now: now)
        _ = apply(next, modelContext: modelContext, now: now)
    }

    func startBreak(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        guard !discardShortFlowIfNeeded(timerState, modelContext: modelContext, now: now) else { return }
        _ = beginBreak(from: timerState, modelContext: modelContext, now: now)
    }

    func requestBreakMemo(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        guard canRequestBreak else { return }
        publishFlowBreakInteraction(.requested, at: now)
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
        let normalizedResult = normalizedResult(result)
        activeSession?.result = normalizedResult
        if let normalizedResult {
            activeSession?.todo?.setMemo(normalizedResult, now: now)
        }
        isAwaitingBreakMemo = false
        _ = beginBreak(from: timerState, modelContext: modelContext, now: now)
    }

    private func normalizedResult(_ result: String?) -> String? {
        let trimmed = result?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == true ? nil : trimmed
    }

    func cancelBreakMemo() {
        isAwaitingBreakMemo = false
    }

    func seekForward(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        let next = engine.seekForward(timerState, now: now)
        guard next != timerState else { return }
        _ = apply(next, modelContext: modelContext, now: now)
    }

    func seekBackward(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        let next = engine.seekBackward(timerState, now: now)
        guard next != timerState else { return }
        _ = apply(next, modelContext: modelContext, now: now)
    }

    func selectMode(_ mode: FlowMode, modelContext: ModelContext, now: Date = .now) {
        guard mode != selectedMode else { return }

        let previousMode = selectedMode
        selectedMode = mode
        persistConfiguration()

        guard let timerState else { return }
        let next = engine.changeMode(mode, for: timerState)
        guard next != timerState else { return }

        guard apply(next, modelContext: modelContext, now: now) else {
            selectedMode = previousMode
            persistConfiguration()
            return
        }
    }

    func stop(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        if timerState.phase == .breakTime {
            _ = completeBreak(modelContext: modelContext, now: now)
            return
        }

        guard !discardShortFlowIfNeeded(timerState, modelContext: modelContext, now: now) else { return }
        stateBeforeResultPrompt = timerState
        _ = apply(engine.finish(timerState, now: now), modelContext: modelContext, now: now)
    }

    func destroy(modelContext: ModelContext, now: Date = .now) {
        if isBreakPhase {
            if let activeSession {
                do {
                    if let flowBreak = try openBreak(for: activeSession.id, modelContext: modelContext) {
                        flowBreak.deletedAt = now
                        flowBreak.updatedAt = now
                    }
                } catch {
                    PersistenceIssueCenter.shared.report(error, operation: .dataLoad)
                    return
                }
                activeSession.complete(now: now)
            }
        } else if let activeSession {
            if didApplyProgress {
                do {
                    try historyEditor.delete(session: activeSession, modelContext: modelContext, now: now)
                } catch {
                    modelContext.rollback()
                    PersistenceIssueCenter.shared.report(error, operation: .flowDelete)
                    return
                }
            } else {
                modelContext.delete(activeSession)
            }
        }

        guard modelContext.saveReporting(.flowDelete) else { return }
        activeSession = nil
        timerState = nil
        flowBreakInteraction = nil
        didApplyProgress = false
        isAwaitingBreakMemo = false
        stateBeforeResultPrompt = nil
        lastAppliedRuntimeVersion = nil
        notifications.cancelPendingFlowNotifications()
        liveActivities.end()
    }

    func skipBreak(modelContext: ModelContext, now: Date = .now) {
        guard let timerState else { return }
        guard timerState.phase == .breakTime else { return }
        _ = completeBreak(modelContext: modelContext, now: now)
    }

    func startNextFlow(
        direction: Direction,
        todo: Todo?,
        modelContext: ModelContext,
        now: Date = .now
    ) {
        guard timerState?.phase == .breakTime else { return }

        guard completeBreak(modelContext: modelContext, now: now) else { return }
        configure(direction: direction, todo: todo)
        start(direction: direction, todo: todo, modelContext: modelContext, now: now)
    }

    @discardableResult
    private func completeBreak(modelContext: ModelContext, now: Date) -> Bool {
        guard let timerState else { return false }
        if let activeSession {
            do {
                try openBreak(for: activeSession.id, modelContext: modelContext)?.stopTimer(at: now)
            } catch {
                PersistenceIssueCenter.shared.report(error, operation: .dataLoad)
                return false
            }
        }
        guard apply(
            engine.skipBreak(timerState, now: now),
            modelContext: modelContext,
            now: now
        ) else { return false }
        activeSession = nil
        self.timerState = nil
        flowBreakInteraction = nil
        didApplyProgress = false
        isAwaitingBreakMemo = false
        lastAppliedRuntimeVersion = nil
        liveActivities.end()
        return true
    }

    @discardableResult
    private func beginBreak(
        from state: FlowTimerState,
        modelContext: ModelContext,
        now: Date
    ) -> Bool {
        guard let activeSession else { return false }

        let focusedSeconds = engine.actualFocusDuration(for: state, now: now)
        let seriesID = activeSession.seriesID ?? activeSession.id
        let storedSessions: [FlowSession]
        let storedBreaks: [FlowBreak]
        do {
            storedSessions = try sessions(modelContext: modelContext)
            storedBreaks = try flowBreaks(modelContext: modelContext)
        } catch {
            PersistenceIssueCenter.shared.report(error, operation: .dataLoad)
            return false
        }
        let priorSeriesSeconds = storedSessions
            .filter { $0.id != activeSession.id && ($0.seriesID ?? $0.id) == seriesID }
            .reduce(0) { $0 + $1.resolvedActualFocusDurationSeconds }
        let completedLongBreaks = storedBreaks
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
        guard apply(next, modelContext: modelContext, now: now) else { return false }
        publishFlowBreakInteraction(.started(isLong: usesLongBreak), at: now)
        TaskCompletionFeedbackPlayer.shared.playFlow(for: activeSession.id, now: now)
        return true
    }

    private func publishFlowBreakInteraction(
        _ kind: FlowBreakInteraction.Kind,
        at date: Date
    ) {
        nextFlowBreakInteractionSequence &+= 1
        flowBreakInteraction = FlowBreakInteraction(
            sequence: nextFlowBreakInteractionSequence,
            kind: kind,
            occurredAt: date
        )
    }

    private func eligiblePendingBreak(modelContext: ModelContext, at date: Date) throws -> FlowBreak? {
        try flowBreaks(modelContext: modelContext)
            .filter { flowBreak in
                flowBreak.timerStoppedAt != nil && seriesPolicy.canContinueSeries(after: flowBreak, at: date)
            }
            .max { $0.startedAt < $1.startedAt }
    }

    private func openBreak(for sessionID: UUID, modelContext: ModelContext) throws -> FlowBreak? {
        try flowBreaks(modelContext: modelContext)
            .filter {
                $0.previousSessionID == sessionID &&
                    $0.timerStoppedAt == nil &&
                    !$0.isDeleted
            }
            .max { $0.startedAt < $1.startedAt }
    }

    private func sessions(modelContext: ModelContext) throws -> [FlowSession] {
        try modelContext.fetch(FetchDescriptor<FlowSession>())
    }

    private func flowBreaks(modelContext: ModelContext) throws -> [FlowBreak] {
        try modelContext.fetch(FetchDescriptor<FlowBreak>())
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

    func clearNotificationBadge() {
        notifications.clearBadge()
    }

    @discardableResult
    private func apply(_ state: FlowTimerState, modelContext: ModelContext, now: Date) -> Bool {
        guard state != timerState else { return true }

        let previousState = timerState
        let previousDidApplyProgress = didApplyProgress
        timerState = state
        activeSession?.apply(timerState: state, now: now)

        if state.phase == .breakTime || state.phase == .awaitingResult || state.phase == .completed {
            let focusedSeconds = state.actualFocusDurationSeconds ?? engine.actualFocusDuration(for: state, now: now)
            closeCurrentSegment(at: now, totalFocusSeconds: focusedSeconds)
            do {
                try applyProgressIfNeeded(modelContext: modelContext, now: now)
            } catch {
                modelContext.rollback()
                timerState = previousState
                didApplyProgress = previousDidApplyProgress
                PersistenceIssueCenter.shared.report(error, operation: .flowUpdate)
                return false
            }
        }

        guard modelContext.saveReporting(.flowUpdate) else {
            timerState = previousState
            didApplyProgress = previousDidApplyProgress
            return false
        }
        replaceNotifications(for: state)
        lastAppliedRuntimeVersion = activeSession?.runtimeVersion
        synchronizeLiveActivity(now: now)
        return true
    }

    private func adopt(
        session: FlowSession,
        timerState: FlowTimerState,
        now: Date
    ) {
        notifications.cancelPendingFlowNotifications()
        activeSession = session
        self.timerState = timerState
        flowBreakInteraction = nil
        selectedDirectionID = session.direction?.id
        selectedTodoID = session.todo?.id
        selectedMode = timerState.mode
        intent = session.intent
        didApplyProgress = timerState.phase == .breakTime ||
            (timerState.phase == .paused && timerState.phaseBeforePause == .breakTime)
        isAwaitingBreakMemo = false
        stateBeforeResultPrompt = nil
        lastAppliedRuntimeVersion = session.runtimeVersion
        persistConfiguration()

        if timerState.phase == .focusing || timerState.phase == .breakTime {
            scheduleNotifications(for: timerState)
        }
        synchronizeLiveActivity(now: now)
    }

    private func clearSynchronizedRuntimeIfNeeded() {
        guard timerState != nil else { return }
        guard timerState?.phase != .awaitingResult, !isAwaitingBreakMemo else { return }

        notifications.cancelPendingFlowNotifications()
        activeSession = nil
        timerState = nil
        flowBreakInteraction = nil
        didApplyProgress = false
        lastAppliedRuntimeVersion = nil
        liveActivities.end()
    }

    private func scheduleNotifications(for state: FlowTimerState) {
        switch state.phase {
        case .focusing:
            notifications.scheduleFocusFinished(
                mode: state.mode,
                focusedSeconds: state.plannedFocusDurationSeconds,
                fireDate: state.plannedEndAt
            )
            notifications.scheduleRunningTooLong(
                phase: .focus,
                fireDate: runningTooLongReminderDate(for: state)
            )
        case .breakTime:
            notifications.scheduleBreakFinished(fireDate: state.plannedEndAt)
            notifications.scheduleRunningTooLong(
                phase: .breakTime,
                fireDate: runningTooLongReminderDate(for: state)
            )
        default:
            break
        }
    }

    private func replaceNotifications(for state: FlowTimerState) {
        notifications.cancelPendingFlowNotifications()
        scheduleNotifications(for: state)
    }

    private func runningTooLongReminderDate(for state: FlowTimerState) -> Date {
        let plannedDuration = state.phase == .breakTime
            ? state.plannedBreakDurationSeconds
            : state.plannedFocusDurationSeconds
        let activePhaseStart = state.plannedEndAt.addingTimeInterval(-TimeInterval(plannedDuration))
        return activePhaseStart.addingTimeInterval(TimeInterval(Self.forgottenTimerReminderSeconds))
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
                self?.refreshLiveActivityTimeBoundary(now: date)
            }
    }

    private func applyProgressIfNeeded(modelContext: ModelContext, now: Date) throws {
        guard !didApplyProgress else { return }

        if let activeSession {
            try progressReconciler.reconcile(
                session: activeSession,
                modelContext: modelContext,
                now: now
            )
        }
        didApplyProgress = true
    }

    private func closeCurrentSegment(at date: Date, totalFocusSeconds: Int) {
        activeSession?.resolvedSegments
            .last(where: { $0.endedAt == nil })?
            .close(at: date, totalFocusSeconds: totalFocusSeconds)
    }

    private func openSegment(
        direction: Direction,
        todo: Todo?,
        session: FlowSession,
        modelContext: ModelContext,
        now: Date,
        startFocusSeconds: Int
    ) {
        let segment = FlowSegment(
            session: session,
            direction: direction,
            todo: todo,
            startedAt: now,
            startFocusSeconds: startFocusSeconds
        )
        modelContext.insert(segment)
        if !session.resolvedSegments.contains(where: { $0.id == segment.id }) {
            session.resolvedSegments.append(segment)
        }
    }

    private func transferCurrentSegment(
        _ currentSegment: FlowSegment,
        to direction: Direction,
        todo: Todo?,
        session: FlowSession,
        modelContext: ModelContext
    ) {
        let previousSegment = session.resolvedSegments
            .filter { $0.id != currentSegment.id && $0.endedAt != nil }
            .max { $0.startedAt < $1.startedAt }

        if previousSegment?.direction?.id == direction.id,
           previousSegment?.todo?.id == todo?.id,
           let previousSegment {
            session.resolvedSegments.removeAll { $0.id == currentSegment.id }
            modelContext.delete(currentSegment)
            previousSegment.reopen()
            return
        }

        currentSegment.direction = direction
        currentSegment.todo = todo
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

        guard modelContext.saveReporting(.flowDelete) else { return true }
        activeSession = nil
        timerState = nil
        didApplyProgress = false
        isAwaitingBreakMemo = false
        stateBeforeResultPrompt = nil
        lastAppliedRuntimeVersion = nil
        notifications.cancelPendingFlowNotifications()
        liveActivities.end()
        return true
    }

    private func startLiveActivity(now: Date) {
        guard let content = liveActivityContent(now: now) else {
            lastPublishedLiveActivityWasOvertime = nil
            liveActivities.end()
            return
        }
        lastPublishedLiveActivityWasOvertime = content.remainingSeconds < 0
        liveActivities.start(content: content)
    }

    private func synchronizeLiveActivity(now: Date) {
        guard let content = liveActivityContent(now: now) else {
            lastPublishedLiveActivityWasOvertime = nil
            liveActivities.end()
            return
        }
        lastPublishedLiveActivityWasOvertime = content.remainingSeconds < 0
        liveActivities.update(content: content)
    }

    func refreshLiveActivityTimeBoundary(now: Date = .now) {
        guard let content = liveActivityContent(now: now) else {
            lastPublishedLiveActivityWasOvertime = nil
            return
        }

        let isOvertime = content.remainingSeconds < 0
        guard lastPublishedLiveActivityWasOvertime != isOvertime else { return }

        lastPublishedLiveActivityWasOvertime = isOvertime
        liveActivities.update(content: content)
    }

    func liveActivityContent(now: Date = .now) -> FlowLiveActivityContent? {
        guard let state = timerState, let activeSession else { return nil }

        let status: FlowLiveActivityStatus
        let timerKind: FlowLiveActivityTimerKind
        switch state.phase {
        case .focusing, .awaitingExtensionDecision:
            status = .focus
            timerKind = .focus
        case .breakTime:
            status = .breakTime
            timerKind = .breakTime
        case .paused:
            status = .paused
            timerKind = state.phaseBeforePause == .breakTime ? .breakTime : .focus
        case .idle, .configured, .awaitingResult, .completed:
            return nil
        }

        let currentSegment = activeSession.resolvedSegments.last(where: { $0.endedAt == nil })
        let direction = currentSegment?.direction ?? activeSession.direction
        let todo = currentSegment?.todo ?? activeSession.todo
        let directionName = direction?.name ?? String(localized: "その他")
        let trimmedTitle = todo?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let duration = timerKind == .breakTime
            ? state.plannedBreakDurationSeconds
            : state.plannedFocusDurationSeconds
        let timerStartedAt = timerKind == .breakTime
            ? (state.breakStartedAt ?? state.plannedEndAt.addingTimeInterval(-Double(duration)))
            : state.plannedEndAt.addingTimeInterval(-Double(duration))

        return FlowLiveActivityContent(
            sessionID: activeSession.id,
            taskEmoji: direction?.symbolName ?? "📝",
            taskTitle: trimmedTitle.isEmpty ? directionName : trimmedTitle,
            directionEmoji: direction?.symbolName ?? "📝",
            directionName: directionName,
            directionColorHex: direction?.colorHex ?? "#007AFF",
            modeRawValue: state.mode.rawValue,
            modeName: state.mode.displayName,
            status: status,
            timerKind: timerKind,
            timerStartedAt: timerStartedAt,
            plannedEndAt: state.plannedEndAt,
            remainingSeconds: engine.remainingSeconds(for: state, now: now),
            progress: phaseProgress(now: now),
            updatedAt: now
        )
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

private enum ActiveFlowPersistenceEvent {
    static func completedCloudKitImportDate(from notification: Notification) -> Date? {
        guard let event = notification.userInfo?[
            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
        ] as? NSPersistentCloudKitContainer.Event,
        event.type == .import,
        let endDate = event.endDate,
        event.succeeded else {
            return nil
        }

        return endDate
    }
}

extension Notification.Name {
    static let flowDidComplete = Notification.Name("com.shigorefu.thruflow.flowDidComplete")
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
        return FlowMode.persistedMode(rawValue: value)
    }
}
