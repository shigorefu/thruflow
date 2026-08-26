//
//  StatisticsCSVExporter.swift
//  ThruFlow
//
//

import Foundation

enum StatisticsCSVContent: String, CaseIterable, Identifiable, Sendable {
    case all
    case flow
    case task

    var id: String { rawValue }
}

struct StatisticsCSVExporter: Sendable {
    nonisolated init() {}

    nonisolated static let commonHeader = [
        "date",
        "task",
        "direction",
        "hashtags"
    ]

    nonisolated static let flowHeader = commonHeader + [
        "focused_seconds",
        "focused_minutes",
        "blocks",
        "flow_count"
    ]

    nonisolated static let taskHeader = commonHeader + [
        "completed_tasks"
    ]

    nonisolated static let header = flowHeader + ["completed_tasks"]

    nonisolated func export(
        rows: [StatisticsCSVRow],
        content: StatisticsCSVContent = .all,
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

        let includedRows = rows.filter { row in
            switch content {
            case .all:
                true
            case .flow:
                row.focusedSeconds > 0 || row.flowCount > 0
            case .task:
                row.completedTaskCount > 0
            }
        }

        let lines = includedRows.map { row in
            let commonValues = [
                dateFormatter.string(from: row.date),
                row.task,
                row.direction,
                row.hashtags.joined(separator: " ")
            ]
            let flowValues = [
                String(row.focusedSeconds),
                numberFormatter.string(from: NSNumber(value: row.focusedMinutes)) ?? "0",
                numberFormatter.string(from: NSNumber(value: row.blocks)) ?? "0",
                String(row.flowCount)
            ]
            let values: [String]
            switch content {
            case .all:
                values = commonValues + flowValues + [String(row.completedTaskCount)]
            case .flow:
                values = commonValues + flowValues
            case .task:
                values = commonValues + [String(row.completedTaskCount)]
            }
            return values.map(Self.escape).joined(separator: ",")
        }

        let header: [String]
        switch content {
        case .all:
            header = Self.header
        case .flow:
            header = Self.flowHeader
        case .task:
            header = Self.taskHeader
        }
        return ([header.joined(separator: ",")] + lines).joined(separator: "\n") + "\n"
    }

    nonisolated private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
