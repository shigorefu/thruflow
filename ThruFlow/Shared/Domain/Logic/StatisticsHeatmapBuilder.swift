//
//  StatisticsHeatmapBuilder.swift
//  ThruFlow
//
//

import Foundation

enum StatisticsRange: String, CaseIterable, Identifiable, Sendable {
    case currentMonth
    case days180
    case calendarYear

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .currentMonth:
            String(localized: "今月")
        case .days180:
            String(localized: "180日")
        case .calendarYear:
            String(localized: "年")
        }
    }

    var summaryText: String {
        switch self {
        case .currentMonth:
            String(localized: "今月")
        case .days180:
            String(localized: "過去180日")
        case .calendarYear:
            String(localized: "今年")
        }
    }
}

enum StatisticsMode: String, CaseIterable, Identifiable, Sendable {
    case achievement
    case flow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .achievement:
            String(localized: "タスク")
        case .flow:
            String(localized: "集中")
        }
    }
}

struct StatisticsFilter: Equatable, Sendable {
    var range: StatisticsRange = .calendarYear
    var directionID: UUID?
}

struct StatisticsDay: Identifiable, Equatable, Sendable {
    let date: Date
    let totalFocusSeconds: Int
    let mixedColorHex: String?
    let directionCount: Int
    let sessionCount: Int

    var id: Date { date }

    nonisolated var isEmpty: Bool {
        totalFocusSeconds <= 0
    }
}

struct StatisticsSummary: Equatable, Sendable {
    let totalFocusSeconds: Int
    let activeDayCount: Int
    let sessionCount: Int

    var totalBlocks: Double {
        BlockUnit.blocks(forFocusedSeconds: totalFocusSeconds)
    }
}

struct StatisticsHeatmapResult: Equatable, Sendable {
    let days: [StatisticsDay]
    let summary: StatisticsSummary
}

struct AchievementDay: Identifiable, Equatable, Sendable {
    let date: Date
    let completedCount: Int
    let mixedColorHex: String?
    let directionCount: Int

    var id: Date { date }

    nonisolated var isEmpty: Bool {
        completedCount <= 0
    }
}

struct AchievementSummary: Equatable, Sendable {
    let completedCount: Int
    let activeDayCount: Int
    let directionCount: Int
}

struct AchievementHeatmapResult: Equatable, Sendable {
    let days: [AchievementDay]
    let summary: AchievementSummary
}

struct StatisticsFlowRecord: Sendable {
    let sessionID: UUID
    let startedAt: Date
    let directionID: UUID?
    let directionColorHex: String?
    let focusSeconds: Int
}

struct StatisticsAchievementRecord: Sendable {
    let completedAt: Date
    let directionID: UUID?
    let directionColorHex: String?
}

struct StatisticsHeatmapBuilder: Sendable {
    private let calendar: Calendar
    private let dayBoundary: AppDayBoundary

    nonisolated init(
        calendar: Calendar = .current,
        dayBoundary: AppDayBoundary = .midnight
    ) {
        self.calendar = calendar
        self.dayBoundary = dayBoundary
    }

    @MainActor
    func build(
        sessions: [FlowSession],
        filter: StatisticsFilter,
        now: Date = .now
    ) -> StatisticsHeatmapResult {
        build(
            records: sessions.flatMap(Self.makeRecords),
            filter: filter,
            now: now
        )
    }

    nonisolated func build(
        records: [StatisticsFlowRecord],
        filter: StatisticsFilter,
        now: Date = .now
    ) -> StatisticsHeatmapResult {
        let interval = dateInterval(for: filter.range, now: now)
        let startDate = interval.start
        let endDate = interval.end
        let contributions = records.filter { contribution in
            let contributionDate = dayBoundary.day(
                containing: contribution.startedAt,
                calendar: calendar
            )
            guard contributionDate >= startDate, contributionDate <= endDate else { return false }
            guard let directionID = filter.directionID else { return true }
            return contribution.directionID == directionID
        }

        let groupedByDay = Dictionary(grouping: contributions) { contribution in
            dayBoundary.day(containing: contribution.startedAt, calendar: calendar)
        }

        let days = daysBetween(startDate, and: endDate).map { date in
            makeDay(date: date, contributions: groupedByDay[date] ?? [])
        }

        let summary = StatisticsSummary(
            totalFocusSeconds: days.reduce(0) { $0 + $1.totalFocusSeconds },
            activeDayCount: days.filter { !$0.isEmpty }.count,
            sessionCount: Set(contributions.map(\.sessionID)).count
        )

        return StatisticsHeatmapResult(days: days, summary: summary)
    }

