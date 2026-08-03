//
//  StatisticsPeriodBuilder.swift
//  ThruFlow
//
//  Created by Codex on 2026/08/03.
//

import Foundation

enum StatisticsPeriod: String, CaseIterable, Identifiable, Sendable {
    case week
    case month
    case year

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .week:
            String(localized: "週")
        case .month:
            String(localized: "月")
        case .year:
            String(localized: "年")
        }
    }

    nonisolated func offset(_ date: Date, by value: Int, calendar: Calendar) -> Date {
        let component: Calendar.Component
        switch self {
        case .week:
            component = .weekOfYear
        case .month:
            component = .month
        case .year:
            component = .year
        }
        return calendar.date(byAdding: component, value: value, to: date) ?? date
    }
}

struct StatisticsPeriodFilter: Equatable, Sendable {
    var period: StatisticsPeriod = .week
    var anchorDate: Date = .now
    var directionID: UUID?
    var query = ""
}

struct StatisticsPeriodBounds: Equatable, Sendable {
    let currentStart: Date
    let currentEnd: Date
    let previousStart: Date
    let previousEnd: Date
    let fetchInterval: DateInterval

    nonisolated func containsCurrent(_ day: Date) -> Bool {
        day >= currentStart && day < currentEnd
    }

    nonisolated func containsPrevious(_ day: Date) -> Bool {
        day >= previousStart && day < previousEnd
    }
}

struct StatisticsPeriodFlowRecord: Equatable, Sendable {
    let sessionID: UUID
    let startedAt: Date
    let focusSeconds: Int
    let directionID: UUID?
    let directionName: String
    let directionSymbol: String
    let directionColorHex: String?
    let todoID: UUID?
    let todoTitle: String
    let todoHashtags: [String]
    let todoNotes: String
    let intent: String
    let result: String
}

struct StatisticsPeriodAchievementRecord: Equatable, Sendable {
    let completedAt: Date
    let todoID: UUID
    let todoTitle: String
    let todoHashtags: [String]
    let todoNotes: String
    let directionID: UUID?
    let directionName: String
    let directionSymbol: String
    let directionColorHex: String?
}

struct StatisticsPeriodSummary: Equatable, Sendable {
    let totalFocusSeconds: Int
    let flowCount: Int
    let completedTaskCount: Int
    let activeFlowDayCount: Int

    nonisolated var totalBlocks: Double {
        BlockUnit.blocks(forFocusedSeconds: totalFocusSeconds)
    }
}

struct StatisticsTrendPoint: Identifiable, Equatable, Sendable {
    let index: Int
    let date: Date
    let comparisonDate: Date
    let focusSeconds: Int
    let previousFocusSeconds: Int
    let completedTaskCount: Int
    let previousCompletedTaskCount: Int

    var id: Int { index }
}

struct StatisticsDistributionItem: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let symbol: String?
    let colorHex: String?
    let focusSeconds: Int
}

struct StatisticsCSVRow: Equatable, Sendable {
    let date: Date
    let task: String
    let direction: String
    let hashtags: [String]
    let focusedSeconds: Int
    let flowCount: Int
    let completedTaskCount: Int

    nonisolated var focusedMinutes: Double {
        Double(focusedSeconds) / 60
    }

    nonisolated var blocks: Double {
        BlockUnit.blocks(forFocusedSeconds: focusedSeconds)
    }
}

struct StatisticsPeriodSnapshot: Equatable, Sendable {
    let filter: StatisticsPeriodFilter
    let bounds: StatisticsPeriodBounds
    let summary: StatisticsPeriodSummary
    let previousSummary: StatisticsPeriodSummary
    let trend: [StatisticsTrendPoint]
    let taskDistribution: [StatisticsDistributionItem]
    let directionDistribution: [StatisticsDistributionItem]
    let flowDays: [StatisticsDay]
    let achievementDays: [AchievementDay]
    let csvRows: [StatisticsCSVRow]
}

