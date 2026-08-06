//
//  FlowHistoryDeletionService.swift
//  ThruFlow
//

import Foundation
import SwiftData

struct FlowHistoryDeletionResult: Equatable, Sendable {
    let deletedFlowCount: Int
    let deletedBreakCount: Int
}

enum FlowHistoryDeletionError: Error, Equatable {
    case activeFlowExists
}

struct FlowHistoryDeletionService {
    nonisolated init() {}

    @discardableResult
    nonisolated func deleteAll(
        modelContext: ModelContext,
        now: Date = .now
    ) throws -> FlowHistoryDeletionResult {
        do {
            let sessions = try modelContext.fetch(FetchDescriptor<FlowSession>())

            guard !sessions.contains(where: { $0.reconstructableTimerState != nil }) else {
                throw FlowHistoryDeletionError.activeFlowExists
            }

            let breaks = try modelContext.fetch(FetchDescriptor<FlowBreak>())
            let segments = try modelContext.fetch(FetchDescriptor<FlowSegment>())
            let todos = try modelContext.fetch(FetchDescriptor<Todo>())
            let directions = try modelContext.fetch(FetchDescriptor<Direction>())
            var hasChanges = !sessions.isEmpty || !breaks.isEmpty || !segments.isEmpty

            for segment in segments {
                modelContext.delete(segment)
            }
            for session in sessions {
                modelContext.delete(session)
            }
            for flowBreak in breaks {
                modelContext.delete(flowBreak)
            }

            for todo in todos {
                let needsFocusReset = todo.recordedFocusSeconds != 0

                if todo.measurement == .checkbox {
                    guard needsFocusReset else { continue }
                    todo.recordedFocusSeconds = 0
                    todo.updatedAt = now
                    hasChanges = true
                    continue
                }

                let needsProgressReset = todo.actualProgress != 0 || todo.completedAt != nil
                let needsStatusReset = !todo.isArchived && todo.status != .active
                guard needsFocusReset || needsProgressReset || needsStatusReset else { continue }

                todo.recordedFocusSeconds = 0
                if todo.isArchived {
                    todo.actualProgress = 0
                    todo.completedAt = nil
                    todo.updatedAt = now
                } else {
                    todo.setProgress(0, now: now)
                }
                hasChanges = true
            }

            for direction in directions where direction.recordedFocusSeconds != 0 {
                direction.recordedFocusSeconds = 0
                direction.updatedAt = now
                hasChanges = true
            }

            if hasChanges {
                let latestSessions = try modelContext.fetch(FetchDescriptor<FlowSession>())
                guard !latestSessions.contains(where: { $0.reconstructableTimerState != nil }) else {
                    throw FlowHistoryDeletionError.activeFlowExists
                }
                try modelContext.save()
            }
            return FlowHistoryDeletionResult(
                deletedFlowCount: sessions.count,
                deletedBreakCount: breaks.count
            )
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
