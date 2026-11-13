#if os(iOS)
import SwiftData
import SwiftUI

struct IOSAreaRecords {
    let areas: [Area]
    let activeGroups: [AreaType: [Area]]
    let archivedGroups: [AreaType: [Area]]
    let projectsByArea: [UUID: [Project]]

    init(areas: [Area], projects: [Project]) {
        self.areas = areas
        let sortedAreas = areas.filter { !DefaultAreas.isTaskInbox($0) }.sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        activeGroups = Dictionary(grouping: sortedAreas.filter { !$0.isArchived }, by: \.type)
        archivedGroups = Dictionary(grouping: sortedAreas.filter(\.isArchived), by: \.type)
        let projectEntries = projects.compactMap { project in
            project.area.map { (areaID: $0.id, project: project) }
        }
        projectsByArea = Dictionary(grouping: projectEntries, by: \.areaID).mapValues { entries in
            let children = entries.map(\.project)
            return children.filter { !$0.isCompleted } + children.filter(\.isCompleted)
        }
    }
}

struct IOSAreasQuery: View {
    @Query(sort: \Area.sortIndex) private var areas: [Area]
    @Query(sort: \Project.createdAt) private var projects: [Project]

    let onUpdate: (Result<IOSAreaRecords, Error>) -> Void

    var body: some View {
        let revision = [
            areas.map { RecordRevision(id: $0.id, updatedAt: $0.updatedAt) },
            projects.map { RecordRevision(id: $0.id, updatedAt: $0.updatedAt) }
        ]
        let error = _areas.fetchError ?? _projects.fetchError
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task(id: QueryRevision(records: revision, failed: error != nil)) {
                guard !Task.isCancelled else { return }
                if let error {
                    onUpdate(.failure(error))
                } else {
                    onUpdate(.success(IOSAreaRecords(areas: areas, projects: projects)))
                }
            }
    }

    private struct RecordRevision: Hashable {
        let id: UUID
        let updatedAt: Date
    }

    private struct QueryRevision: Hashable {
        let records: [[RecordRevision]]
        let failed: Bool
    }
}
#endif
