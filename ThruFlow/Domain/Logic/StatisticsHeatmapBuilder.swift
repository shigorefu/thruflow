//
//  StatisticsHeatmapBuilder.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/09.
//

import Foundation

enum StatisticsRange: Int, CaseIterable, Identifiable {
    case days90 = 90
    case days180 = 180
    case year = 365

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .days90:
            "90日"
        case .days180:
            "180日"
        case .year:
            "1年"
        }
    }
}

struct StatisticsFilter: Equatable {
    var range: StatisticsRange = .year
    var directionID: UUID?
}

struct StatisticsDay: Identifiable, Equatable {
    let date: Date
    let totalFocusSeconds: Int
    let mixedColorHex: String?
    let directionCount: Int

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
        Double(totalFocusSeconds) / Double(BlockUnit.secondsPerBlock)
    }
}

struct StatisticsHeatmapResult: Equatable {
    let days: [StatisticsDay]
    let summary: StatisticsSummary
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
        let startDate = startDate(for: filter.range, now: now)
        let endDate = calendar.startOfDay(for: now)
        let eligibleSessions = sessions.filter { session in
            let sessionDate = calendar.startOfDay(for: session.startedAt)
            guard sessionDate >= startDate, sessionDate <= endDate else { return false }
            guard session.resolvedActualFocusDurationSeconds > 0 else { return false }
            guard session.status != .interrupted else { return false }
            guard let directionID = filter.directionID else { return true }
            return session.direction?.id == directionID
        }

        let groupedByDay = Dictionary(grouping: eligibleSessions) { session in
            calendar.startOfDay(for: session.startedAt)
        }

        let days = daysBetween(startDate, and: endDate).map { date in
            makeDay(date: date, sessions: groupedByDay[date] ?? [])
        }

        let summary = StatisticsSummary(
            totalFocusSeconds: days.reduce(0) { $0 + $1.totalFocusSeconds },
            activeDayCount: days.filter { !$0.isEmpty }.count,
            sessionCount: eligibleSessions.count
        )

        return StatisticsHeatmapResult(days: days, summary: summary)
    }

    private func startDate(for range: StatisticsRange, now: Date) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -(range.rawValue - 1), to: today) ?? today
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

    private func makeDay(date: Date, sessions: [FlowSession]) -> StatisticsDay {
        let totalSeconds = sessions.reduce(0) { $0 + $1.resolvedActualFocusDurationSeconds }
        let weightedColors = sessions.compactMap { session -> WeightedHexColor? in
            guard let direction = session.direction else { return nil }
            return WeightedHexColor(
                hex: direction.colorHex,
                weight: session.resolvedActualFocusDurationSeconds
            )
        }

        return StatisticsDay(
            date: date,
            totalFocusSeconds: totalSeconds,
            mixedColorHex: Self.mixedHexColor(weightedColors),
            directionCount: Set(sessions.compactMap { $0.direction?.id }).count
        )
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
