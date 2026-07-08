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

    private static var isRunningTests: Bool {
        let processInfo = ProcessInfo.processInfo
        return processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            processInfo.arguments.contains("--uitesting")
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Direction.self,
            Todo.self,
            FlowSession.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: Self.isRunningTests)

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
        MenuBarExtra {
            FlowMiniPlayerView()
                .environmentObject(activeFlowStore)
                .frame(width: 560)
        } label: {
            FlowMenuBarLabel()
                .environmentObject(activeFlowStore)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(sharedModelContainer)
#endif
    }
}

#if os(macOS)
private struct FlowMenuBarLabel: View {
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    var body: some View {
        if activeFlowStore.timerState == nil {
            Label("Flow", systemImage: "timer")
        } else {
            Text(menuTitle)
                .font(.system(.body, design: .monospaced))
                .monospacedDigit()
        }
    }

    private var menuTitle: String {
        guard activeFlowStore.timerState != nil else {
            return "Flow"
        }

        return activeFlowStore.remainingText(now: activeFlowStore.displayDate)
    }
}
#endif
