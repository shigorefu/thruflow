//
//  DashboardStatisticsBuilder.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/15.
//

import Foundation

struct DashboardStatisticsDay: Identifiable {
    let date: Date
    let focusSeconds: Int
    let colorHex: String

    var id: Date { date }
}

struct DashboardStatisticsDirectionGrowth {
    let symbol: String
    let name: String
    let focusSecondsDelta: Int
}

struct DashboardStatisticsComparison {
    let focusSecondsDelta: Int
    let completedTaskDelta: Int
    let blocksDelta: Double
    let growingDirection: DashboardStatisticsDirectionGrowth?
}

struct DashboardStatisticsBuilder {
    private let calendar: Calendar
    private let dashboardBuilder: FlowDashboardBuilder

    init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.dashboardBuilder = FlowDashboardBuilder(calendar: calendar)
    }

    func days(
        count: Int,
        endingOn date: Date,
        sessions: [FlowSession],
        breaks: [FlowBreak]
    ) -> [DashboardStatisticsDay] {
        let count = max(1, count)
        let endDay = calendar.startOfDay(for: date)

        return (0..<count).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: endDay) else {
                return nil
            }
            let snapshot = dashboardBuilder.build(date: day, sessions: sessions, breaks: breaks)
            return DashboardStatisticsDay(
                date: day,
                focusSeconds: snapshot.totalFocusSeconds,
                colorHex: snapshot.directionSummaries.first?.colorHex ?? "#8E8E93"
            )
        }
    }

    func comparison(
        on date: Date,
        sessions: [FlowSession],
        breaks: [FlowBreak],
        todos: [Todo]
    ) -> DashboardStatisticsComparison {
        let day = calendar.startOfDay(for: date)
        let previousDay = calendar.date(byAdding: .day, value: -1, to: day)
            ?? day.addingTimeInterval(-86_400)
        let current = dashboardBuilder.build(date: day, sessions: sessions, breaks: breaks)
        let previous = dashboardBuilder.build(date: previousDay, sessions: sessions, breaks: breaks)

        let previousByDirection = Dictionary(
            uniqueKeysWithValues: previous.directionSummaries.map { ($0.id, $0.focusSeconds) }
        )
        let growth = current.directionSummaries
            .map { summary in
                DashboardStatisticsDirectionGrowth(
                    symbol: summary.symbol,
                    name: summary.name,
                    focusSecondsDelta: summary.focusSeconds - (previousByDirection[summary.id] ?? 0)
                )
            }
            .filter { $0.focusSecondsDelta > 0 }
            .max { $0.focusSecondsDelta < $1.focusSecondsDelta }

        return DashboardStatisticsComparison(
            focusSecondsDelta: current.totalFocusSeconds - previous.totalFocusSeconds,
            completedTaskDelta: completedTaskCount(on: day, todos: todos)
                - completedTaskCount(on: previousDay, todos: todos),
            blocksDelta: current.blocks - previous.blocks,
            growingDirection: growth
        )
    }

    private func completedTaskCount(on date: Date, todos: [Todo]) -> Int {
        todos.filter { todo in
            guard !todo.isDeleted,
                  let completedAt = todo.completedAt else {
                return false
            }
            return calendar.isDate(completedAt, inSameDayAs: date)
        }
        .count
    }
}
