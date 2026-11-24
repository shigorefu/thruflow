import Foundation
import SwiftData

struct DefaultAreaReconciliationResult: Equatable {
    var canonicalID: UUID
    var archivedDuplicateCount: Int
}

struct DefaultAreaReconciler {
    @discardableResult
    func reconcile(
        modelContext: ModelContext,
        now: Date = .now
    ) throws -> DefaultAreaReconciliationResult {
        let areas = try modelContext.fetch(FetchDescriptor<Area>())
        let candidates = areas
            .filter { !$0.isArchived && DefaultAreas.isTaskInboxRecord($0) }
            .sorted { DefaultAreas.canonicalOrder($0, $1) }

        guard let canonical = candidates.first else {
            let inbox = DefaultAreas.makeTaskInbox(now: now)
            modelContext.insert(inbox)
            try modelContext.save()
            return DefaultAreaReconciliationResult(
                canonicalID: inbox.id,
                archivedDuplicateCount: 0
            )
        }

        var didChange = false
        if canonical.systemRole != .taskInbox {
            canonical.systemRole = .taskInbox
            canonical.updatedAt = now
            didChange = true
        }

        let duplicates = Array(candidates.dropFirst())
        if !duplicates.isEmpty {
            let duplicateIDs = Set(duplicates.map(\.id))
            try reconnectRelationships(
                from: duplicateIDs,
                to: canonical,
                modelContext: modelContext
            )

            for duplicate in duplicates {
                duplicate.archive(now: now)
            }
            didChange = true
        }

        if didChange {
            try modelContext.save()
        }

        return DefaultAreaReconciliationResult(
            canonicalID: canonical.id,
            archivedDuplicateCount: duplicates.count
        )
    }

    private func reconnectRelationships(
        from duplicateIDs: Set<UUID>,
        to canonical: Area,
        modelContext: ModelContext
    ) throws {
        for todo in try modelContext.fetch(FetchDescriptor<Todo>())
        where todo.area.map({ duplicateIDs.contains($0.id) }) == true {
            todo.area = canonical
        }

        for session in try modelContext.fetch(FetchDescriptor<FlowSession>())
        where session.area.map({ duplicateIDs.contains($0.id) }) == true {
            session.area = canonical
        }

        for segment in try modelContext.fetch(FetchDescriptor<FlowSegment>())
        where segment.area.map({ duplicateIDs.contains($0.id) }) == true {
            segment.area = canonical
        }
    }
}
