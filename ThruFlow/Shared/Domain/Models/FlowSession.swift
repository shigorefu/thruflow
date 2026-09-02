//
//  FlowSession.swift
//  ThruFlow
//
//

import Foundation
import SwiftData

enum FlowMode: String, CaseIterable, Codable, Identifiable {
    case sprint
    case twentyFiveFive
    case fiftyTen
    case adaptive

    private static let legacySprintRawValue = "twelveThree"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sprint:
            String(localized: "Sprint")
        case .twentyFiveFive:
            String(localized: "Focus")
        case .fiftyTen:
            String(localized: "Deep")
        case .adaptive:
            String(localized: "オート")
        }
    }

    var initialFocusDurationSeconds: Int {
        switch self {
        case .sprint, .adaptive:
            12 * 60
        case .twentyFiveFive:
            25 * 60
        case .fiftyTen:
            50 * 60
        }
    }

    var breakDurationSeconds: Int {
        switch self {
        case .sprint, .adaptive:
            3 * 60
        case .twentyFiveFive:
            5 * 60
        case .fiftyTen:
            10 * 60
        }
    }

    var blockSummary: String {
        switch self {
        case .sprint:
            String(localized: "12分集中 / 3分休憩")
        case .twentyFiveFive:
            String(localized: "25分集中 / 5分休憩")
        case .fiftyTen:
            String(localized: "50分集中 / 10分休憩")
        case .adaptive:
            String(localized: "12分から開始")
        }
    }

    var compactDurationText: String {
        switch self {
        case .sprint, .adaptive:
            "12/3"
        case .twentyFiveFive:
            "25/5"
        case .fiftyTen:
            "50/10"
        }
    }

    static func persistedMode(rawValue: String) -> FlowMode? {
        if rawValue == legacySprintRawValue {
            return .sprint
        }
        return FlowMode(rawValue: rawValue)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let mode = Self.persistedMode(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown FlowMode raw value: \(rawValue)"
            )
        }
        self = mode
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    static func adaptiveBreakDurationSeconds(forFocusSeconds seconds: Int) -> Int {
        switch seconds {
        case (49 * 60)...:
            return 10 * 60
        case (24 * 60)...:
            return 5 * 60
        default:
            return 3 * 60
        }
    }
}

enum FlowPhase: String, CaseIterable, Codable, Identifiable {
    case idle
    case configured
    case focusing
    case paused
    case breakTime
    case awaitingExtensionDecision
    case awaitingResult
    case completed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .idle:
            String(localized: "未設定")
        case .configured:
            String(localized: "準備完了")
        case .focusing:
            String(localized: "集中")
        case .paused:
            String(localized: "一時停止中のFlow")
        case .breakTime:
            String(localized: "休憩")
        case .awaitingExtensionDecision:
            String(localized: "次を選択")
        case .awaitingResult:
            String(localized: "結果を入力")
        case .completed:
            String(localized: "集中完了")
        }
    }
}

enum FlowSessionStatus: String, CaseIterable, Codable, Identifiable {
    case active
    case paused
    case breakTime
    case awaitingResult
    case completed
    case interrupted

    var id: String { rawValue }
}

@Model
final class FlowSession {
    var id: UUID = UUID()
    var seriesID: UUID?
    /// Persisted as `direction` for SwiftData and CloudKit compatibility.
    var direction: Area?
    var todo: Todo?
    var intent: String = ""
    var result: String?
    var modeRawValue: String = FlowMode.twentyFiveFive.rawValue
    var phaseRawValue: String = FlowPhase.focusing.rawValue
    var statusRawValue: String = FlowSessionStatus.active.rawValue
    var startedAt: Date = Date.now
    var plannedEndAt: Date = Date.now
    var endedAt: Date?
    var plannedFocusDurationSeconds: Int = 0
    var actualFocusDurationSeconds: Int?
    var plannedBreakDurationSeconds: Int = 0
    var accumulatedPauseDurationSeconds: Int = 0
    var pausedAt: Date?
    var phaseBeforePauseRawValue: String?
    var completedAt: Date?
    var breakStartedAt: Date?
    var wasPaused: Bool = false
    var interruptionCount: Int = 0
    var runtimeRevision: Int = 0
    var runtimeMutationID: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    @Relationship(deleteRule: .cascade, inverse: \FlowSegment.session)
    var segments: [FlowSegment]?

