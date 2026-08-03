import Foundation
import SwiftData

struct DefaultDirectionReconciliationResult: Equatable {
    var canonicalID: UUID
    var archivedDuplicateCount: Int
}

struct DefaultDirectionReconciler {
    @discardableResult
    func reconcile(
        modelContext: ModelContext,
        now: Date = .now
    ) throws -> DefaultDirectionReconciliationResult {
        let directions = try modelContext.fetch(FetchDescriptor<Direction>())
        let candidates = directions
            .filter { !$0.isArchived && DefaultDirections.isTaskInboxRecord($0) }
            .sorted { DefaultDirections.canonicalOrder($0, $1) }

        guard let canonical = candidates.first else {
            let inbox = DefaultDirections.makeTaskInbox(now: now)
            modelContext.insert(inbox)
            try modelContext.save()
            return DefaultDirectionReconciliationResult(
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

        return DefaultDirectionReconciliationResult(
            canonicalID: canonical.id,
            archivedDuplicateCount: duplicates.count
        )
    }

    private func reconnectRelationships(
        from duplicateIDs: Set<UUID>,
        to canonical: Direction,
        modelContext: ModelContext
    ) throws {
        for todo in try modelContext.fetch(FetchDescriptor<Todo>())
        where todo.direction.map({ duplicateIDs.contains($0.id) }) == true {
            todo.direction = canonical
        }

        for session in try modelContext.fetch(FetchDescriptor<FlowSession>())
        where session.direction.map({ duplicateIDs.contains($0.id) }) == true {
            session.direction = canonical
        }

        for segment in try modelContext.fetch(FetchDescriptor<FlowSegment>())
        where segment.direction.map({ duplicateIDs.contains($0.id) }) == true {
            segment.direction = canonical
        }
    }
}
