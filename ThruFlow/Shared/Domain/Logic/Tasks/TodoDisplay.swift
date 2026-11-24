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

    /// Task lists and editors use the Project as a display fallback only.
    static func taskTitle(for todo: Todo) -> String {
        let title = todo.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? taskPlaceholder(for: todo) : title
    }

    static func taskPlaceholder(for todo: Todo) -> String {
        flowProjectName(for: todo) ?? placeholder(for: todo)
    }

    // Flow labels are projections only; never write a fallback into the Task title.
    static func flowTitle(for todo: Todo) -> String {
        taskTitle(for: todo)
    }

    static func flowPlaceholder(for todo: Todo) -> String {
        taskPlaceholder(for: todo)
    }

    static func flowProjectName(for todo: Todo?) -> String? {
        guard let name = todo?.project?.name.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }
        return name
    }

    static func flowContextName(for todo: Todo?, area: Area? = nil) -> String {
        let areaName = (todo?.area ?? area)?.name ?? String(localized: "その他")
        guard let projectName = flowProjectName(for: todo) else { return areaName }
        return areaName + "/" + projectName
    }

}
