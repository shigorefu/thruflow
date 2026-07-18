//
//  StatisticsHeatmapBuilder.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/09.
//

import Foundation

enum StatisticsRange: String, CaseIterable, Identifiable {
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

enum StatisticsMode: String, CaseIterable, Identifiable {
    case achievement
    case flow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .achievement:
            String(localized: "達成")
        case .flow:
            String(localized: "Flow")
        }
    }
}

struct StatisticsFilter: Equatable {
    var range: StatisticsRange = .calendarYear
    var directionID: UUID?
}

struct StatisticsDay: Identifiable, Equatable {
    let date: Date
    let totalFocusSeconds: Int
    let mixedColorHex: String?
    let directionCount: Int
    let sessionCount: Int

    var id: Date { date }

    var isEmpty: Bool {
        totalFocusSeconds <= 0
    }
}

struct StatisticsSummary: Equatable {
    let totalFocusSeconds: Int
    let activeDayCount: Int
    let sessionCount: Int

    var totalBlocks: Double {
        BlockUnit.blocks(forFocusedSeconds: totalFocusSeconds)
    }
}

struct StatisticsHeatmapResult: Equatable {
    let days: [StatisticsDay]
    let summary: StatisticsSummary
}

struct AchievementDay: Identifiable, Equatable {
    let date: Date
    let completedCount: Int
    let mixedColorHex: String?
    let directionCount: Int

    var id: Date { date }

    var isEmpty: Bool {
        completedCount <= 0
    }
}

struct AchievementSummary: Equatable {
    let completedCount: Int
    let activeDayCount: Int
    let directionCount: Int
}

struct AchievementHeatmapResult: Equatable {
    let days: [AchievementDay]
    let summary: AchievementSummary
}

struct StatisticsHeatmapBuilder {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func build(
        sessions: [FlowSession],
        filter: StatisticsFilter,
        now: Date = .now
    ) -> StatisticsHeatmapResult {
        let interval = dateInterval(for: filter.range, now: now)
        let startDate = interval.start
        let endDate = interval.end
        let contributions = sessions.flatMap(makeContributions).filter { contribution in
            let contributionDate = calendar.startOfDay(for: contribution.startedAt)
            guard contributionDate >= startDate, contributionDate <= endDate else { return false }
            guard let directionID = filter.directionID else { return true }
            return contribution.direction?.id == directionID
        }

        let groupedByDay = Dictionary(grouping: contributions) { contribution in
            calendar.startOfDay(for: contribution.startedAt)
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

    private func dateInterval(for range: StatisticsRange, now: Date) -> (start: Date, end: Date) {
        let today = calendar.startOfDay(for: now)

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

    private func daysBetween(_ startDate: Date, and endDate: Date) -> [Date] {
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

    private func makeDay(date: Date, contributions: [FlowContribution]) -> StatisticsDay {
        let totalSeconds = contributions.reduce(0) { $0 + $1.focusSeconds }
        let weightedColors = contributions.compactMap { contribution -> WeightedHexColor? in
            guard let direction = contribution.direction else { return nil }
            return WeightedHexColor(
                hex: direction.colorHex,
                weight: contribution.focusSeconds
            )
        }

        return StatisticsDay(
            date: date,
            totalFocusSeconds: totalSeconds,
            mixedColorHex: Self.mixedHexColor(weightedColors),
            directionCount: Set(contributions.compactMap { $0.direction?.id }).count,
            sessionCount: Set(contributions.map(\.sessionID)).count
        )
    }

    private func makeContributions(_ session: FlowSession) -> [FlowContribution] {
        guard session.status != .interrupted else { return [] }

        if !session.resolvedSegments.isEmpty {
            return session.resolvedSegments.compactMap { segment in
                guard segment.resolvedFocusSeconds > 0 else { return nil }
                return FlowContribution(
                    sessionID: session.id,
                    startedAt: segment.startedAt,
                    direction: segment.direction,
                    focusSeconds: segment.resolvedFocusSeconds
                )
            }
        }

        guard session.resolvedActualFocusDurationSeconds > 0 else { return [] }
        return [FlowContribution(
            sessionID: session.id,
            startedAt: session.startedAt,
            direction: session.direction,
            focusSeconds: session.resolvedActualFocusDurationSeconds
        )]
    }

    static func mixedHexColor(_ colors: [WeightedHexColor]) -> String? {
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

private struct FlowContribution {
    let sessionID: UUID
    let startedAt: Date
    let direction: Direction?
    let focusSeconds: Int
}

struct AchievementHeatmapBuilder {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func build(
        todos: [Todo],
        filter: StatisticsFilter,
        now: Date = .now
    ) -> AchievementHeatmapResult {
        let interval = dateInterval(for: filter.range, now: now)
        let startDate = interval.start
        let endDate = interval.end
        let eligibleTodos = todos.filter { todo in
            let completionDate = calendar.startOfDay(for: todo.completedAt ?? todo.updatedAt)
            guard completionDate >= startDate, completionDate <= endDate else { return false }
            guard todo.status == .completed, !todo.isDeleted else { return false }
            guard let directionID = filter.directionID else { return true }
            return todo.direction?.id == directionID
        }

        let groupedByDay = Dictionary(grouping: eligibleTodos) { todo in
            calendar.startOfDay(for: todo.completedAt ?? todo.updatedAt)
        }

        let days = daysBetween(startDate, and: endDate).map { date in
            makeDay(date: date, todos: groupedByDay[date] ?? [])
        }

        let directionIDs = Set(eligibleTodos.compactMap { $0.direction?.id })
        let summary = AchievementSummary(
            completedCount: eligibleTodos.count,
            activeDayCount: days.filter { !$0.isEmpty }.count,
            directionCount: directionIDs.count
        )

        return AchievementHeatmapResult(days: days, summary: summary)
    }

    private func dateInterval(for range: StatisticsRange, now: Date) -> (start: Date, end: Date) {
        let today = calendar.startOfDay(for: now)

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

    private func daysBetween(_ startDate: Date, and endDate: Date) -> [Date] {
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

    private func makeDay(date: Date, todos: [Todo]) -> AchievementDay {
        let weightedColors = todos.compactMap { todo -> WeightedHexColor? in
            guard let direction = todo.direction else { return nil }
            return WeightedHexColor(hex: direction.colorHex, weight: 1)
        }

        return AchievementDay(
            date: date,
            completedCount: todos.count,
            mixedColorHex: StatisticsHeatmapBuilder.mixedHexColor(weightedColors),
            directionCount: Set(todos.compactMap { $0.direction?.id }).count
        )
    }
}

struct WeightedHexColor: Equatable {
    let hex: String
    let weight: Int
}

private struct RGBColor: Equatable {
    let red: Int
    let green: Int
    let blue: Int

    init(red: Int, green: Int, blue: Int) {
        self.red = min(max(red, 0), 255)
        self.green = min(max(green, 0), 255)
        self.blue = min(max(blue, 0), 255)
    }

    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }

        guard value.count == 6, let intValue = Int(value, radix: 16) else { return nil }

        red = (intValue >> 16) & 0xFF
        green = (intValue >> 8) & 0xFF
        blue = intValue & 0xFF
    }

    var hex: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }
}
