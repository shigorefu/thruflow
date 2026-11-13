#if os(macOS)
import SwiftData
import SwiftUI

struct MacTasksData {
    let areas: [Area]
    let todos: [Todo]
    let projects: [Project]
    let snapshot: TaskCalendarSnapshot
}

struct MacTasksDataSource: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
    @Query(sort: \Area.name) private var areas: [Area]
    @Query(sort: \Todo.sortIndex) private var todos: [Todo]
    @Query(sort: \Project.createdAt) private var projects: [Project]

    let dayRevision: Int
    let onUpdate: (Result<MacTasksData, Error>) -> Void

    var body: some View {
        let revision = Revision(
            areas: areas.map { RecordVersion(id: $0.id, updatedAt: $0.updatedAt) },
            todos: todos.map { RecordVersion(id: $0.id, updatedAt: $0.updatedAt) },
            projects: projects.map { RecordVersion(id: $0.id, updatedAt: $0.updatedAt) },
            calendar: calendar,
            dayBoundary: dayBoundary,
            dayRevision: dayRevision,
            failed: loadError != nil
        )

        Color.clear
            .onChange(of: revision, initial: true) { _, _ in
                if let loadError {
                    onUpdate(.failure(loadError))
                    return
                }
                onUpdate(.success(MacTasksData(
                    areas: areas,
                    todos: todos,
                    projects: projects,
                    snapshot: TaskCalendarSnapshot(todos: todos, calendar: calendar, dayBoundary: dayBoundary)
                )))
            }
    }

    private var loadError: Error? {
        _areas.fetchError ?? _todos.fetchError ?? _projects.fetchError
    }

    private struct RecordVersion: Equatable {
        let id: UUID
        let updatedAt: Date
    }

    private struct Revision: Equatable {
        let areas: [RecordVersion]
        let todos: [RecordVersion]
        let projects: [RecordVersion]
        let calendar: Calendar
        let dayBoundary: AppDayBoundary
        let dayRevision: Int
        let failed: Bool
    }
}
#endif
