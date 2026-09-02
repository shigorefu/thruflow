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
        let areas = try modelContext.fetch(FetchDescriptor<Area>())
        let sessions = try modelContext.fetch(FetchDescriptor<FlowSession>())
        let segments = try modelContext.fetch(FetchDescriptor<FlowSegment>())
        let orphanTodos = todos.filter { !$0.isDeleted && $0.area == nil }
        let planner = RequiredTodoPlanner(calendar: calendar)

        var historyCount = 0
        var templateCount = 0

        for todo in orphanTodos {
            if let area = uniqueHistoryArea(
                for: todo,
                sessions: sessions,
                segments: segments
            ) {
                todo.area = area
                todo.updatedAt = now
                historyCount += 1
                continue
            }

            let candidates = areas.filter { area in
                guard planner.matchesGeneratedTemplate(todo, for: area),
                      let scheduledDate = todo.scheduledDate else {
                    return false
                }

                return planner.existingRequiredTodo(
                    for: area,
                    in: todos,
                    on: scheduledDate
                ) == nil
            }

            guard candidates.count == 1, let area = candidates.first else {
                continue
            }

            todo.area = area
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
            try FlowProgressReconciler().reconcile(
                todos: habitReconciliation.canonicalTodos.map(Optional.some),
                areas: habitReconciliation.affectedAreas.map(Optional.some),
                modelContext: modelContext,
                now: now
            )
        }

        try modelContext.save()
        return result
    }

    private func uniqueHistoryArea(
        for todo: Todo,
        sessions: [FlowSession],
        segments: [FlowSegment]
    ) -> Area? {
        let sessionAreas = sessions.compactMap { session -> Area? in
            guard session.todo?.id == todo.id else { return nil }
            return session.area
        }
        let segmentAreas = segments.compactMap { segment -> Area? in
            guard segment.todo?.id == todo.id else { return nil }
            return segment.area
        }
        let areas = sessionAreas + segmentAreas
        let uniqueAreas = Dictionary(grouping: areas, by: \.id)
            .compactMap { $0.value.first }

        guard uniqueAreas.count == 1 else { return nil }
        return uniqueAreas[0]
    }
}
