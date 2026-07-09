//
//  ContentView.swift
//  ThruFlow
//
//  Created by エドワード on 2026/07/08.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selection: AppSection? = .today
    @State private var tabSelection: AppSection = .today

    var body: some View {
#if os(macOS)
        NavigationSplitView {
            List(selection: $selection) {
                Label("今日", systemImage: "sun.max")
                    .tag(AppSection.today)

                Label("Inbox", systemImage: "tray")
                    .tag(AppSection.inbox)

                Label("方向", systemImage: "point.3.connected.trianglepath.dotted")
                    .tag(AppSection.directions)

                Label("統計", systemImage: "square.grid.3x3")
                    .tag(AppSection.statistics)
            }
            .navigationTitle("スルフロ")
        } detail: {
            switch selection ?? .today {
            case .today:
                TodayView()
            case .inbox:
                InboxView()
            case .directions:
                DirectionListView()
            case .statistics:
                StatisticsView()
            }
        }
        .safeAreaInset(edge: .top) {
            FlowMiniPlayerView()
        }
#else
        TabView(selection: $tabSelection) {
            TodayView()
                .tabItem {
                    Label("今日", systemImage: "sun.max")
                }
                .tag(AppSection.today)

            DirectionListView()
                .tabItem {
                    Label("方向", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .tag(AppSection.directions)

            InboxView()
                .tabItem {
                    Label("Inbox", systemImage: "tray")
                }
                .tag(AppSection.inbox)

            StatisticsView()
                .tabItem {
                    Label("統計", systemImage: "square.grid.3x3")
                }
                .tag(AppSection.statistics)
        }
        .safeAreaInset(edge: .top) {
            FlowMiniPlayerView()
        }
#endif
    }
}

private enum AppSection: Hashable {
    case today
    case inbox
    case directions
    case statistics
}

#Preview {
    ContentView()
        .environmentObject(ActiveFlowStore())
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self], inMemory: true)
}
