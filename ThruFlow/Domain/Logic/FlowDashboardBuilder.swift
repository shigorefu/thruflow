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
        min(max(blocks / FlowVisualState.maximumGrowthBlocks, 0), 1)
    }

    var directionSummaries: [FlowDashboardDirectionSummary] {
        Dictionary(grouping: segments, by: \FlowDashboardSegment.directionID)
            .values
            .map { values in
                let first = values[0]
                return FlowDashboardDirectionSummary(
                    id: first.directionID,
                    symbol: first.symbol,
                    name: first.directionName,
                    colorHex: first.colorHex,
                    focusSeconds: values.reduce(0) { $0 + $1.focusSeconds }
                )
            }
            .sorted { $0.focusSeconds > $1.focusSeconds }
    }
}

struct FlowDashboardDirectionSummary: Identifiable {
    let id: UUID
    let symbol: String
    let name: String
    let colorHex: String
    let focusSeconds: Int
}

struct FlowDashboardSegment: Identifiable {
    let id: UUID
    let session: FlowSession
    let startedAt: Date
    let endedAt: Date
    let startFraction: Double
    let endFraction: Double
    let focusSeconds: Int
    let directionID: UUID
    let directionName: String
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

        let segments = sessions.flatMap { session -> [FlowDashboardSegment] in
            guard calendar.isDate(session.startedAt, inSameDayAs: day),
                  session.status != .interrupted else {
                return []
            }

            let isActive = session.id == activeSessionID
            let resolvedFocusSeconds = isActive
                ? max(session.resolvedActualFocusDurationSeconds, activeFocusSeconds)
                : session.resolvedActualFocusDurationSeconds

            if !session.segments.isEmpty {
                return session.segments.compactMap { segment in
                    let focusSeconds = segment.endFocusSeconds.map { max(0, $0 - segment.startFocusSeconds) }
                        ?? (isActive ? max(0, resolvedFocusSeconds - segment.startFocusSeconds) : 0)
                    guard focusSeconds > 0 else { return nil }

                    return dashboardSegment(
                        id: segment.id,
                        session: session,
                        direction: segment.direction,
                        todo: segment.todo,
                        startedAt: segment.startedAt,
                        endedAt: segment.endedAt ?? (isActive ? date : nil),
                        focusSeconds: focusSeconds,
                        isActive: isActive && segment.endedAt == nil,
                        day: day,
                        dayDuration: dayDuration
                    )
                }
            }

            let focusSeconds = isActive && resolvedFocusSeconds < FlowTimerEngine.minimumCreditableFocusDurationSeconds
                ? 0
                : resolvedFocusSeconds
            guard focusSeconds > 0 else { return [] }

            return [dashboardSegment(
                id: session.id,
                session: session,
                direction: session.direction,
                todo: session.todo,
                startedAt: session.startedAt,
                endedAt: isActive && session.endedAt == nil ? date : session.endedAt,
                focusSeconds: focusSeconds,
                isActive: isActive,
                day: day,
                dayDuration: dayDuration
            )]
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
            flowCount: Set(segments.map { $0.session.id }).count,
            segments: segments,
            palette: groupedColors.map(\.colorHex)
        )
    }

    private func dashboardSegment(
        id: UUID,
        session: FlowSession,
        direction: Direction?,
        todo: Todo?,
        startedAt: Date,
        endedAt: Date?,
        focusSeconds: Int,
        isActive: Bool,
        day: Date,
        dayDuration: TimeInterval
    ) -> FlowDashboardSegment {
        let start = min(max(startedAt.timeIntervalSince(day) / dayDuration, 0), 1)
        let resolvedEnd = endedAt ?? startedAt.addingTimeInterval(TimeInterval(focusSeconds))
        let end = min(max(resolvedEnd.timeIntervalSince(day) / dayDuration, start), 1)

        return FlowDashboardSegment(
            id: id,
            session: session,
            startedAt: startedAt,
            endedAt: resolvedEnd,
            startFraction: start,
            endFraction: min(1, max(end, start + (1 / dayDuration))),
            focusSeconds: focusSeconds,
            directionID: direction?.id ?? id,
            directionName: direction?.name ?? "その他",
            colorHex: direction?.colorHex ?? "#8E8E93",
            symbol: direction?.symbolName ?? "📥",
            taskTitle: todo.map(TodoDisplay.title(for:)) ?? "(\(direction?.name ?? "その他"))",
            isActive: isActive
        )
    }
}
