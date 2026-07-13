//
//  ContentView.swift
//  ThruFlow
//
//  Created by エドワード on 2026/07/08.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selection: AppSection? = .flow
    @State private var tabSelection: AppSection = .flow
    @State private var historyDate = Calendar.current.startOfDay(for: .now)

    var body: some View {
#if os(macOS)
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
#else
        TabView(selection: $tabSelection) {
            FlowDashboardView()
                .tabItem {
                    Label("Flow", systemImage: "waveform.path")
                }
                .tag(AppSection.flow)

            TasksView()
                .tabItem {
                    Label("タスク", systemImage: "checklist")
                }
                .tag(AppSection.tasks)

            DayHistoryView(initialDate: historyDate)
                .id(historyDate)
                .tabItem {
                    Label("履歴", systemImage: "clock.arrow.circlepath")
                }
                .tag(AppSection.history)

            DirectionListView()
                .tabItem {
                    Label("方向", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .tag(AppSection.directions)

            StatisticsView { date in
                historyDate = Calendar.current.startOfDay(for: date)
                tabSelection = .history
            }
                .tabItem {
                    Label("統計", systemImage: "square.grid.3x3")
                }
                .tag(AppSection.statistics)
        }
#endif
    }

#if os(macOS)
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
#endif
}

private enum AppSection: Hashable {
    case flow
    case tasks
    case history
    case directions
    case statistics
}

#Preview {
    ContentView()
        .environmentObject(ActiveFlowStore())
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self], inMemory: true)
}
