//
//  FlowProgressReconciliationActor.swift
//  ThruFlow
//

import Foundation
import SwiftData

@ModelActor
actor FlowProgressReconciliationActor {
    func reconcileAll(now: Date = .now) throws {
        FlowProgressReconciler().reconcileAll(modelContext: modelContext, now: now)
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }
}
