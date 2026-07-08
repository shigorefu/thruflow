//
//  ThruFlowApp.swift
//  ThruFlow
//
//  Created by エドワード on 2026/07/08.
//

import SwiftUI
import SwiftData

@main
struct ThruFlowApp: App {
    @StateObject private var activeFlowStore = ActiveFlowStore()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Direction.self,
            Todo.self,
            FlowSession.self,
        ])
        let processInfo = ProcessInfo.processInfo
        let isRunningTests = processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            processInfo.arguments.contains("--uitesting")
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isRunningTests)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(activeFlowStore)
        }
        .modelContainer(sharedModelContainer)

#if os(macOS)
        MenuBarExtra("スルフロ Flow", systemImage: "timer") {
            FlowMiniPlayerView()
                .environmentObject(activeFlowStore)
                .frame(width: 560)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(sharedModelContainer)
#endif
    }
}
