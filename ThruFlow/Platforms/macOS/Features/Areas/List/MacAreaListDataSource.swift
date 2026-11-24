#if os(macOS)
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct MacAreaListData {
    let areas: [Area]
    let projectsByArea: [UUID?: [Project]]
}

struct MacAreaListDataSource: View {
    @Query(sort: \Area.sortIndex) private var areas: [Area]
    @Query(sort: \Project.createdAt) private var projects: [Project]

    let onUpdate: (Result<MacAreaListData, Error>) -> Void

    var body: some View {
        let revision = Revision(
            areas: areas.map { RecordVersion(id: $0.id, updatedAt: $0.updatedAt) },
            projects: projects.map { RecordVersion(id: $0.id, updatedAt: $0.updatedAt) },
            failed: loadError != nil
        )
        Color.clear
            .onChange(of: revision, initial: true) { _, _ in
                if let loadError {
                    onUpdate(.failure(loadError))
                } else {
                    onUpdate(.success(MacAreaListData(
                        areas: areas,
                        projectsByArea: Dictionary(grouping: projects, by: { $0.area?.id })
                    )))
                }
            }
    }

    private var loadError: Error? { _areas.fetchError ?? _projects.fetchError }

    private struct RecordVersion: Equatable {
        let id: UUID
        let updatedAt: Date
    }

    private struct Revision: Equatable {
        let areas: [RecordVersion]
        let projects: [RecordVersion]
        let failed: Bool
    }
}
#endif