struct StatisticsPeriodBuilder: Sendable {
    private let calendar: Calendar
    private let dayBoundary: AppDayBoundary

    nonisolated init(
        calendar: Calendar = .current,
        dayBoundary: AppDayBoundary = .midnight
    ) {
        self.calendar = calendar
        self.dayBoundary = dayBoundary
    }

    nonisolated func bounds(for filter: StatisticsPeriodFilter) -> StatisticsPeriodBounds {
        let anchorDay = dayBoundary.day(containing: filter.anchorDate, calendar: calendar)
        let current: DateInterval
        switch filter.period {
        case .week:
            current = calendar.dateInterval(of: .weekOfYear, for: anchorDay)
                ?? DateInterval(start: anchorDay, duration: 7 * 86_400)
        case .month:
            current = calendar.dateInterval(of: .month, for: anchorDay)
                ?? DateInterval(start: anchorDay, duration: 31 * 86_400)
        case .year:
            current = calendar.dateInterval(of: .year, for: anchorDay)
                ?? DateInterval(start: anchorDay, duration: 365 * 86_400)
        }

        let currentStart = calendar.startOfDay(for: current.start)
        let currentEnd = calendar.startOfDay(for: current.end)
        let previousStart = filter.period.offset(currentStart, by: -1, calendar: calendar)
        let previousEnd = currentStart

        return StatisticsPeriodBounds(
            currentStart: currentStart,
            currentEnd: currentEnd,
            previousStart: previousStart,
            previousEnd: previousEnd,
            fetchInterval: DateInterval(
                start: dayBoundary.interval(for: previousStart, calendar: calendar).start,
                end: dayBoundary.interval(
                    for: calendar.date(byAdding: .day, value: -1, to: currentEnd) ?? currentEnd,
                    calendar: calendar
                ).end
            )
        )
    }

    nonisolated func build(
        flowRecords: [StatisticsPeriodFlowRecord],
        achievementRecords: [StatisticsPeriodAchievementRecord],
        filter: StatisticsPeriodFilter
    ) -> StatisticsPeriodSnapshot {
        let periodBounds = bounds(for: filter)
        let filteredFlows = flowRecords.filter {
            matchesDirection($0.directionID, filter: filter) && matchesQuery($0, query: filter.query)
        }
        let filteredAchievements = achievementRecords.filter {
            matchesDirection($0.directionID, filter: filter) && matchesQuery($0, query: filter.query)
        }

        let currentFlows = filteredFlows.filter {
            periodBounds.containsCurrent(dayBoundary.day(containing: $0.startedAt, calendar: calendar))
        }
        let previousFlows = filteredFlows.filter {
            periodBounds.containsPrevious(dayBoundary.day(containing: $0.startedAt, calendar: calendar))
        }
        let currentAchievements = filteredAchievements.filter {
            periodBounds.containsCurrent(dayBoundary.day(containing: $0.completedAt, calendar: calendar))
        }
        let previousAchievements = filteredAchievements.filter {
            periodBounds.containsPrevious(dayBoundary.day(containing: $0.completedAt, calendar: calendar))
        }

        let days = dates(from: periodBounds.currentStart, to: periodBounds.currentEnd)
        return StatisticsPeriodSnapshot(
            filter: filter,
            bounds: periodBounds,
            summary: makeSummary(flows: currentFlows, achievements: currentAchievements),
            previousSummary: makeSummary(flows: previousFlows, achievements: previousAchievements),
            trend: makeTrend(
                period: filter.period,
                bounds: periodBounds,
                currentFlows: currentFlows,
                previousFlows: previousFlows,
                currentAchievements: currentAchievements,
                previousAchievements: previousAchievements
            ),
            taskDistribution: makeDistribution(flows: currentFlows, dimension: .task),
            directionDistribution: makeDistribution(flows: currentFlows, dimension: .direction),
            flowDays: makeFlowDays(days: days, flows: currentFlows),
            achievementDays: makeAchievementDays(days: days, achievements: currentAchievements),
            csvRows: makeCSVRows(flows: currentFlows, achievements: currentAchievements)
        )
    }

