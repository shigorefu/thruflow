//
//  FlowDashboardBuilder.swift
//  ThruFlow
//
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
    let paletteWeights: [Double]
    let dailyVisualSeed: UInt64

    static func empty(at date: Date = .now) -> FlowDashboardSnapshot {
        FlowDashboardSnapshot(
            date: date,
            totalFocusSeconds: 0,
            flowCount: 0,
            segments: [],
            breaks: [],
            seriesSpans: [],
            palette: ["#0A84FF", "#30D158", "#64D2FF"],
            paletteWeights: [1, 1, 1],
            dailyVisualSeed: 0
        )
    }

    var blocks: Double {
        BlockUnit.blocks(forFocusedSeconds: totalFocusSeconds)
    }

    var intensity: Double {
        min(max(blocks / FlowVisualState.maximumGrowthBlocks, 0), 1)
    }

    func focusShare(for focusSeconds: Int) -> Double {
        guard totalFocusSeconds > 0 else { return 0 }
        return min(max(Double(focusSeconds) / Double(totalFocusSeconds), 0), 1)
    }

    var areaSummaries: [FlowDashboardAreaSummary] {
        Dictionary(grouping: segments, by: \FlowDashboardSegment.areaID)
            .values
            .map { values in
                let first = values[0]
                return FlowDashboardAreaSummary(
                    id: first.areaID,
                    symbol: first.symbol,
                    name: first.areaName,
                    colorHex: first.colorHex,
                    focusSeconds: values.reduce(0) { $0 + $1.focusSeconds }
                )
            }
            .sorted { $0.focusSeconds > $1.focusSeconds }
    }

    var taskSummaries: [FlowDashboardTaskSummary] {
        Dictionary(grouping: segments) { segment in
            segment.taskID?.uuidString ?? "area-\(segment.areaID.uuidString)"
        }
        .map { id, values in
            let first = values[0]
            return FlowDashboardTaskSummary(
                id: id,
                title: first.taskTitle,
                symbol: first.symbol,
                colorHex: first.colorHex,
                focusSeconds: values.reduce(0) { $0 + $1.focusSeconds }
            )
        }
        .sorted {
            if $0.focusSeconds != $1.focusSeconds {
                return $0.focusSeconds > $1.focusSeconds
            }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    var sessionGroups: [FlowDashboardSessionGroup] {
        Dictionary(grouping: segments, by: { $0.session.id })
            .values
            .compactMap { values in
                guard let first = values.min(by: { $0.startedAt < $1.startedAt }),
                      let last = values.max(by: { $0.endedAt < $1.endedAt }) else {
                    return nil
                }

                return FlowDashboardSessionGroup(
                    id: first.session.id,
                    startedAt: first.startedAt,
                    endedAt: last.endedAt,
                    segments: values.sorted { $0.startedAt < $1.startedAt },
                    isActive: values.contains(where: \FlowDashboardSegment.isActive)
                )
            }
            .sorted { $0.startedAt < $1.startedAt }
    }
}

struct FlowDashboardAreaSummary: Identifiable {
    let id: UUID
    let symbol: String
    let name: String
    let colorHex: String
    let focusSeconds: Int
}

struct FlowDashboardTaskSummary: Identifiable {
    let id: String
    let title: String
    let symbol: String
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
    let taskID: UUID?
    let areaID: UUID
    let areaName: String
    let colorHex: String
    let symbol: String
    let taskTitle: String
    let isActive: Bool
}

struct FlowDashboardSessionGroup: Identifiable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let segments: [FlowDashboardSegment]
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

struct FlowTimelineRange: Equatable {
    let start: Date
    let end: Date

    init(
        date: Date,
        segments: [FlowDashboardSegment],
        breaks: [FlowDashboardBreak] = [],
        calendar: Calendar = .current
    ) {
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
struct FlowDashboardTodoGroups {
    let all: [Todo]
    let standard: [Todo]
    let habits: [Todo]
    let nice: [Todo]

    static let empty = FlowDashboardTodoGroups(
        all: [],
        standard: [],
        habits: [],
        nice: []
    )
}

@MainActor
struct FlowDashboardTodoGroupBuilder {
    let calendar: Calendar
    let dayBoundary: AppDayBoundary

    func build(from todos: [Todo]) -> FlowDashboardTodoGroups {
        let filter = TodayTodoFilter(calendar: calendar, dayBoundary: dayBoundary)
        let sorted = FlowDashboardTodoSorter().sorted(todos.filter { filter.includes($0) })

        return FlowDashboardTodoGroups(
            all: sorted,
            standard: sorted.filter { ($0.area?.type ?? .neutral) == .neutral },
            habits: sorted.filter { $0.area?.type == .habit },
            nice: sorted.filter { $0.area?.type == .nice }
        )
    }
}

@MainActor
struct FlowDashboardBuilder {
    private let calendar: Calendar
    private let dayBoundary: AppDayBoundary

    init(
        calendar: Calendar = .current,
        dayBoundary: AppDayBoundary = .midnight
    ) {
        self.calendar = calendar
        self.dayBoundary = dayBoundary
    }

    func build(
        date: Date,
        sessions: [FlowSession],
        breaks storedBreaks: [FlowBreak] = [],
        activeSessionID: UUID? = nil,
        activeFocusSeconds: Int = 0,
        visualIdentityID: UUID? = nil,
        explicitDay: Date? = nil
    ) -> FlowDashboardSnapshot {
        let day = explicitDay.map(calendar.startOfDay(for:))
            ?? dayBoundary.day(containing: date, calendar: calendar)
        let dayInterval = dayBoundary.interval(for: day, calendar: calendar)
        let dayStart = dayInterval.start
        let nextDay = dayInterval.end
        let dayDuration = max(dayInterval.duration, 1)

        let segments = sessions.flatMap { session -> [FlowDashboardSegment] in
            guard dayBoundary.contains(session.startedAt, in: day, calendar: calendar),
                  session.status != .interrupted else {
                return []
            }

            let isActive = session.id == activeSessionID
            let resolvedFocusSeconds = isActive
                ? max(session.resolvedActualFocusDurationSeconds, activeFocusSeconds)
                : session.resolvedActualFocusDurationSeconds

            if !session.resolvedSegments.isEmpty {
                return session.resolvedSegments.compactMap { segment in
                    let focusSeconds = segment.endFocusSeconds.map { max(0, $0 - segment.startFocusSeconds) }
                        ?? (isActive ? max(0, resolvedFocusSeconds - segment.startFocusSeconds) : 0)
                    guard focusSeconds > 0 else { return nil }

                    return dashboardSegment(
                        id: segment.id,
                        session: session,
                        storedSegment: segment,
                        area: segment.area,
                        todo: segment.todo,
                        startedAt: segment.startedAt,
                        endedAt: segment.endedAt ?? (isActive ? date : nil),
                        focusSeconds: focusSeconds,
                        isActive: isActive && segment.endedAt == nil,
                        day: dayStart,
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
                area: session.area,
                todo: session.todo,
                startedAt: session.startedAt,
                endedAt: isActive && session.endedAt == nil ? date : session.endedAt,
                focusSeconds: focusSeconds,
                isActive: isActive,
                day: dayStart,
                dayDuration: dayDuration
            )]
        }
        .sorted { $0.startFraction < $1.startFraction }

        let sessionIDs = Set(segments.map { $0.session.id })
        let breaks = storedBreaks.compactMap { flowBreak -> FlowDashboardBreak? in
            guard !flowBreak.isDeleted,
                  dayBoundary.contains(flowBreak.startedAt, in: day, calendar: calendar),
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
            .sorted {
                if $0.seconds != $1.seconds {
                    return $0.seconds > $1.seconds
                }
                return $0.colorHex < $1.colorHex
            }
        let paletteTotal = max(groupedColors.reduce(0) { $0 + $1.seconds }, 1)
        let appearance = DailyFlowAppearance(
            date: day,
            identityID: visualIdentityID,
            calendar: calendar
        )

        return FlowDashboardSnapshot(
            date: day,
            totalFocusSeconds: totalFocusSeconds,
            flowCount: Set(segments.map { $0.session.id }).count,
            segments: segments,
            breaks: breaks,
            seriesSpans: seriesSpans,
            palette: groupedColors.map(\.colorHex),
            paletteWeights: groupedColors.map { Double($0.seconds) / Double(paletteTotal) },
            dailyVisualSeed: appearance.seed
        )
    }

    private func dashboardSegment(
        id: UUID,
        session: FlowSession,
        storedSegment: FlowSegment?,
        area: Area?,
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
            taskID: todo?.id,
            areaID: area?.id ?? id,
            areaName: area?.name ?? String(localized: "その他"),
            colorHex: area?.colorHex ?? "#8E8E93",
            symbol: area?.symbolName ?? "📥",
            taskTitle: todo.map(TodoDisplay.title(for:))
                ?? String(localized: "(\(area?.name ?? String(localized: "その他")))"),
            isActive: isActive
        )
    }
}
