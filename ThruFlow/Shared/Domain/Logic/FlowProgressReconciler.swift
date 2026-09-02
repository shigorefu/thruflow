//
//  FlowProgressReconciler.swift
//  ThruFlow
//

import Foundation
import SwiftData

struct FlowProgressReconciler {
    nonisolated init() {}

    nonisolated func reconcileAll(modelContext: ModelContext, now: Date = .now) throws {
        let todos = try modelContext.fetch(FetchDescriptor<Todo>())
        let areas = try modelContext.fetch(FetchDescriptor<Area>())
        try reconcile(
            todos: todos,
            areas: areas,
            modelContext: modelContext,
            now: now
        )
    }

    nonisolated func reconcile(
        session: FlowSession,
        modelContext: ModelContext,
        excludingSessionIDs: Set<UUID> = [],
        excludingSegmentIDs: Set<UUID> = [],
        now: Date = .now
    ) throws {
        try reconcile(
            todos: [session.todo] + session.resolvedSegments.map(\.todo),
            areas: [session.area] + session.resolvedSegments.map(\.area),
            modelContext: modelContext,
            excludingSessionIDs: excludingSessionIDs,
            excludingSegmentIDs: excludingSegmentIDs,
            now: now
        )
    }

    nonisolated func reconcile(
        todos: [Todo?],
        areas: [Area?],
        modelContext: ModelContext,
        excludingSessionIDs: Set<UUID> = [],
        excludingSegmentIDs: Set<UUID> = [],
        now: Date = .now
    ) throws {
        let storedSessions = try modelContext.fetch(FetchDescriptor<FlowSession>())
        let sessions = storedSessions.filter {
            !excludingSessionIDs.contains($0.id) && contributesToProgress($0)
        }
        let uniqueTodos = unique(todos.compactMap { $0 })
        let uniqueAreas = unique(areas.compactMap { $0 })

        for todo in uniqueTodos where todo.measurement != .checkbox {
            let seconds = sessions.reduce(0) { total, session in
                total + focusSeconds(
                    in: session,
                    todoID: todo.id,
                    excludingSegmentIDs: excludingSegmentIDs
                )
            }
            todo.recordedFocusSeconds = seconds

            switch todo.measurement {
            case .checkbox:
                break
            case .focusBlocks:
                todo.setProgress(BlockUnit.wholeBlocks(forFocusedSeconds: seconds), now: now)
            case .minutes:
                todo.setProgress(seconds / 60, now: now)
            }
        }

        for area in uniqueAreas {
            area.recordedFocusSeconds = sessions.reduce(0) { total, session in
                total + focusSeconds(
                    in: session,
                    areaID: area.id,
                    excludingSegmentIDs: excludingSegmentIDs
                )
            }
            area.updatedAt = now
        }
    }

    nonisolated private func contributesToProgress(_ session: FlowSession) -> Bool {
        switch session.status {
        case .breakTime, .awaitingResult, .completed:
            true
        case .active, .paused, .interrupted:
            false
        }
    }

    nonisolated private func focusSeconds(
        in session: FlowSession,
        todoID: UUID,
        excludingSegmentIDs: Set<UUID>
    ) -> Int {
        if !session.resolvedSegments.isEmpty {
            return session.resolvedSegments.reduce(0) { total, segment in
                guard !excludingSegmentIDs.contains(segment.id), segment.todo?.id == todoID else {
                    return total
                }
                return total + segment.resolvedFocusSeconds
            }
        }

        return session.todo?.id == todoID ? session.resolvedActualFocusDurationSeconds : 0
    }

    nonisolated private func focusSeconds(
        in session: FlowSession,
        areaID: UUID,
        excludingSegmentIDs: Set<UUID>
    ) -> Int {
        if !session.resolvedSegments.isEmpty {
            return session.resolvedSegments.reduce(0) { total, segment in
                guard !excludingSegmentIDs.contains(segment.id), segment.area?.id == areaID else {
                    return total
                }
                return total + segment.resolvedFocusSeconds
            }
        }

        return session.area?.id == areaID ? session.resolvedActualFocusDurationSeconds : 0
    }

    nonisolated private func unique<Model: AnyObject & Identifiable>(_ models: [Model]) -> [Model] where Model.ID == UUID {
        var seen = Set<UUID>()
        return models.filter { seen.insert($0.id).inserted }
    }
}
