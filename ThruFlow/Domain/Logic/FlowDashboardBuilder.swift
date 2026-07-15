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
    let breaks: [FlowDashboardBreak]
    let seriesSpans: [FlowDashboardSeriesSpan]
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
    let seriesID: UUID
    let storedSegment: FlowSegment?
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

struct FlowDashboardBreak: Identifiable {
    let id: UUID
    let storedBreak: FlowBreak
    let seriesID: UUID
    let startedAt: Date
    let endedAt: Date
    let plannedDurationSeconds: Int
    let isLongBreak: Bool
    let isActive: Bool

    var durationSeconds: Int {
        max(0, Int(endedAt.timeIntervalSince(startedAt)))
    }
}

struct FlowDashboardSeriesSpan: Identifiable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
}

enum FlowTimelineMode: String, CaseIterable, Identifiable {
    case elastic
    case fullDay

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .elastic:
            "Elastic"
        case .fullDay:
            "24時間"
        }
    }
}

struct FlowTimelineRange: Equatable {
    let start: Date
    let end: Date

    init(
        mode: FlowTimelineMode,
        date: Date,
        segments: [FlowDashboardSegment],
        breaks: [FlowDashboardBreak] = [],
        calendar: Calendar = .current
    ) {
        switch mode {
        case .fullDay:
            start = calendar.startOfDay(for: date)
            end = calendar.date(byAdding: .day, value: 1, to: start)
                ?? start.addingTimeInterval(86_400)
        case .elastic:
            let firstDate = (segments.map(\.startedAt) + breaks.map(\.startedAt)).min() ?? date
            let lastDate = (segments.map(\.endedAt) + breaks.map(\.endedAt)).max() ?? date
            let firstHour = calendar.dateInterval(of: .hour, for: firstDate)
            let lastHour = calendar.dateInterval(of: .hour, for: lastDate)
            let resolvedStart = firstHour?.start ?? firstDate
            let minimumEnd = calendar.date(byAdding: .hour, value: 2, to: resolvedStart)
                ?? resolvedStart.addingTimeInterval(7_200)
            let resolvedEnd = lastHour?.end ?? lastDate

            start = resolvedStart
            end = max(resolvedEnd, minimumEnd)
        }
    }

    var duration: TimeInterval {
        max(end.timeIntervalSince(start), 1)
    }

    func fraction(for date: Date) -> Double {
        min(max(date.timeIntervalSince(start) / duration, 0), 1)
    }

    func labelDates(calendar: Calendar = .current) -> [Date] {
        let hours = max(1, Int(ceil(duration / 3_600)))
        let step = max(1, Int(ceil(Double(hours) / 4)))
        var labels = stride(from: 0, to: hours, by: step).compactMap {
            calendar.date(byAdding: .hour, value: $0, to: start)
        }

        if labels.last != end {
            labels.append(end)
        }
        return labels
    }
}

@MainActor
struct FlowDashboardTodoSorter {
    func sorted(_ todos: [Todo]) -> [Todo] {
        todos.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted
            }

            let lhsPriority = priorityRank(lhs)
            let rhsPriority = priorityRank(rhs)
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }

            if lhs.sortIndex != rhs.sortIndex {
                return lhs.sortIndex < rhs.sortIndex
            }

            return lhs.createdAt < rhs.createdAt
        }
    }

    private func priorityRank(_ todo: Todo) -> Int {
        switch todo.priority {
        case .high:
            0
        case .medium:
            1
        case .low:
            todo.isRoomIfPossible ? 3 : 2
        }
    }
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
        breaks storedBreaks: [FlowBreak] = [],
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
                        storedSegment: segment,
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
                storedSegment: nil,
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

        let sessionIDs = Set(segments.map { $0.session.id })
        let breaks = storedBreaks.compactMap { flowBreak -> FlowDashboardBreak? in
            guard !flowBreak.isDeleted,
                  calendar.isDate(flowBreak.startedAt, inSameDayAs: day),
                  sessionIDs.contains(flowBreak.previousSessionID) else {
                return nil
            }

            let end = flowBreak.resolvedEndAt(referenceDate: date)
            guard end > flowBreak.startedAt else { return nil }

            return FlowDashboardBreak(
                id: flowBreak.id,
                storedBreak: flowBreak,
                seriesID: flowBreak.seriesID,
                startedAt: flowBreak.startedAt,
                endedAt: min(end, nextDay),
                plannedDurationSeconds: flowBreak.plannedDurationSeconds,
                isLongBreak: flowBreak.isLongBreak,
                isActive: flowBreak.timerStoppedAt == nil
            )
        }
        .sorted { $0.startedAt < $1.startedAt }

        let seriesSpans = Dictionary(grouping: segments, by: \.seriesID)
            .compactMap { seriesID, values -> FlowDashboardSeriesSpan? in
                let seriesBreaks = breaks.filter { $0.seriesID == seriesID }
                guard !seriesBreaks.isEmpty,
                      let first = values.map(\.startedAt).min(),
                      let last = values.map(\.endedAt).max() else {
                    return nil
                }

                return FlowDashboardSeriesSpan(
                    id: seriesID,
                    startedAt: min(first, seriesBreaks.map(\.startedAt).min() ?? first),
                    endedAt: max(last, seriesBreaks.map(\.endedAt).max() ?? last)
                )
            }
            .sorted { $0.startedAt < $1.startedAt }

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
            breaks: breaks,
            seriesSpans: seriesSpans,
            palette: groupedColors.map(\.colorHex)
        )
    }

    private func dashboardSegment(
        id: UUID,
        session: FlowSession,
        storedSegment: FlowSegment?,
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
            seriesID: session.seriesID ?? session.id,
            storedSegment: storedSegment,
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
