//
//  LiveActivityService.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
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
    var directionEmoji: String
    var directionName: String
    var directionColorHex: String
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

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
struct FlowLiveActivityRunningTimeFormatStyle: DiscreteFormatStyle {
    var plannedEndAt: Date

    nonisolated func format(_ value: Date) -> String {
        let remainingInterval = plannedEndAt.timeIntervalSince(value)
        let seconds: Int

        if remainingInterval > 0 {
            seconds = Int(ceil(remainingInterval))
        } else {
            seconds = -Int(floor(abs(remainingInterval)))
        }

        return FlowLiveActivityFormatter.timeText(
            seconds: seconds,
            allowsOvertime: true
        )
    }

    nonisolated func discreteInput(after input: Date) -> Date? {
        boundary(after: input)
    }

    nonisolated func discreteInput(before input: Date) -> Date? {
        boundary(before: input)
    }

    nonisolated func locale(_ locale: Locale) -> Self {
        self
    }

    private nonisolated func boundary(after input: Date) -> Date {
        let offset = input.timeIntervalSince(plannedEndAt)
        return plannedEndAt.addingTimeInterval(floor(offset) + 1)
    }

    private nonisolated func boundary(before input: Date) -> Date {
        let offset = input.timeIntervalSince(plannedEndAt)
        return plannedEndAt.addingTimeInterval(ceil(offset) - 1)
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

    nonisolated static func directionName(
        _ directionName: String,
        timerKind: FlowLiveActivityTimerKind
    ) -> String {
        timerKind == .breakTime ? "" : directionName
    }
}
