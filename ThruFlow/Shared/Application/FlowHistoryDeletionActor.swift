//
//  FlowHistoryDeletionActor.swift
//  ThruFlow
//

import Foundation
import SwiftData

@ModelActor
actor FlowHistoryDeletionActor {
    func deleteAll(now: Date = .now) throws -> FlowHistoryDeletionResult {
        try FlowHistoryDeletionService().deleteAll(
            modelContext: modelContext,
            now: now
        )
    }
}
