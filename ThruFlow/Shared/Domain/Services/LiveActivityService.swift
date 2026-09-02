//
//  LiveActivityService.swift
//  ThruFlow
//
//

import Foundation

enum FlowLiveActivityStatus: String, Codable, Equatable, Hashable {
    case focus
    case breakTime
    case paused
}

enum FlowLiveActivityTimerKind: String, Codable, Equatable, Hashable {
    case focus
    case breakTime
}

struct FlowLiveActivityContent: Equatable {
    var sessionID: UUID
    var taskEmoji: String
    var taskTitle: String
    var areaEmoji: String
    var areaName: String
    var areaColorHex: String
    var modeRawValue: String
    var modeName: String
    var status: FlowLiveActivityStatus
    var timerKind: FlowLiveActivityTimerKind
    var timerStartedAt: Date
    var plannedEndAt: Date
    var remainingSeconds: Int
    var progress: Double
    var updatedAt: Date
}

@MainActor
protocol LiveActivityService {
    func start(content: FlowLiveActivityContent)
    func update(content: FlowLiveActivityContent)
    func end()
}

@MainActor
struct NoopLiveActivityService: LiveActivityService {
    func start(content: FlowLiveActivityContent) {}
    func update(content: FlowLiveActivityContent) {}
    func end() {}
}

enum FlowLiveActivityFormatter {
    nonisolated static func timeText(
        seconds: Int,
        allowsOvertime: Bool = false
    ) -> String {
        if allowsOvertime, seconds < 0 {
            let overtimeSeconds = abs(seconds)
            return String(format: "+%02d:%02d", overtimeSeconds / 60, overtimeSeconds % 60)
        }

        let clampedSeconds = max(0, seconds)
        return String(format: "%02d:%02d", clampedSeconds / 60, clampedSeconds % 60)
    }
}

enum FlowLiveActivityPresentation {
    nonisolated static func emoji(
        taskEmoji: String,
        timerKind: FlowLiveActivityTimerKind
    ) -> String {
        timerKind == .breakTime ? "☕️" : taskEmoji
    }

    nonisolated static func title(
        taskTitle: String,
        timerKind: FlowLiveActivityTimerKind
    ) -> String {
        timerKind == .breakTime ? String(localized: "休憩") : taskTitle
    }

    nonisolated static func areaName(
        _ areaName: String,
        timerKind: FlowLiveActivityTimerKind
    ) -> String {
        timerKind == .breakTime ? "" : areaName
    }
}