    init(
        id: UUID = UUID(),
        seriesID: UUID? = nil,
        area: Area,
        todo: Todo? = nil,
        intent: String = "",
        result: String? = nil,
        mode: FlowMode,
        phase: FlowPhase = .focusing,
        status: FlowSessionStatus = .active,
        startedAt: Date,
        plannedEndAt: Date,
        endedAt: Date? = nil,
        plannedFocusDurationSeconds: Int,
        actualFocusDurationSeconds: Int? = nil,
        plannedBreakDurationSeconds: Int,
        accumulatedPauseDurationSeconds: Int = 0,
        pausedAt: Date? = nil,
        phaseBeforePause: FlowPhase? = nil,
        completedAt: Date? = nil,
        breakStartedAt: Date? = nil,
        wasPaused: Bool = false,
        interruptionCount: Int = 0,
        runtimeRevision: Int = 1,
        runtimeMutationID: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.seriesID = seriesID ?? id
        self.direction = area
        self.todo = todo
        self.intent = intent
        self.result = result
        self.modeRawValue = mode.rawValue
        self.phaseRawValue = phase.rawValue
        self.statusRawValue = status.rawValue
        self.startedAt = startedAt
        self.plannedEndAt = plannedEndAt
        self.endedAt = endedAt
        self.plannedFocusDurationSeconds = plannedFocusDurationSeconds
        self.actualFocusDurationSeconds = actualFocusDurationSeconds
        self.plannedBreakDurationSeconds = plannedBreakDurationSeconds
        self.accumulatedPauseDurationSeconds = accumulatedPauseDurationSeconds
        self.pausedAt = pausedAt
        self.phaseBeforePauseRawValue = phaseBeforePause?.rawValue
        self.completedAt = completedAt
        self.breakStartedAt = breakStartedAt
        self.wasPaused = wasPaused
        self.interruptionCount = interruptionCount
        self.runtimeRevision = runtimeRevision
        self.runtimeMutationID = runtimeMutationID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var area: Area? {
        get { direction }
        set { direction = newValue }
    }

    var resolvedSegments: [FlowSegment] {
        get { segments ?? [] }
        set { segments = newValue }
    }

    var mode: FlowMode {
        get { FlowMode.persistedMode(rawValue: modeRawValue) ?? .adaptive }
        set { modeRawValue = newValue.rawValue }
    }

    var phase: FlowPhase {
        get { FlowPhase(rawValue: phaseRawValue) ?? .idle }
        set { phaseRawValue = newValue.rawValue }
    }

    var status: FlowSessionStatus {
        get { FlowSessionStatus(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
    }

    var phaseBeforePause: FlowPhase? {
        get {
            phaseBeforePauseRawValue.flatMap(FlowPhase.init(rawValue:))
        }
        set {
            phaseBeforePauseRawValue = newValue?.rawValue
        }
    }

    var runtimeVersion: FlowRuntimeVersion {
        FlowRuntimeVersion(
            updatedAt: updatedAt,
            revision: runtimeRevision,
            mutationID: runtimeMutationID
        )
    }

    var reconstructableTimerState: FlowTimerState? {
        guard status != .completed,
              status != .interrupted,
              phase == .focusing ||
                phase == .paused ||
                phase == .breakTime ||
                phase == .awaitingExtensionDecision else {
            return nil
        }

        let resolvedPhaseBeforePause: FlowPhase?
        let resolvedPausedAt: Date?
        if phase == .paused {
            resolvedPhaseBeforePause = phaseBeforePause ?? .focusing
            resolvedPausedAt = pausedAt ?? updatedAt
        } else {
            resolvedPhaseBeforePause = phaseBeforePause
            resolvedPausedAt = pausedAt
        }

        let resolvedBreakStartedAt: Date?
        if phase == .breakTime ||
            (phase == .paused && resolvedPhaseBeforePause == .breakTime) {
            resolvedBreakStartedAt = breakStartedAt ??
                plannedEndAt.addingTimeInterval(-TimeInterval(plannedBreakDurationSeconds))
        } else {
            resolvedBreakStartedAt = breakStartedAt
        }

        return FlowTimerState(
            mode: mode,
            phase: phase,
            startedAt: startedAt,
            plannedEndAt: plannedEndAt,
            pausedAt: resolvedPausedAt,
            phaseBeforePause: resolvedPhaseBeforePause,
            accumulatedPauseDurationSeconds: accumulatedPauseDurationSeconds,
            completedAt: completedAt,
            endedAt: endedAt,
            plannedFocusDurationSeconds: plannedFocusDurationSeconds,
            actualFocusDurationSeconds: actualFocusDurationSeconds,
            plannedBreakDurationSeconds: plannedBreakDurationSeconds,
            breakStartedAt: resolvedBreakStartedAt,
            wasPaused: wasPaused,
            interruptionCount: interruptionCount
        )
    }

    var resolvedActualFocusDurationSeconds: Int {
        if let actualFocusDurationSeconds {
            return actualFocusDurationSeconds
        }

        guard let endedAt else { return 0 }
        let elapsed = max(0, Int(endedAt.timeIntervalSince(startedAt)))
        return min(plannedFocusDurationSeconds, max(0, elapsed - accumulatedPauseDurationSeconds))
    }

    func apply(timerState: FlowTimerState, now: Date = .now) {
        mode = timerState.mode
        phase = timerState.phase
        status = FlowSessionStatus(phase: timerState.phase)
        plannedEndAt = timerState.plannedEndAt
        endedAt = timerState.endedAt
        plannedFocusDurationSeconds = timerState.plannedFocusDurationSeconds
        actualFocusDurationSeconds = timerState.actualFocusDurationSeconds
        plannedBreakDurationSeconds = timerState.plannedBreakDurationSeconds
        accumulatedPauseDurationSeconds = timerState.accumulatedPauseDurationSeconds
        pausedAt = timerState.pausedAt
        phaseBeforePause = timerState.phaseBeforePause
        completedAt = timerState.completedAt
        breakStartedAt = timerState.breakStartedAt
        wasPaused = timerState.wasPaused
        interruptionCount = timerState.interruptionCount
        recordRuntimeMutation(now: now)
    }

    func complete(now: Date = .now) {
        phase = .completed
        status = .completed
        completedAt = completedAt ?? now
        recordRuntimeMutation(now: now)
    }

    func recordRuntimeMutation(now: Date = .now) {
        runtimeRevision += 1
        runtimeMutationID = UUID()
        updatedAt = now
    }
}

struct FlowRuntimeVersion: Equatable, Comparable {
    var updatedAt: Date
    var revision: Int
    var mutationID: UUID

    static func < (lhs: FlowRuntimeVersion, rhs: FlowRuntimeVersion) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt < rhs.updatedAt
        }
        if lhs.revision != rhs.revision {
            return lhs.revision < rhs.revision
        }
        return lhs.mutationID.uuidString < rhs.mutationID.uuidString
    }
}

extension FlowSessionStatus {
    init(phase: FlowPhase) {
        switch phase {
        case .idle, .configured, .focusing, .awaitingExtensionDecision:
            self = .active
        case .paused:
            self = .paused
        case .breakTime:
            self = .breakTime
        case .awaitingResult:
            self = .awaitingResult
        case .completed:
            self = .completed
        }
    }
}
