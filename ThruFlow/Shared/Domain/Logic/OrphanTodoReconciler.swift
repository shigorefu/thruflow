import Foundation
import SwiftData

struct OrphanTodoReconciliationResult: Equatable {
    let reconnectedFromHistoryCount: Int
    let reconnectedFromHabitTemplateCount: Int

    var changed: Bool {
        reconnectedFromHistoryCount > 0 || reconnectedFromHabitTemplateCount > 0
    }
}

@MainActor
struct OrphanTodoReconciler {
    var calendar: Calendar = .current

    @discardableResult
    func reconcile(
        modelContext: ModelContext,
        now: Date = .now
    ) throws -> OrphanTodoReconciliationResult {
        let todos = try modelContext.fetch(FetchDescriptor<Todo>())
        let directions = try modelContext.fetch(FetchDescriptor<Direction>())
        let sessions = try modelContext.fetch(FetchDescriptor<FlowSession>())
        let segments = try modelContext.fetch(FetchDescriptor<FlowSegment>())
        let orphanTodos = todos.filter { !$0.isDeleted && $0.direction == nil }
        let planner = RequiredTodoPlanner(calendar: calendar)

        var historyCount = 0
        var templateCount = 0

        for todo in orphanTodos {
            if let direction = uniqueHistoryDirection(
                for: todo,
                sessions: sessions,
                segments: segments
            ) {
                todo.direction = direction
                todo.updatedAt = now
                historyCount += 1
                continue
            }

            let candidates = directions.filter { direction in
                guard planner.matchesGeneratedTemplate(todo, for: direction),
                      let scheduledDate = todo.scheduledDate else {
                    return false
                }

                return planner.existingRequiredTodo(
                    for: direction,
                    in: todos,
                    on: scheduledDate
                ) == nil
            }

            guard candidates.count == 1, let direction = candidates.first else {
                continue
            }

            todo.direction = direction
            todo.updatedAt = now
            templateCount += 1
        }

        let result = OrphanTodoReconciliationResult(
            reconnectedFromHistoryCount: historyCount,
            reconnectedFromHabitTemplateCount: templateCount
        )
        guard result.changed else { return result }

        let habitReconciliation = HabitTodoReconciler(calendar: calendar).reconcile(
            todos: todos,
            sessions: sessions,
            segments: segments,
            now: now
        )
        if habitReconciliation.changed {
            FlowProgressReconciler().reconcile(
                todos: habitReconciliation.canonicalTodos.map(Optional.some),
                directions: habitReconciliation.affectedDirections.map(Optional.some),
                modelContext: modelContext,
                now: now
            )
        }

        try modelContext.save()
        return result
    }

    private func uniqueHistoryDirection(
        for todo: Todo,
        sessions: [FlowSession],
        segments: [FlowSegment]
    ) -> Direction? {
        let sessionDirections = sessions.compactMap { session -> Direction? in
            guard session.todo?.id == todo.id else { return nil }
            return session.direction
        }
        let segmentDirections = segments.compactMap { segment -> Direction? in
            guard segment.todo?.id == todo.id else { return nil }
            return segment.direction
        }
        let directions = sessionDirections + segmentDirections
        let uniqueDirections = Dictionary(grouping: directions, by: \.id)
            .compactMap { $0.value.first }

        guard uniqueDirections.count == 1 else { return nil }
        return uniqueDirections[0]
    }
}
