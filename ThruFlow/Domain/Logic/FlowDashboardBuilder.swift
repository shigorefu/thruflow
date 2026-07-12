//
//  FlowDashboardBuilder.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/12.
//

import Foundation

struct FlowDashboardSnapshot {
    let date: Date
    let totalFocusSeconds: Int
    let flowCount: Int
    let segments: [FlowDashboardSegment]
    let palette: [String]

    var blocks: Double {
        BlockUnit.blocks(forFocusedSeconds: totalFocusSeconds)
    }

    var intensity: Double {
        min(max(Double(totalFocusSeconds) / Double(4 * 60 * 60), 0), 1)
    }
}

struct FlowDashboardSegment: Identifiable {
    let id: UUID
    let session: FlowSession
    let startFraction: Double
    let endFraction: Double
    let focusSeconds: Int
    let colorHex: String
    let symbol: String
    let taskTitle: String
    let isActive: Bool
}

@MainActor
struct FlowDashboardBuilder {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func build(
        date: Date,
        sessions: [FlowSession],
        activeSessionID: UUID? = nil,
        activeFocusSeconds: Int = 0
    ) -> FlowDashboardSnapshot {
        let day = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        let dayDuration = max(nextDay.timeIntervalSince(day), 1)

        let segments = sessions.compactMap { session -> FlowDashboardSegment? in
            guard calendar.isDate(session.startedAt, inSameDayAs: day),
                  session.status != .interrupted else {
                return nil
            }

            let isActive = session.id == activeSessionID
            let resolvedFocusSeconds = isActive
                ? max(session.resolvedActualFocusDurationSeconds, activeFocusSeconds)
                : session.resolvedActualFocusDurationSeconds
            let focusSeconds = isActive && resolvedFocusSeconds < FlowTimerEngine.minimumCreditableFocusDurationSeconds
                ? 0
                : resolvedFocusSeconds
            guard focusSeconds > 0 else { return nil }

            let start = min(max(session.startedAt.timeIntervalSince(day) / dayDuration, 0), 1)
            let endDate = isActive && session.endedAt == nil
                ? date
                : (session.endedAt ?? session.startedAt.addingTimeInterval(TimeInterval(focusSeconds)))
            let end = min(max(endDate.timeIntervalSince(day) / dayDuration, start), 1)
            let direction = session.direction

            return FlowDashboardSegment(
                id: session.id,
                session: session,
                startFraction: start,
                endFraction: min(1, max(end, start + (1 / dayDuration))),
                focusSeconds: focusSeconds,
                colorHex: direction?.colorHex ?? "#8E8E93",
                symbol: direction?.symbolName ?? "📥",
                taskTitle: session.todo.map(TodoDisplay.title(for:)) ?? "(\(direction?.name ?? "その他"))",
                isActive: isActive
            )
        }
        .sorted { $0.startFraction < $1.startFraction }

        let totalFocusSeconds = segments.reduce(0) { $0 + $1.focusSeconds }
        let groupedColors = Dictionary(grouping: segments, by: \FlowDashboardSegment.colorHex)
            .map { colorHex, values in
                (colorHex: colorHex, seconds: values.reduce(0) { $0 + $1.focusSeconds })
            }
            .sorted { $0.seconds > $1.seconds }

        return FlowDashboardSnapshot(
            date: day,
            totalFocusSeconds: totalFocusSeconds,
            flowCount: segments.count,
            segments: segments,
            palette: groupedColors.map(\.colorHex)
        )
    }
}
