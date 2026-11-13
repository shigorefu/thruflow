#if os(iOS)
import SwiftData
import SwiftUI

struct IOSTaskCalendarRecords {
    let todos: [Todo]
    let areas: [Area]
    let projects: [Project]
    let snapshot: TaskCalendarSnapshot
}

struct IOSTaskCalendarQuery: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
    @Query(sort: \Todo.sortIndex) private var todos: [Todo]
    @Query(sort: \Area.sortIndex) private var areas: [Area]
    @Query(sort: \Project.createdAt) private var projects: [Project]

    let calendarDayRevision: Int
    let onUpdate: (Result<IOSTaskCalendarRecords, Error>) -> Void

    var body: some View {
        let revisions = [
            todos.map { RecordRevision(id: $0.id, updatedAt: $0.updatedAt) },
            areas.map { RecordRevision(id: $0.id, updatedAt: $0.updatedAt) },
            projects.map { RecordRevision(id: $0.id, updatedAt: $0.updatedAt) }
        ]
        let error = _todos.fetchError ?? _areas.fetchError ?? _projects.fetchError
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task(id: QueryRevision(
                records: revisions,
                calendar: calendar,
                dayBoundaryHour: dayBoundary.hour,
                calendarDayRevision: calendarDayRevision,
                failed: error != nil
            )) {
                guard !Task.isCancelled else { return }
                if let error {
                    onUpdate(.failure(error))
                    return
                }
                let snapshot = TaskCalendarSnapshot(todos: todos, calendar: calendar, dayBoundary: dayBoundary)
                onUpdate(.success(IOSTaskCalendarRecords(todos: todos, areas: areas, projects: projects, snapshot: snapshot)))
            }
    }

    private struct RecordRevision: Hashable {
        let id: UUID
        let updatedAt: Date
    }

    private struct QueryRevision: Hashable {
        let records: [[RecordRevision]]
        let calendar: Calendar
        let dayBoundaryHour: Int
        let calendarDayRevision: Int
        let failed: Bool
    }
}
#endif