    nonisolated private func matchesDirection(_ directionID: UUID?, filter: StatisticsPeriodFilter) -> Bool {
        guard let selectedID = filter.directionID else { return true }
        return directionID == selectedID
    }

    nonisolated private func matchesQuery(_ record: StatisticsPeriodFlowRecord, query: String) -> Bool {
        matchesQuery(
            query,
            candidates: [
                record.todoTitle,
                record.todoNotes,
                record.todoHashtags.joined(separator: " "),
                record.directionName,
                record.directionSymbol,
                record.intent,
                record.result
            ]
        )
    }

    nonisolated private func matchesQuery(_ record: StatisticsPeriodAchievementRecord, query: String) -> Bool {
        matchesQuery(
            query,
            candidates: [
                record.todoTitle,
                record.todoNotes,
                record.todoHashtags.joined(separator: " "),
                record.directionName,
                record.directionSymbol
            ]
        )
    }

    nonisolated private func matchesQuery(_ query: String, candidates: [String]) -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return true }
        return candidates.contains { $0.localizedCaseInsensitiveContains(term) }
    }

    nonisolated private func makeSummary(
        flows: [StatisticsPeriodFlowRecord],
        achievements: [StatisticsPeriodAchievementRecord]
    ) -> StatisticsPeriodSummary {
        StatisticsPeriodSummary(
            totalFocusSeconds: flows.reduce(0) { $0 + max(0, $1.focusSeconds) },
            flowCount: Set(flows.map(\.sessionID)).count,
            completedTaskCount: achievements.count,
            activeFlowDayCount: Set(flows.map {
                dayBoundary.day(containing: $0.startedAt, calendar: calendar)
            }).count
        )
    }

    nonisolated private func makeTrend(
        period: StatisticsPeriod,
        bounds: StatisticsPeriodBounds,
        currentFlows: [StatisticsPeriodFlowRecord],
        previousFlows: [StatisticsPeriodFlowRecord],
        currentAchievements: [StatisticsPeriodAchievementRecord],
        previousAchievements: [StatisticsPeriodAchievementRecord]
    ) -> [StatisticsTrendPoint] {
        let currentDates: [Date]
        let previousDates: [Date]

        if period == .year {
            currentDates = monthStarts(from: bounds.currentStart, to: bounds.currentEnd)
            previousDates = monthStarts(from: bounds.previousStart, to: bounds.previousEnd)
        } else {
            currentDates = dates(from: bounds.currentStart, to: bounds.currentEnd)
            previousDates = dates(from: bounds.previousStart, to: bounds.previousEnd)
        }

        return currentDates.enumerated().map { index, date in
            let comparisonDate = previousDates.indices.contains(index) ? previousDates[index] : bounds.previousStart
            return StatisticsTrendPoint(
                index: index,
                date: date,
                comparisonDate: comparisonDate,
                focusSeconds: totalFocus(on: date, period: period, records: currentFlows),
                previousFocusSeconds: totalFocus(on: comparisonDate, period: period, records: previousFlows),
                completedTaskCount: completionCount(on: date, period: period, records: currentAchievements),
                previousCompletedTaskCount: completionCount(on: comparisonDate, period: period, records: previousAchievements)
            )
        }
    }

    nonisolated private func totalFocus(
        on date: Date,
        period: StatisticsPeriod,
        records: [StatisticsPeriodFlowRecord]
    ) -> Int {
        records.reduce(0) { result, record in
            let day = dayBoundary.day(containing: record.startedAt, calendar: calendar)
            return result + (sameTrendBucket(day, date, period: period) ? max(0, record.focusSeconds) : 0)
        }
    }

    nonisolated private func completionCount(
        on date: Date,
        period: StatisticsPeriod,
        records: [StatisticsPeriodAchievementRecord]
    ) -> Int {
        records.reduce(0) { result, record in
            let day = dayBoundary.day(containing: record.completedAt, calendar: calendar)
            return result + (sameTrendBucket(day, date, period: period) ? 1 : 0)
        }
    }

    nonisolated private func sameTrendBucket(_ lhs: Date, _ rhs: Date, period: StatisticsPeriod) -> Bool {
        if period == .year {
            return calendar.isDate(lhs, equalTo: rhs, toGranularity: .month)
        }
        return calendar.isDate(lhs, inSameDayAs: rhs)
    }

    private enum DistributionDimension {
        case task
        case direction
    }

    private struct DistributionAccumulator {
        var name: String
        var symbol: String?
        var colors: [WeightedHexColor]
        var focusSeconds: Int
    }

    nonisolated private func makeDistribution(
        flows: [StatisticsPeriodFlowRecord],
        dimension: DistributionDimension
    ) -> [StatisticsDistributionItem] {
        var grouped: [String: DistributionAccumulator] = [:]

        for record in flows where record.focusSeconds > 0 {
            let key: String
            let name: String
            let symbol: String?
            switch dimension {
            case .task:
                let title = record.todoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                key = title.isEmpty ? "task:unassigned" : "task:\(title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))"
                name = title.isEmpty ? String(localized: "タスクなし") : title
                symbol = nil
            case .direction:
                key = record.directionID.map { "direction:\($0.uuidString)" } ?? "direction:other"
                name = record.directionName.isEmpty ? String(localized: "その他") : record.directionName
                symbol = record.directionSymbol.isEmpty ? nil : record.directionSymbol
            }

            var accumulator = grouped[key] ?? DistributionAccumulator(
                name: name,
                symbol: symbol,
                colors: [],
                focusSeconds: 0
            )
            accumulator.focusSeconds += record.focusSeconds
            if let color = record.directionColorHex {
                accumulator.colors.append(WeightedHexColor(hex: color, weight: record.focusSeconds))
            }
            grouped[key] = accumulator
        }

        let sorted = grouped.map { key, value in
            StatisticsDistributionItem(
                id: key,
                name: value.name,
                symbol: value.symbol,
                colorHex: StatisticsHeatmapBuilder.mixedHexColor(value.colors),
                focusSeconds: value.focusSeconds
            )
        }.sorted {
            if $0.focusSeconds != $1.focusSeconds { return $0.focusSeconds > $1.focusSeconds }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }

        guard sorted.count > 6 else { return sorted }
        let visible = Array(sorted.prefix(5))
        let remainder = Array(sorted.dropFirst(5))
        let remainderSeconds = remainder.reduce(0) { $0 + $1.focusSeconds }
        let colors = remainder.compactMap { item -> WeightedHexColor? in
            guard let color = item.colorHex else { return nil }
            return WeightedHexColor(hex: color, weight: item.focusSeconds)
        }
        return visible + [StatisticsDistributionItem(
            id: "distribution:other",
            name: String(localized: "その他"),
            symbol: nil,
            colorHex: StatisticsHeatmapBuilder.mixedHexColor(colors),
            focusSeconds: remainderSeconds
        )]
    }

    nonisolated private func makeFlowDays(
        days: [Date],
        flows: [StatisticsPeriodFlowRecord]
    ) -> [StatisticsDay] {
        let grouped = Dictionary(grouping: flows) {
            dayBoundary.day(containing: $0.startedAt, calendar: calendar)
        }
        return days.map { date in
            let records = grouped[date] ?? []
            return StatisticsDay(
                date: date,
                totalFocusSeconds: records.reduce(0) { $0 + max(0, $1.focusSeconds) },
                mixedColorHex: StatisticsHeatmapBuilder.mixedHexColor(records.compactMap {
                    guard let color = $0.directionColorHex else { return nil }
                    return WeightedHexColor(hex: color, weight: $0.focusSeconds)
                }),
                directionCount: Set(records.compactMap(\.directionID)).count,
                sessionCount: Set(records.map(\.sessionID)).count
            )
        }
    }

    nonisolated private func makeAchievementDays(
        days: [Date],
        achievements: [StatisticsPeriodAchievementRecord]
    ) -> [AchievementDay] {
        let grouped = Dictionary(grouping: achievements) {
            dayBoundary.day(containing: $0.completedAt, calendar: calendar)
        }
        return days.map { date in
            let records = grouped[date] ?? []
            return AchievementDay(
                date: date,
                completedCount: records.count,
                mixedColorHex: StatisticsHeatmapBuilder.mixedHexColor(records.compactMap {
                    guard let color = $0.directionColorHex else { return nil }
                    return WeightedHexColor(hex: color, weight: 1)
                }),
                directionCount: Set(records.compactMap(\.directionID)).count
            )
        }
    }

    nonisolated private struct CSVKey: Hashable {
        let day: Date
        let task: String
        let direction: String

        nonisolated static func == (lhs: CSVKey, rhs: CSVKey) -> Bool {
            lhs.day == rhs.day && lhs.task == rhs.task && lhs.direction == rhs.direction
        }

        nonisolated func hash(into hasher: inout Hasher) {
            hasher.combine(day)
            hasher.combine(task)
            hasher.combine(direction)
        }
    }

    private struct CSVAccumulator {
        var task: String
        var direction: String
        var hashtags: Set<String>
        var focusedSeconds: Int
        var sessionIDs: Set<UUID>
        var completedTaskCount: Int
    }

    nonisolated private func makeCSVRows(
        flows: [StatisticsPeriodFlowRecord],
        achievements: [StatisticsPeriodAchievementRecord]
    ) -> [StatisticsCSVRow] {
        var grouped: [CSVKey: CSVAccumulator] = [:]

        for record in flows {
            let day = dayBoundary.day(containing: record.startedAt, calendar: calendar)
            let task = record.todoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let direction = record.directionName.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = CSVKey(day: day, task: normalized(task), direction: normalized(direction))
            var value = grouped[key] ?? CSVAccumulator(
                task: task,
                direction: direction,
                hashtags: [],
                focusedSeconds: 0,
                sessionIDs: [],
                completedTaskCount: 0
            )
            value.focusedSeconds += max(0, record.focusSeconds)
            value.sessionIDs.insert(record.sessionID)
            value.hashtags.formUnion(record.todoHashtags)
            grouped[key] = value
        }

        for record in achievements {
            let day = dayBoundary.day(containing: record.completedAt, calendar: calendar)
            let task = record.todoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let direction = record.directionName.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = CSVKey(day: day, task: normalized(task), direction: normalized(direction))
            var value = grouped[key] ?? CSVAccumulator(
                task: task,
                direction: direction,
                hashtags: [],
                focusedSeconds: 0,
                sessionIDs: [],
                completedTaskCount: 0
            )
            value.completedTaskCount += 1
            value.hashtags.formUnion(record.todoHashtags)
            grouped[key] = value
        }

        return grouped.map { key, value in
            StatisticsCSVRow(
                date: key.day,
                task: value.task,
                direction: value.direction,
                hashtags: value.hashtags.sorted { $0.localizedStandardCompare($1) == .orderedAscending },
                focusedSeconds: value.focusedSeconds,
                flowCount: value.sessionIDs.count,
                completedTaskCount: value.completedTaskCount
            )
        }.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.task != $1.task { return $0.task.localizedStandardCompare($1.task) == .orderedAscending }
            return $0.direction.localizedStandardCompare($1.direction) == .orderedAscending
        }
    }

    nonisolated private func normalized(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    nonisolated private func dates(from start: Date, to end: Date) -> [Date] {
        guard start < end else { return [] }
        var result: [Date] = []
        var date = start
        while date < end {
            result.append(date)
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return result
    }

    nonisolated private func monthStarts(from start: Date, to end: Date) -> [Date] {
        guard start < end else { return [] }
        var result: [Date] = []
        var date = start
        while date < end {
            result.append(date)
            guard let next = calendar.date(byAdding: .month, value: 1, to: date) else { break }
            date = next
        }
        return result
    }
}
