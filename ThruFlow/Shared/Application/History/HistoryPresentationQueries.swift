import Foundation
import SwiftData

/// Loads the visible period for browsing. Explicit global searches use the full store.
struct HistoryPresentationQueries {
    let interval: DateInterval?
    let calendar: Calendar

    var sessions: FetchDescriptor<FlowSession> {
        let sort = [SortDescriptor(\FlowSession.startedAt)]
        guard let interval else { return FetchDescriptor(sortBy: sort) }
        let start = interval.start
        let end = interval.end
        return FetchDescriptor(
            predicate: #Predicate { session in
                session.startedAt <= end &&
                    (session.startedAt >= start || session.endedAt == nil ||
                        (session.endedAt ?? end) >= start)
            },
            sortBy: sort
        )
    }

    var breaks: FetchDescriptor<FlowBreak> {
        let sort = [SortDescriptor(\FlowBreak.startedAt)]
        guard let interval else { return FetchDescriptor(sortBy: sort) }
        let start = interval.start
        let end = interval.end
        return FetchDescriptor(
            predicate: #Predicate { record in
                record.deletedAt == nil && record.startedAt <= end &&
                    (record.startedAt >= start ||
                        (record.adjustedEndAt ?? record.connectedUntil ?? record.timerStoppedAt ?? end) >= start)
            },
            sortBy: sort
        )
    }

    var todos: FetchDescriptor<Todo> {
        let sort = [SortDescriptor(\Todo.updatedAt, order: .reverse)]
        guard let interval else { return FetchDescriptor(sortBy: sort) }
        let start = interval.start
        let end = interval.end
        let firstScheduledDay = calendar.startOfDay(for: start)
        let lastScheduledDay = calendar.startOfDay(for: end)
        let missing = Date.distantPast
        return FetchDescriptor(
            predicate: #Predicate { todo in
                todo.deletedAt == nil &&
                    (((todo.completedAt ?? todo.updatedAt) >= start &&
                        (todo.completedAt ?? todo.updatedAt) <= end) ||
                     ((todo.scheduledDate ?? missing) >= firstScheduledDay &&
                        (todo.scheduledDate ?? missing) <= lastScheduledDay))
            },
            sortBy: sort
        )
    }

    static func includingLinkedTodos(
        _ todos: [Todo],
        from sessions: [FlowSession],
        interval: DateInterval?
    ) -> [Todo] {
        guard let interval else { return todos }
        var result = todos
        var loadedIDs = Set(todos.map(\.id))
        for session in sessions where interval.contains(session.startedAt) {
            let segments = session.resolvedSegments
            let linkedTodos = segments.isEmpty
                ? [session.todo].compactMap { $0 }
                : segments.compactMap(\.todo)
            for todo in linkedTodos where loadedIDs.insert(todo.id).inserted {
                result.append(todo)
            }
        }
        return result
    }

    static func relatedSessions(for ids: [UUID]) -> FetchDescriptor<FlowSession> {
        FetchDescriptor(predicate: #Predicate { session in ids.contains(session.id) })
    }
}
