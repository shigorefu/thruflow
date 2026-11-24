//
//  StatisticsPeriodSelection.swift
//  ThruFlow
//
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

struct StatisticsPeriodFilter: Hashable, Sendable {
    var period: StatisticsPeriod = .week
    var anchorDate: Date = .now
    var customStartDate: Date?
    var customEndDate: Date?
    var areaIDs: Set<UUID> = []
    var query = ""

    nonisolated var usesCustomRange: Bool {
        customStartDate != nil && customEndDate != nil
    }
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
