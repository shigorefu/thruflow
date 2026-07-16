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
                .task {
                    repairDragVerificationFlowIfRequested()
                }
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

    @MainActor
    private func repairDragVerificationFlowIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--repair-drag-verification-flow") else { return }

        let context = sharedModelContainer.mainContext
        let calendar = Calendar.current
        let sessions = (try? context.fetch(FetchDescriptor<FlowSession>())) ?? []
        let todos = (try? context.fetch(FetchDescriptor<Todo>())) ?? []
        guard let session = sessions.first(where: {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: $0.startedAt)
            return components.year == 2026 && components.month == 7 && components.day == 14 &&
                components.hour == 12 && components.minute == 42 && $0.actualFocusDurationSeconds == 26 * 60
        }),
        session.segments.count == 1,
        let primaryTodo = session.todo,
        let primaryDirection = session.direction,
        let ankiTodo = todos.first(where: {
            $0.direction?.name == "Anki" &&
                $0.scheduledDate.map { calendar.isDate($0, inSameDayAs: session.startedAt) } == true
        }),
        let ankiDirection = ankiTodo.direction,
        let first = session.segments.first else { return }

        first.direction = primaryDirection
        first.todo = primaryTodo
        first.startedAt = session.startedAt
        first.startFocusSeconds = 0
        first.close(at: session.startedAt.addingTimeInterval(12 * 60), totalFocusSeconds: 12 * 60)

        let second = FlowSegment(
            session: session,
            direction: ankiDirection,
            todo: ankiTodo,
            startedAt: session.startedAt.addingTimeInterval(12 * 60),
            startFocusSeconds: 12 * 60
        )
        second.close(at: session.startedAt.addingTimeInterval(14 * 60), totalFocusSeconds: 14 * 60)

        let third = FlowSegment(
            session: session,
            direction: primaryDirection,
            todo: primaryTodo,
            startedAt: session.startedAt.addingTimeInterval(14 * 60),
            startFocusSeconds: 14 * 60
        )
        third.close(at: session.startedAt.addingTimeInterval(26 * 60), totalFocusSeconds: 26 * 60)

        context.insert(second)
        context.insert(third)
        session.segments = [first, second, third]
        FlowProgressReconciler().reconcile(session: session, modelContext: context, now: .now)
        try? context.save()
    }
}

#if os(macOS)
private struct FlowMenuBarLabel: View {
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    var body: some View {
        if activeFlowStore.timerState == nil {
            Label("Flow", systemImage: "waveform.path")
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
