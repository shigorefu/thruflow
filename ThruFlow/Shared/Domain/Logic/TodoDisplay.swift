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

        if let areaName = todo.area?.name.trimmingCharacters(in: .whitespacesAndNewlines),
           !areaName.isEmpty {
            return "(\(areaName))"
        }

        return String(localized: "(その他)")
    }

    static func placeholder(for todo: Todo) -> String {
        if let areaName = todo.area?.name.trimmingCharacters(in: .whitespacesAndNewlines),
           !areaName.isEmpty {
            return "(\(areaName))"
        }

        return String(localized: "(その他)")
    }
}
