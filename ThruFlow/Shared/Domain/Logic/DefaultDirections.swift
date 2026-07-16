//
//  DefaultDirections.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import Foundation

enum DefaultDirections {
    static let taskInboxName = "その他"
    static let taskInboxSymbol = "📝"
    static let taskInboxColorHex = "#007AFF"

    static func makeTaskInbox(now: Date = .now) -> Direction {
        Direction(
            name: taskInboxName,
            type: .neutral,
            symbolName: taskInboxSymbol,
            colorHex: taskInboxColorHex,
            createdAt: now,
            updatedAt: now
        )
    }

    static func existingTaskInbox(in directions: [Direction]) -> Direction? {
        directions.first {
            isTaskInbox($0)
        }
    }

    static func isTaskInbox(_ direction: Direction) -> Bool {
        !direction.isArchived &&
        direction.type == .neutral &&
        direction.name == taskInboxName
    }
}
