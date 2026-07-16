//
//  ThruFlowApp.swift
//  ThruFlow
//
//  Created by エドワード on 2026/07/08.
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

@main
struct ThruFlowApp: App {
    @StateObject private var activeFlowStore = ActiveFlowStore()
#if os(macOS)
    @NSApplicationDelegateAdaptor(ThruFlowAppDelegate.self) private var appDelegate
#endif

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
            FlowSegment.self,
            FlowBreak.self,
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
            FlowMiniPlayerView(style: .dashboard)
                .environmentObject(activeFlowStore)
                .frame(width: 310, height: 410)
                .padding(16)
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
private final class ThruFlowAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL) else { return }

        NSApplication.shared.applicationIconImage = icon
    }
}

private struct FlowMenuBarLabel: View {
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    var body: some View {
        if activeFlowStore.timerState == nil {
            Image("FlowMenuBarIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 13)
                .accessibilityLabel("Flow")
        } else {
            Text(menuTitle)
                .font(.system(.body, design: .default))
                .monospacedDigit()
        }
    }

    private var menuTitle: String {
        guard activeFlowStore.timerState != nil else {
            return "Flow"
        }

        if activeFlowStore.isBreakPhase {
            let title = activeFlowStore.timerState?.isLongBreak == true ? "Long Break" : "休憩"
            return "☕️ \(title) - \(activeFlowStore.remainingText(now: activeFlowStore.displayDate))"
        }

        let session = activeFlowStore.activeSession
        let emoji = session?.direction?.symbolName ?? "▶"
        let taskName = resolvedTaskName(session: session)
        return "\(emoji): \(taskName) - \(activeFlowStore.remainingText(now: activeFlowStore.displayDate))"
    }

    private func resolvedTaskName(session: FlowSession?) -> String {
        if let todo = session?.todo {
            return TodoDisplay.title(for: todo)
        }

        if let directionName = session?.direction?.name.trimmingCharacters(in: .whitespacesAndNewlines),
           !directionName.isEmpty {
            return directionName
        }

        return "その他"
    }
}
#endif