    nonisolated private func dateInterval(for range: StatisticsRange, now: Date) -> (start: Date, end: Date) {
        let today = dayBoundary.day(containing: now, calendar: calendar)

        switch range {
        case .currentMonth:
            let components = calendar.dateComponents([.year, .month], from: today)
            let start = calendar.date(from: components) ?? today
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: start) ?? today
            let end = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? today
            return (start, end)
        case .days180:
            return (calendar.date(byAdding: .day, value: -179, to: today) ?? today, today)
        case .calendarYear:
            let year = calendar.component(.year, from: today)
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? today
            let end = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? today
            return (start, end)
        }
    }

    nonisolated private func daysBetween(_ startDate: Date, and endDate: Date) -> [Date] {
        guard startDate <= endDate else { return [] }

        var days: [Date] = []
        var current = startDate
        while current <= endDate {
            days.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else {
                break
            }
            current = next
        }
        return days
    }

    nonisolated private func makeDay(date: Date, contributions: [StatisticsFlowRecord]) -> StatisticsDay {
        let totalSeconds = contributions.reduce(0) { $0 + $1.focusSeconds }
        let weightedColors = contributions.compactMap { contribution -> WeightedHexColor? in
            guard let colorHex = contribution.directionColorHex else { return nil }
            return WeightedHexColor(
                hex: colorHex,
                weight: contribution.focusSeconds
            )
        }

        return StatisticsDay(
            date: date,
            totalFocusSeconds: totalSeconds,
            mixedColorHex: Self.mixedHexColor(weightedColors),
            directionCount: Set(contributions.compactMap(\.directionID)).count,
            sessionCount: Set(contributions.map(\.sessionID)).count
        )
    }

    @MainActor
    static func makeRecords(_ session: FlowSession) -> [StatisticsFlowRecord] {
        guard session.status != .interrupted else { return [] }

        if !session.resolvedSegments.isEmpty {
            return session.resolvedSegments.compactMap { segment in
                guard segment.resolvedFocusSeconds > 0 else { return nil }
                return StatisticsFlowRecord(
                    sessionID: session.id,
                    startedAt: segment.startedAt,
                    directionID: segment.direction?.id,
                    directionColorHex: segment.direction?.colorHex,
                    focusSeconds: segment.resolvedFocusSeconds
                )
            }
        }

        guard session.resolvedActualFocusDurationSeconds > 0 else { return [] }
        return [StatisticsFlowRecord(
            sessionID: session.id,
            startedAt: session.startedAt,
            directionID: session.direction?.id,
            directionColorHex: session.direction?.colorHex,
            focusSeconds: session.resolvedActualFocusDurationSeconds
        )]
    }

    nonisolated static func mixedHexColor(_ colors: [WeightedHexColor]) -> String? {
        let parsed = colors.compactMap { color -> (rgb: RGBColor, weight: Int)? in
            guard color.weight > 0, let rgb = RGBColor(hex: color.hex) else { return nil }
            return (rgb, color.weight)
        }
        let totalWeight = parsed.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return nil }

        let red = parsed.reduce(0.0) { $0 + Double($1.rgb.red * $1.weight) } / Double(totalWeight)
        let green = parsed.reduce(0.0) { $0 + Double($1.rgb.green * $1.weight) } / Double(totalWeight)
        let blue = parsed.reduce(0.0) { $0 + Double($1.rgb.blue * $1.weight) } / Double(totalWeight)

        return RGBColor(
            red: Int(red.rounded()),
            green: Int(green.rounded()),
            blue: Int(blue.rounded())
        ).hex
    }
}

struct AchievementHeatmapBuilder: Sendable {
    private let calendar: Calendar
    private let dayBoundary: AppDayBoundary

    nonisolated init(
        calendar: Calendar = .current,
        dayBoundary: AppDayBoundary = .midnight
    ) {
        self.calendar = calendar
        self.dayBoundary = dayBoundary
    }

