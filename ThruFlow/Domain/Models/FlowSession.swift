//
//  FlowSession.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import Foundation
import SwiftData

enum FlowMode: String, CaseIterable, Codable, Identifiable {
    case twelveThree
    case twentyFiveFive
    case fiftyTen
    case adaptive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .twelveThree:
            "ウォームアップ"
        case .twentyFiveFive:
            "フォーカス"
        case .fiftyTen:
            "ディープ"
        case .adaptive:
            "オート"
        }
    }

    var initialFocusDurationSeconds: Int {
        switch self {
        case .twelveThree, .adaptive:
            12 * 60
        case .twentyFiveFive:
            25 * 60
        case .fiftyTen:
            50 * 60
        }
    }

    var breakDurationSeconds: Int {
        switch self {
        case .twelveThree, .adaptive:
            3 * 60
        case .twentyFiveFive:
            5 * 60
        case .fiftyTen:
            10 * 60
        }
    }

    var blockSummary: String {
        switch self {
        case .twelveThree:
            "12分集中 / 3分休憩"
        case .twentyFiveFive:
            "25分集中 / 5分休憩"
        case .fiftyTen:
            "50分集中 / 10分休憩"
        case .adaptive:
            "12分から開始"
        }
    }

    var shortDurationText: String {
        switch self {
        case .twelveThree, .adaptive:
            "12/3"
        case .twentyFiveFive:
            "25/5"
        case .fiftyTen:
            "50/10"
        }
    }

    static func adaptiveBreakDurationSeconds(forFocusSeconds seconds: Int) -> Int {
        switch seconds {
        case 50 * 60:
            return 10 * 60
        case 25 * 60:
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
            "未設定"
        case .configured:
            "準備完了"
        case .focusing:
            "集中"
        case .paused:
            "一時停止"
        case .breakTime:
            "休憩"
        case .awaitingExtensionDecision:
            "次を選択"
        case .awaitingResult:
            "結果を入力"
        case .completed:
            "完了"
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
    var id: UUID
    var direction: Direction?
    var todo: Todo?
    var intent: String
    var result: String?
    var modeRawValue: String
    var phaseRawValue: String
    var statusRawValue: String
    var startedAt: Date
    var plannedEndAt: Date
    var endedAt: Date?
    var plannedFocusDurationSeconds: Int
    var actualFocusDurationSeconds: Int?
    var plannedBreakDurationSeconds: Int
    var accumulatedPauseDurationSeconds: Int
    var wasPaused: Bool
    var interruptionCount: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        direction: Direction,
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
        wasPaused: Bool = false,
        interruptionCount: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.direction = direction
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
        self.wasPaused = wasPaused
        self.interruptionCount = interruptionCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var mode: FlowMode {
        get { FlowMode(rawValue: modeRawValue) ?? .adaptive }
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
        wasPaused = timerState.wasPaused
        interruptionCount = timerState.interruptionCount
        updatedAt = now
    }

    func setResult(_ result: String?, now: Date = .now) {
        let trimmed = result?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.result = trimmed?.isEmpty == true ? nil : trimmed
        phase = .completed
        status = .completed
        updatedAt = now
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
