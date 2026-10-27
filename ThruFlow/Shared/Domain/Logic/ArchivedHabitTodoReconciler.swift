import Foundation

/// Removes unused generated occurrences that were planned before an Area was archived.
/// Existing fields and soft deletion keep historical and synchronized records intact.
nonisolated struct ArchivedHabitTodoReconciler {
    var calendar: Calendar = .current
    var dayBoundary: AppDayBoundary = .midnight

    @discardableResult
    func reconcile(todos: [Todo], now: Date = .now) -> Bool {
        var changed = false
        for todo in todos {
            guard HabitDefinition(todo: todo) != nil,
                  let scheduledDate = todo.scheduledDate,
                  !todo.isDeleted, !todo.isArchived, !todo.isCompleted,
                  todo.actualProgress == 0, todo.recordedFocusSeconds == 0,
                  (todo.flowSessions?.isEmpty ?? true),
                  (todo.flowSegments?.isEmpty ?? true),
                  isInactive(todo, on: calendar.startOfDay(for: scheduledDate)) else { continue }
            todo.softDelete(now: now)
            changed = true
        }
        return changed
    }

    private func isInactive(_ todo: Todo, on day: Date) -> Bool {
        if let archivedAt = todo.area?.archivedAt,
           day >= dayBoundary.day(containing: archivedAt, calendar: calendar) { return true }
        // The settings relationship may arrive after the Todo from CloudKit.
        // Do not delete anything until its owner's configuration is available.
        if let project = todo.project, let settings = project.habitSettings {
            if let completedAt = project.completedAt,
               day >= dayBoundary.day(containing: completedAt, calendar: calendar) { return true }
            return settings.wasInactive(on: day)
        }
        return false
    }
}