    @MainActor
    func build(
        todos: [Todo],
        filter: StatisticsFilter,
        now: Date = .now
    ) -> AchievementHeatmapResult {
        build(
            records: todos.compactMap(Self.makeRecord),
            filter: filter,
            now: now
        )
    }

    nonisolated func build(
        records: [StatisticsAchievementRecord],
        filter: StatisticsFilter,
        now: Date = .now
    ) -> AchievementHeatmapResult {
        let interval = dateInterval(for: filter.range, now: now)
        let startDate = interval.start
        let endDate = interval.end
        let eligibleTodos = records.filter { todo in
            let completionDate = dayBoundary.day(
                containing: todo.completedAt,
                calendar: calendar
            )
            guard completionDate >= startDate, completionDate <= endDate else { return false }
            guard let directionID = filter.directionID else { return true }
            return todo.directionID == directionID
        }

        let groupedByDay = Dictionary(grouping: eligibleTodos) { todo in
            dayBoundary.day(
                containing: todo.completedAt,
                calendar: calendar
            )
        }

        let days = daysBetween(startDate, and: endDate).map { date in
            makeDay(date: date, todos: groupedByDay[date] ?? [])
        }

        let directionIDs = Set(eligibleTodos.compactMap(\.directionID))
        let summary = AchievementSummary(
            completedCount: eligibleTodos.count,
            activeDayCount: days.filter { !$0.isEmpty }.count,
            directionCount: directionIDs.count
        )

        return AchievementHeatmapResult(days: days, summary: summary)
    }

    nonisolated private func dateInterval(for range: StatisticsRange, now: Date) -> (start: Date, end: Date) {
        let today = dayBoundary.day(containing: now, calendar: calendar)

        switch range {
        case .currentMonth:
            let components = calendar.dateComponents([.year, .month], from: today)
            let start = calendar.date(from: components) ?? today
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: start) ?? today
            let end = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? today
            return (start, end)
        case .days180:
            return (calendar.date(byAdding: .day, value: -179, to: today) ?? today, today)
        case .calendarYear:
            let year = calendar.component(.year, from: today)
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? today
            let end = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? today
            return (start, end)
        }
    }

    nonisolated private func daysBetween(_ startDate: Date, and endDate: Date) -> [Date] {
        guard startDate <= endDate else { return [] }

        var days: [Date] = []
        var current = startDate
        while current <= endDate {
            days.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else {
                break
            }
            current = next
        }
        return days
    }

    nonisolated private func makeDay(date: Date, todos: [StatisticsAchievementRecord]) -> AchievementDay {
        let weightedColors = todos.compactMap { todo -> WeightedHexColor? in
            guard let colorHex = todo.directionColorHex else { return nil }
            return WeightedHexColor(hex: colorHex, weight: 1)
        }

        return AchievementDay(
            date: date,
            completedCount: todos.count,
            mixedColorHex: StatisticsHeatmapBuilder.mixedHexColor(weightedColors),
            directionCount: Set(todos.compactMap(\.directionID)).count
        )
    }

    @MainActor
    static func makeRecord(_ todo: Todo) -> StatisticsAchievementRecord? {
        guard todo.status == .completed, !todo.isDeleted else { return nil }
        return StatisticsAchievementRecord(
            completedAt: todo.completedAt ?? todo.updatedAt,
            directionID: todo.direction?.id,
            directionColorHex: todo.direction?.colorHex
        )
    }
}

struct WeightedHexColor: Equatable, Sendable {
    let hex: String
    let weight: Int
}

private struct RGBColor: Equatable, Sendable {
    let red: Int
    let green: Int
    let blue: Int

    nonisolated init(red: Int, green: Int, blue: Int) {
        self.red = min(max(red, 0), 255)
        self.green = min(max(green, 0), 255)
        self.blue = min(max(blue, 0), 255)
    }

    nonisolated init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }

        guard value.count == 6, let intValue = Int(value, radix: 16) else { return nil }

        red = (intValue >> 16) & 0xFF
        green = (intValue >> 8) & 0xFF
        blue = intValue & 0xFF
    }

    nonisolated var hex: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }
}
