//
//  HistoryCalendarBuilder.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/14.
//

import Foundation

enum HistoryCalendarRange: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .day: String(localized: "日")
        case .week: String(localized: "週")
        case .month: String(localized: "月")
        }
    }

    func interval(
        containing date: Date,
        calendar: Calendar,
        dayBoundary: AppDayBoundary = .midnight
    ) -> DateInterval {
        let calendarInterval: DateInterval
        switch self {
        case .day:
            let start = calendar.startOfDay(for: date)
            calendarInterval = DateInterval(
                start: start,
                end: calendar.date(byAdding: .day, value: 1, to: start)!
            )
        case .week:
            calendarInterval = calendar.dateInterval(of: .weekOfYear, for: date)!
        case .month:
            calendarInterval = calendar.dateInterval(of: .month, for: date)!
        }

        return DateInterval(
            start: dayBoundary.interval(for: calendarInterval.start, calendar: calendar).start,
            end: dayBoundary.interval(for: calendarInterval.end, calendar: calendar).start
        )
    }

    func moving(_ date: Date, by value: Int, calendar: Calendar) -> Date {
        let component: Calendar.Component
        switch self {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        }
        return calendar.date(byAdding: component, value: value, to: date) ?? date
    }
}

enum HistoryDayTimelineScale: String, CaseIterable, Identifiable {
    case elastic
    case fullDay

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .elastic: String(localized: "Elastic")
        case .fullDay: String(localized: "24時間")
        }
    }
}

struct HistoryDayTimelineWindowBuilder {
    private let minimumHours = 4

    func hourRange(
        for date: Date,
        items: [HistoryCalendarItem],
        scale: HistoryDayTimelineScale,
        now: Date = .now,
        calendar: Calendar = .current,
        dayBoundary: AppDayBoundary = .midnight
    ) -> Range<Int> {
        guard scale == .elastic else { return 0..<24 }

        let dayInterval = HistoryCalendarRange.day.interval(
            containing: date,
            calendar: calendar,
            dayBoundary: dayBoundary
        )
        let timedItems = items.filter { item in
            item.startedAt < dayInterval.end
                && item.endedAt > dayInterval.start
        }
        var startHour = timedItems.map { item in
            calendar.component(.hour, from: max(item.startedAt, dayInterval.start))
        }.min()
        var endHour = timedItems.map { item in
            let end = min(max(item.endedAt, item.startedAt), dayInterval.end)
            if end == dayInterval.end { return 24 }
            let hour = calendar.component(.hour, from: end)
            let hasPartialHour = calendar.component(.minute, from: end) > 0
                || calendar.component(.second, from: end) > 0
            return hour + (hasPartialHour ? 1 : 0)
        }.max()

        if calendar.isDate(date, inSameDayAs: now) {
            let currentHour = calendar.component(.hour, from: now)
            startHour = min(startHour ?? currentHour, currentHour)
            endHour = max(endHour ?? currentHour + 1, currentHour + 1)
        }

        if startHour == nil || endHour == nil {
            startHour = 10
            endHour = 14
        } else {
            startHour = (startHour ?? 0) - 1
            endHour = (endHour ?? 24) + 1
        }

        var lower = max(0, startHour ?? 0)
        var upper = min(24, endHour ?? 24)
        if upper - lower < minimumHours {
            let missing = minimumHours - (upper - lower)
            lower = max(0, lower - missing / 2)
            upper = min(24, lower + minimumHours)
            lower = max(0, upper - minimumHours)
        }
        return lower..<max(lower + 1, upper)
    }
}

enum HistoryCalendarItemKind: String, CaseIterable, Hashable {
    case flow
    case rest
}

struct HistoryCalendarItem: Identifiable {
    let id: String
    let kind: HistoryCalendarItemKind
    let startedAt: Date
    let endedAt: Date
    let title: String
    let subtitle: String
    let symbol: String
    let colorHex: String
    let session: FlowSession?
    let flowBreak: FlowBreak?
    let todo: Todo?

    var durationSeconds: Int {
        max(0, Int(endedAt.timeIntervalSince(startedAt)))
    }

    var seriesID: UUID? {
        flowBreak?.seriesID ?? session.map { $0.seriesID ?? $0.id }
    }

    var seriesBlockID: String {
        seriesID.map { "series-\($0.uuidString)" } ?? "item-\(id)"
    }
}

struct HistoryCalendarSnapshot {
    let interval: DateInterval
    let items: [HistoryCalendarItem]
}

