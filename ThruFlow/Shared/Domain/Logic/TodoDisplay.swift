//
//  TodoDisplay.swift
//  ThruFlow
//
//

import Foundation

enum TodoDisplay {
    static func title(for todo: Todo) -> String {
        let title = todo.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            return title
        }

        if let directionName = todo.direction?.name.trimmingCharacters(in: .whitespacesAndNewlines),
           !directionName.isEmpty {
            return "(\(directionName))"
        }

        return String(localized: "(その他)")
    }

    static func placeholder(for todo: Todo) -> String {
        if let directionName = todo.direction?.name.trimmingCharacters(in: .whitespacesAndNewlines),
           !directionName.isEmpty {
            return "(\(directionName))"
        }

        return String(localized: "(その他)")
    }
}
