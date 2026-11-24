import Foundation

enum FlowMemoProjectPolicy {
    static func choices(for todo: Todo?, projects: [Project]) -> [Project] {
        guard let todo, todo.project == nil, !todo.isHabitOccurrence,
              !todo.isDeleted, !todo.isArchived else { return [] }
        return projects.filter { $0.area?.id == todo.area?.id && $0.isAvailableForNewTasks }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func validate(_ project: Project?, for todo: Todo?) throws {
        guard let project else { return }
        // A concurrent assignment wins over a stale open memo draft.
        if todo?.project != nil { return }
        guard let todo, !todo.isHabitOccurrence, !todo.isDeleted, !todo.isArchived,
              project.isAvailableForNewTasks else { throw TodoValidationError.unavailableProject }
        guard project.area?.id == todo.area?.id else { throw TodoValidationError.projectAreaMismatch }
    }
}
