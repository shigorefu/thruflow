//
//  StatisticsCSVExporter.swift
//  ThruFlow
//
//  Created by Codex on 2026/08/03.
//

import Foundation

struct StatisticsCSVExporter: Sendable {
    nonisolated static let header = [
        "date",
        "task",
        "direction",
        "hashtags",
        "focused_seconds",
        "focused_minutes",
        "blocks",
        "flow_count",
        "completed_tasks"
    ]

    nonisolated func export(
        rows: [StatisticsCSVRow],
        calendar: Calendar = .current
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = calendar.timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale(identifier: "en_US_POSIX")
        numberFormatter.numberStyle = .decimal
        numberFormatter.usesGroupingSeparator = false
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 2

        let lines = rows.map { row in
            [
                dateFormatter.string(from: row.date),
                row.task,
                row.direction,
                row.hashtags.joined(separator: " "),
                String(row.focusedSeconds),
                numberFormatter.string(from: NSNumber(value: row.focusedMinutes)) ?? "0",
                numberFormatter.string(from: NSNumber(value: row.blocks)) ?? "0",
                String(row.flowCount),
                String(row.completedTaskCount)
            ].map(Self.escape).joined(separator: ",")
        }

        return ([Self.header.joined(separator: ",")] + lines).joined(separator: "\n") + "\n"
    }

    nonisolated private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
