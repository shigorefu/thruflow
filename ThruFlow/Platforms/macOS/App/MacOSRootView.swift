//
//  MacOSRootView.swift
//  ThruFlow
//
//  Created by エドワード on 2026/07/08.
//

import SwiftUI
import SwiftData

struct MacOSRootView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selection: AppSection? = .flow
    @State private var historyDate = Calendar.current.startOfDay(for: .now)
    @State private var didReconcileFlowProgress = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Flow", systemImage: "waveform.path")
                    .tag(AppSection.flow)

                Label("タスク", systemImage: "checklist")
                    .tag(AppSection.tasks)

                Label("履歴", systemImage: "clock.arrow.circlepath")
                    .tag(AppSection.history)

                Label("方向", systemImage: "point.3.connected.trianglepath.dotted")
                    .tag(AppSection.directions)

                Label("統計", systemImage: "square.grid.3x3")
                    .tag(AppSection.statistics)
            }
            .navigationTitle("スルフロ")
        } detail: {
            detailContent
        }
        .task {
            guard !didReconcileFlowProgress else { return }
            didReconcileFlowProgress = true
            FlowProgressReconciler().reconcileAll(modelContext: modelContext)
            try? modelContext.save()
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection ?? .flow {
        case .flow:
            FlowDashboardView()
        case .tasks:
            TasksView()
        case .history:
            DayHistoryView(initialDate: historyDate)
                .id(historyDate)
        case .directions:
            DirectionListView()
        case .statistics:
            StatisticsView { date in
                historyDate = Calendar.current.startOfDay(for: date)
                selection = .history
            }
        }
    }
}

private enum AppSection: Hashable {
    case flow
    case tasks
    case history
    case directions
    case statistics
}

#Preview {
    MacOSRootView()
        .environmentObject(ActiveFlowStore())
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self], inMemory: true)
}