struct HistoryCalendarSeriesBlock: Identifiable {
    let id: String
    let seriesID: UUID?
    let startedAt: Date
    let endedAt: Date
    let items: [HistoryCalendarItem]
}

struct HistoryCalendarSeriesProjector {
    func project(_ items: [HistoryCalendarItem]) -> [HistoryCalendarSeriesBlock] {
        Dictionary(grouping: items, by: \.seriesBlockID)
            .map { id, values in
                let sorted = values.sorted {
                    if $0.startedAt == $1.startedAt { return $0.id < $1.id }
                    return $0.startedAt < $1.startedAt
                }
                return HistoryCalendarSeriesBlock(
                    id: id,
                    seriesID: sorted.first?.seriesID,
                    startedAt: sorted.map(\.startedAt).min() ?? .distantPast,
                    endedAt: sorted.map(\.endedAt).max() ?? .distantPast,
                    items: sorted
                )
            }
            .sorted {
                if $0.startedAt == $1.startedAt { return $0.id < $1.id }
                return $0.startedAt < $1.startedAt
            }
    }

    func placements(
        for blocks: [HistoryCalendarSeriesBlock]
    ) -> [String: HistoryOverlapPlacement] {
        let placements = HistoryOverlapLayout().place(blocks.map {
            HistoryOverlapInput(id: $0.id, start: $0.startedAt, end: $0.endedAt)
        })
        return Dictionary(uniqueKeysWithValues: placements.map { ($0.id, $0) })
    }
}

struct HistoryTimelineChainPolicy {
    var continuityTolerance: TimeInterval = 1

    func connects(_ previous: HistoryCalendarItem, to next: HistoryCalendarItem) -> Bool {
        guard previous.seriesBlockID == next.seriesBlockID else { return false }
        return next.startedAt <= previous.endedAt.addingTimeInterval(continuityTolerance)
    }
}

struct HistoryTimelineGap: Equatable {
    let startedAt: Date
    let endedAt: Date

    var duration: TimeInterval {
        endedAt.timeIntervalSince(startedAt)
    }
}

struct HistoryTimelineGapBuilder {
    func internalGaps(
        in interval: DateInterval,
        items: [HistoryCalendarItem],
        minimumDuration: TimeInterval = 60 * 60
    ) -> [HistoryTimelineGap] {
        let occupied = items
            .compactMap { item -> DateInterval? in
                let start = max(interval.start, item.startedAt)
                let end = min(interval.end, item.endedAt)
                guard end > start else { return nil }
                return DateInterval(start: start, end: end)
            }
            .sorted { $0.start < $1.start }

        guard occupied.count >= 2 else { return [] }

        var merged: [DateInterval] = []
        for candidate in occupied {
            guard let last = merged.last else {
                merged.append(candidate)
                continue
            }

            if candidate.start <= last.end {
                merged[merged.count - 1] = DateInterval(
                    start: last.start,
                    end: max(last.end, candidate.end)
                )
            } else {
                merged.append(candidate)
            }
        }

        return zip(merged, merged.dropFirst()).compactMap { previous, next in
            let gap = HistoryTimelineGap(startedAt: previous.end, endedAt: next.start)
            return gap.duration >= minimumDuration ? gap : nil
        }
    }
}

