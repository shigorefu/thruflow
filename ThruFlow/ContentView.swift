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

    var body: some View {
#if os(macOS)
        NavigationSplitView {
            List(selection: $selection) {
                Label("今日", systemImage: "sun.max")
                    .tag(AppSection.today)

                Label("方向", systemImage: "point.3.connected.trianglepath.dotted")
                    .tag(AppSection.directions)
            }
            .navigationTitle("スルフロ")
        } detail: {
            switch selection ?? .today {
            case .today:
                TodayView()
            case .directions:
                DirectionListView()
            }
        }
#else
        TabView {
            TodayView()
                .tabItem {
                    Label("今日", systemImage: "sun.max")
                }

            DirectionListView()
                .tabItem {
                    Label("方向", systemImage: "point.3.connected.trianglepath.dotted")
                }
        }
#endif
    }
}

private enum AppSection: Hashable {
    case today
    case directions
}

#Preview {
    ContentView()
        .modelContainer(for: [Direction.self, Todo.self], inMemory: true)
}
