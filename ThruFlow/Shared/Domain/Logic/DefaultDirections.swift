//
//  DefaultDirections.swift
//  ThruFlow
//
//

import Foundation

enum DefaultDirections {
    static let taskInboxName = String(localized: "その他")
    static let taskInboxSymbol = "📝"
    static let taskInboxColorHex = "#007AFF"

    static func makeTaskInbox(now: Date = .now) -> Direction {
        Direction(
            name: taskInboxName,
            systemRole: .taskInbox,
            type: .neutral,
            symbolName: taskInboxSymbol,
            colorHex: taskInboxColorHex,
            createdAt: now,
            updatedAt: now
        )
    }

    static func existingTaskInbox(in directions: [Direction]) -> Direction? {
        directions
            .filter { isTaskInbox($0) }
            .min { canonicalOrder($0, $1) }
    }

    static func isTaskInbox(_ direction: Direction) -> Bool {
        !direction.isArchived && isTaskInboxRecord(direction)
    }

    static func isTaskInboxRecord(_ direction: Direction) -> Bool {
        if direction.systemRole == .taskInbox {
            return true
        }

        return direction.type == .neutral &&
            direction.symbolName == taskInboxSymbol &&
            direction.colorHex.caseInsensitiveCompare(taskInboxColorHex) == .orderedSame &&
            legacyTaskInboxNames.contains(direction.name)
    }

    static func canonicalOrder(_ lhs: Direction, _ rhs: Direction) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static let legacyTaskInboxNames: Set<String> = [
        "その他", // localisation-audit: persisted-value
        "Other",
        "Другое",
    ]
}
