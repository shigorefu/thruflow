//
//  DefaultAreas.swift
//  ThruFlow
//
//

import Foundation

enum DefaultAreas {
    static let taskInboxName = String(localized: "その他")
    static let taskInboxSymbol = "📝"
    static let taskInboxColorHex = "#007AFF"

    static func makeTaskInbox(now: Date = .now) -> Area {
        Area(
            name: taskInboxName,
            systemRole: .taskInbox,
            type: .neutral,
            symbolName: taskInboxSymbol,
            colorHex: taskInboxColorHex,
            createdAt: now,
            updatedAt: now
        )
    }

    static func existingTaskInbox(in areas: [Area]) -> Area? {
        areas
            .filter { isTaskInbox($0) }
            .min { canonicalOrder($0, $1) }
    }

    static func isTaskInbox(_ area: Area) -> Bool {
        !area.isArchived && isTaskInboxRecord(area)
    }

    static func isTaskInboxRecord(_ area: Area) -> Bool {
        if area.systemRole == .taskInbox {
            return true
        }

        return area.type == .neutral &&
            area.symbolName == taskInboxSymbol &&
            area.colorHex.caseInsensitiveCompare(taskInboxColorHex) == .orderedSame &&
            legacyTaskInboxNames.contains(area.name)
    }

    static func canonicalOrder(_ lhs: Area, _ rhs: Area) -> Bool {
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
