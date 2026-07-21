import SwiftUI

enum IOSAppRoute: Hashable, CaseIterable, Identifiable {
    case flow
    case tasks
    case history
    case directions
    case statistics
    case settings

    var id: String { String(describing: self) }

    var title: String {
        switch self {
        case .flow: String(localized: "Flow")
        case .tasks: String(localized: "タスク")
        case .history: String(localized: "履歴")
        case .directions: String(localized: "方向")
        case .statistics: String(localized: "統計")
        case .settings: String(localized: "設定")
        }
    }

    var systemImage: String {
        switch self {
        case .flow: "waveform.path"
        case .tasks: "checklist"
        case .history: "clock.arrow.circlepath"
        case .directions: "point.3.connected.trianglepath.dotted"
        case .statistics: "chart.bar.xaxis"
        case .settings: "gearshape"
        }
    }

    static var tabs: [IOSAppRoute] {
        [.flow, .tasks, .history, .directions, .statistics]
    }
}

struct IOSRootView: View {
    @State private var selection = IOSAppRoute.flow
    @State private var showsSettings = false

    private var selectionBinding: Binding<IOSAppRoute> {
        Binding(
            get: { selection },
            set: { route in
                withAnimation(.snappy(duration: 0.28)) {
                    selection = route
                }
            }
        )
    }

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                tabs
                    .tabBarMinimizeBehavior(.onScrollDown)
            } else {
                tabs
            }
        }
        .sheet(isPresented: $showsSettings) {
            NavigationStack {
                IOSSettingsView()
            }
        }
    }

    private var tabs: some View {
        TabView(selection: selectionBinding) {
            ForEach(IOSAppRoute.tabs) { route in
                NavigationStack {
                    destination(for: route)
                }
                .toolbar(route == .tasks ? .hidden : .visible, for: .tabBar)
                .tabItem {
                    Label(route.title, systemImage: route.systemImage)
                }
                .tag(route)
                .accessibilityLabel(route.title)
            }
        }
        .tint(.accentColor)
    }

    @ViewBuilder
    private func destination(for route: IOSAppRoute) -> some View {
        switch route {
        case .flow:
            IOSFlowView(open: open)
        case .tasks:
            IOSTasksView { open(.flow) }
        case .history:
            IOSHistoryView()
        case .directions:
            IOSDirectionsView()
        case .statistics:
            IOSStatisticsView()
        case .settings:
            IOSSettingsView()
        }
    }

    private func open(_ route: IOSAppRoute) {
        if route == .settings {
            showsSettings = true
        } else {
            selectionBinding.wrappedValue = route
        }
    }
}
