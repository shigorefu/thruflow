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
            guard todo.isHabitOccurrence,
                  let archivedAt = todo.area?.archivedAt,
                  let scheduledDate = todo.scheduledDate,
                  !todo.isDeleted, !todo.isArchived, !todo.isCompleted,
                  todo.actualProgress == 0, todo.recordedFocusSeconds == 0,
                  (todo.flowSessions?.isEmpty ?? true),
                  (todo.flowSegments?.isEmpty ?? true),
                  calendar.startOfDay(for: scheduledDate) >=
                    dayBoundary.day(containing: archivedAt, calendar: calendar) else { continue }
            todo.softDelete(now: now)
            changed = true
        }
        return changed
    }
}
