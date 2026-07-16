//
//  FlowProgressReconciler.swift
//  ThruFlow
//

import Foundation
import SwiftData

struct FlowProgressReconciler {
    func reconcileAll(modelContext: ModelContext, now: Date = .now) {
        guard let todos = try? modelContext.fetch(FetchDescriptor<Todo>()),
              let directions = try? modelContext.fetch(FetchDescriptor<Direction>()) else {
            return
        }
        reconcile(
            todos: todos,
            directions: directions,
            modelContext: modelContext,
            now: now
        )
    }

    func reconcile(
        session: FlowSession,
        modelContext: ModelContext,
        excludingSessionIDs: Set<UUID> = [],
        excludingSegmentIDs: Set<UUID> = [],
        now: Date = .now
    ) {
        reconcile(
            todos: [session.todo] + session.segments.map(\.todo),
            directions: [session.direction] + session.segments.map(\.direction),
            modelContext: modelContext,
            excludingSessionIDs: excludingSessionIDs,
            excludingSegmentIDs: excludingSegmentIDs,
            now: now
        )
    }

    func reconcile(
        todos: [Todo?],
        directions: [Direction?],
        modelContext: ModelContext,
        excludingSessionIDs: Set<UUID> = [],
        excludingSegmentIDs: Set<UUID> = [],
        now: Date = .now
    ) {
        guard let storedSessions = try? modelContext.fetch(FetchDescriptor<FlowSession>()) else {
            return
        }
        let sessions = storedSessions.filter {
            !excludingSessionIDs.contains($0.id) && contributesToProgress($0)
        }
        let uniqueTodos = unique(todos.compactMap { $0 })
        let uniqueDirections = unique(directions.compactMap { $0 })

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

        for direction in uniqueDirections {
            direction.recordedFocusSeconds = sessions.reduce(0) { total, session in
                total + focusSeconds(
                    in: session,
                    directionID: direction.id,
                    excludingSegmentIDs: excludingSegmentIDs
                )
            }
            direction.updatedAt = now
        }
    }

    private func contributesToProgress(_ session: FlowSession) -> Bool {
        switch session.status {
        case .breakTime, .awaitingResult, .completed:
            true
        case .active, .paused, .interrupted:
            false
        }
    }

    private func focusSeconds(
        in session: FlowSession,
        todoID: UUID,
        excludingSegmentIDs: Set<UUID>
    ) -> Int {
        if !session.segments.isEmpty {
            return session.segments.reduce(0) { total, segment in
                guard !excludingSegmentIDs.contains(segment.id), segment.todo?.id == todoID else {
                    return total
                }
                return total + segment.resolvedFocusSeconds
            }
        }

        return session.todo?.id == todoID ? session.resolvedActualFocusDurationSeconds : 0
    }

    private func focusSeconds(
        in session: FlowSession,
        directionID: UUID,
        excludingSegmentIDs: Set<UUID>
    ) -> Int {
        if !session.segments.isEmpty {
            return session.segments.reduce(0) { total, segment in
                guard !excludingSegmentIDs.contains(segment.id), segment.direction?.id == directionID else {
                    return total
                }
                return total + segment.resolvedFocusSeconds
            }
        }

        return session.direction?.id == directionID ? session.resolvedActualFocusDurationSeconds : 0
    }

    private func unique<Model: AnyObject & Identifiable>(_ models: [Model]) -> [Model] where Model.ID == UUID {
        var seen = Set<UUID>()
        return models.filter { seen.insert($0.id).inserted }
    }
}
