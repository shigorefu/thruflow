//
//  AppDataResetActor.swift
//  ThruFlow
//

import Foundation
import SwiftData

@ModelActor
actor AppDataResetActor {
    func reset() throws -> AppDataResetResult {
        try AppDataResetService().reset(modelContext: modelContext)
    }
}