@MainActor
struct HistoryCalendarBuilder {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func build(
        interval: DateInterval,
        sessions: [FlowSession],
        breaks: [FlowBreak],
        referenceDate: Date = .now
    ) -> HistoryCalendarSnapshot {
        let visibleSessions = sessions.filter { session in
            session.status != .interrupted
                && session.resolvedActualFocusDurationSeconds > 0
                && overlaps(start: session.startedAt, end: resolvedEnd(of: session), interval: interval)
        }
        let sessionsByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })

        var items = visibleSessions.flatMap(makeFlowItems)
        items += breaks.compactMap { flowBreak in
            guard !flowBreak.isDeleted else { return nil }
            let end = flowBreak.resolvedEndAt(referenceDate: referenceDate)
            guard end > flowBreak.startedAt,
                  overlaps(start: flowBreak.startedAt, end: end, interval: interval) else { return nil }
            let previousSession = sessionsByID[flowBreak.previousSessionID]
            let direction = previousSession?.direction
            return HistoryCalendarItem(
                id: "rest-\(flowBreak.id.uuidString)",
                kind: .rest,
                startedAt: flowBreak.startedAt,
                endedAt: end,
                title: flowBreak.isLongBreak ? String(localized: "Long Break") : String(localized: "休憩"),
                subtitle: direction?.name ?? String(localized: "Flowシリーズ"),
                symbol: "☕️",
                colorHex: "#8E8E93",
                session: previousSession,
                flowBreak: flowBreak,
                todo: nil
            )
        }
        return HistoryCalendarSnapshot(
            interval: interval,
            items: items.sorted {
                if $0.startedAt == $1.startedAt { return $0.kind.rawValue < $1.kind.rawValue }
                return $0.startedAt < $1.startedAt
            }
        )
    }

    private func makeFlowItems(_ session: FlowSession) -> [HistoryCalendarItem] {
        if !session.resolvedSegments.isEmpty {
            return session.resolvedSegments.compactMap { segment in
                guard segment.resolvedFocusSeconds > 0 else { return nil }
                let end = segment.endedAt
                    ?? segment.startedAt.addingTimeInterval(TimeInterval(segment.resolvedFocusSeconds))
                return makeFlowItem(
                    id: segment.id,
                    session: session,
                    direction: segment.direction,
                    todo: segment.todo,
                    start: segment.startedAt,
                    end: end
                )
            }
        }

        return [makeFlowItem(
            id: session.id,
            session: session,
            direction: session.direction,
            todo: session.todo,
            start: session.startedAt,
            end: resolvedEnd(of: session)
        )]
    }

    private func makeFlowItem(
        id: UUID,
        session: FlowSession,
        direction: Direction?,
        todo: Todo?,
        start: Date,
        end: Date
    ) -> HistoryCalendarItem {
        let directionName = direction?.name ?? String(localized: "その他")
        return HistoryCalendarItem(
            id: "flow-\(id.uuidString)",
            kind: .flow,
            startedAt: start,
            endedAt: max(end, start.addingTimeInterval(60)),
            title: todo.map(TodoDisplay.title(for:)) ?? "(\(directionName))",
            subtitle: directionName,
            symbol: direction?.symbolName ?? "📝",
            colorHex: direction?.colorHex ?? "#8E8E93",
            session: session,
            flowBreak: nil,
            todo: todo
        )
    }

    private func resolvedEnd(of session: FlowSession) -> Date {
        session.endedAt
            ?? session.startedAt.addingTimeInterval(TimeInterval(session.resolvedActualFocusDurationSeconds))
    }

    private func overlaps(start: Date, end: Date, interval: DateInterval) -> Bool {
        start < interval.end && end > interval.start
    }
}

struct HistoryOverlapInput: Identifiable, Equatable {
    let id: String
    let start: Date
    let end: Date
}

struct HistoryOverlapPlacement: Identifiable, Equatable {
    let id: String
    let lane: Int
    let laneCount: Int
}

struct HistoryOverlapLayout {
    func place(
        _ inputs: [HistoryOverlapInput],
        minimumDuration: TimeInterval = 0
    ) -> [HistoryOverlapPlacement] {
        let expanded = inputs.map { input in
            HistoryOverlapInput(
                id: input.id,
                start: input.start,
                end: max(input.end, input.start.addingTimeInterval(minimumDuration))
            )
        }
        let sorted = expanded.sorted {
            if $0.start == $1.start { return $0.end < $1.end }
            return $0.start < $1.start
        }
        guard !sorted.isEmpty else { return [] }

        var result: [HistoryOverlapPlacement] = []
        var cluster: [HistoryOverlapInput] = []
        var clusterEnd = Date.distantPast

        func appendCluster(_ entries: [HistoryOverlapInput], to output: inout [HistoryOverlapPlacement]) {
            guard !entries.isEmpty else { return }
            var laneEnds: [Date] = []
            var assigned: [(String, Int)] = []

            for entry in entries {
                let lane = laneEnds.firstIndex { $0 <= entry.start } ?? laneEnds.count
                if lane == laneEnds.count {
                    laneEnds.append(entry.end)
                } else {
                    laneEnds[lane] = entry.end
                }
                assigned.append((entry.id, lane))
            }

            output += assigned.map {
                HistoryOverlapPlacement(id: $0.0, lane: $0.1, laneCount: laneEnds.count)
            }
        }

        for entry in sorted {
            if !cluster.isEmpty, entry.start >= clusterEnd {
                appendCluster(cluster, to: &result)
                cluster.removeAll(keepingCapacity: true)
                clusterEnd = .distantPast
            }
            cluster.append(entry)
            clusterEnd = max(clusterEnd, entry.end)
        }
        appendCluster(cluster, to: &result)
        return result
    }
}
