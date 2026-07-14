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
        case .day: "日"
        case .week: "週"
        case .month: "月"
        }
    }

    func interval(containing date: Date, calendar: Calendar) -> DateInterval {
        switch self {
        case .day:
            let start = calendar.startOfDay(for: date)
            return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: start)!)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)!
        case .month:
            return calendar.dateInterval(of: .month, for: date)!
        }
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

enum HistoryCalendarItemKind: String, CaseIterable, Hashable {
    case flow
    case rest
    case completedTask
    case scheduledTask
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
    let isAllDay: Bool
    let session: FlowSession?
    let flowBreak: FlowBreak?
    let todo: Todo?

    var durationSeconds: Int {
        max(0, Int(endedAt.timeIntervalSince(startedAt)))
    }
}

struct HistoryCalendarSnapshot {
    let interval: DateInterval
    let items: [HistoryCalendarItem]

    func items(on date: Date, calendar: Calendar) -> [HistoryCalendarItem] {
        items.filter { item in
            item.isAllDay
                ? calendar.isDate(item.startedAt, inSameDayAs: date)
                : calendar.isDate(item.startedAt, inSameDayAs: date)
                    || calendar.isDate(item.endedAt.addingTimeInterval(-1), inSameDayAs: date)
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
        todos: [Todo],
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
                title: flowBreak.isLongBreak ? "Long Break" : "休憩",
                subtitle: direction?.name ?? "Flowシリーズ",
                symbol: "☕️",
                colorHex: "#8E8E93",
                isAllDay: false,
                session: previousSession,
                flowBreak: flowBreak,
                todo: nil
            )
        }
        items += todos.compactMap { makeTaskItem($0, interval: interval) }

        return HistoryCalendarSnapshot(
            interval: interval,
            items: items.sorted {
                if $0.startedAt == $1.startedAt { return $0.kind.rawValue < $1.kind.rawValue }
                return $0.startedAt < $1.startedAt
            }
        )
    }

    private func makeFlowItems(_ session: FlowSession) -> [HistoryCalendarItem] {
        if !session.segments.isEmpty {
            return session.segments.compactMap { segment in
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
        let directionName = direction?.name ?? "その他"
        return HistoryCalendarItem(
            id: "flow-\(id.uuidString)",
            kind: .flow,
            startedAt: start,
            endedAt: max(end, start.addingTimeInterval(60)),
            title: todo.map(TodoDisplay.title(for:)) ?? "(\(directionName))",
            subtitle: directionName,
            symbol: direction?.symbolName ?? "📝",
            colorHex: direction?.colorHex ?? "#8E8E93",
            isAllDay: false,
            session: session,
            flowBreak: nil,
            todo: todo
        )
    }

    private func makeTaskItem(_ todo: Todo, interval: DateInterval) -> HistoryCalendarItem? {
        guard !todo.isDeleted, !todo.isArchived else { return nil }
        let directionName = todo.direction?.name ?? "その他"
        let symbol = todo.direction?.symbolName ?? "📝"
        let color = todo.direction?.colorHex ?? "#8E8E93"

        if todo.isCompleted, let completedAt = todo.completedAt, interval.contains(completedAt) {
            return HistoryCalendarItem(
                id: "completed-task-\(todo.id.uuidString)",
                kind: .completedTask,
                startedAt: completedAt,
                endedAt: completedAt.addingTimeInterval(20 * 60),
                title: TodoDisplay.title(for: todo),
                subtitle: "\(directionName) ・ 達成",
                symbol: symbol,
                colorHex: color,
                isAllDay: false,
                session: nil,
                flowBreak: nil,
                todo: todo
            )
        }

        guard let scheduledDate = todo.scheduledDate,
              interval.contains(calendar.startOfDay(for: scheduledDate)) else { return nil }
        guard !todo.isCompleted || todo.completedAt == nil else { return nil }

        return HistoryCalendarItem(
            id: "scheduled-task-\(todo.id.uuidString)",
            kind: .scheduledTask,
            startedAt: calendar.startOfDay(for: scheduledDate),
            endedAt: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: scheduledDate))!,
            title: TodoDisplay.title(for: todo),
            subtitle: todo.isCompleted ? "\(directionName) ・ 完了時刻なし" : directionName,
            symbol: symbol,
            colorHex: color,
            isAllDay: true,
            session: nil,
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
    func place(_ inputs: [HistoryOverlapInput]) -> [HistoryOverlapPlacement] {
        let sorted = inputs.sorted {
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
