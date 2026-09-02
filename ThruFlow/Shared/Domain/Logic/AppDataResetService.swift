//
//  AppDataResetService.swift
//  ThruFlow
//

import Foundation
import SwiftData

struct AppDataResetResult: Equatable, Sendable {
    let deletedAreaCount: Int
    let deletedTodoCount: Int
    let deletedFlowCount: Int
    let deletedBreakCount: Int
}

enum AppDataResetError: Error, Equatable {
    case activeFlowExists
}

struct AppDataResetService {
    nonisolated init() {}

    @discardableResult
    nonisolated func reset(modelContext: ModelContext) throws -> AppDataResetResult {
        do {
            let sessions = try modelContext.fetch(FetchDescriptor<FlowSession>())

            guard !sessions.contains(where: { $0.reconstructableTimerState != nil }) else {
                throw AppDataResetError.activeFlowExists
            }

            let segments = try modelContext.fetch(FetchDescriptor<FlowSegment>())
            let breaks = try modelContext.fetch(FetchDescriptor<FlowBreak>())
            let todos = try modelContext.fetch(FetchDescriptor<Todo>())
            let areas = try modelContext.fetch(FetchDescriptor<Area>())

            for segment in segments {
                modelContext.delete(segment)
            }
            for flowBreak in breaks {
                modelContext.delete(flowBreak)
            }
            for session in sessions {
                modelContext.delete(session)
            }
            for todo in todos {
                modelContext.delete(todo)
            }
            for area in areas {
                modelContext.delete(area)
            }

            let hasChanges = !segments.isEmpty ||
                !breaks.isEmpty ||
                !sessions.isEmpty ||
                !todos.isEmpty ||
                !areas.isEmpty

            if hasChanges {
                let latestSessions = try modelContext.fetch(FetchDescriptor<FlowSession>())
                guard !latestSessions.contains(where: { $0.reconstructableTimerState != nil }) else {
                    throw AppDataResetError.activeFlowExists
                }
                try modelContext.save()
            }

            return AppDataResetResult(
                deletedAreaCount: areas.count,
                deletedTodoCount: todos.count,
                deletedFlowCount: sessions.count,
                deletedBreakCount: breaks.count
            )
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
