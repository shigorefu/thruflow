import SwiftData
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
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary

    @Query(sort: \Todo.updatedAt, order: .reverse) private var todos: [Todo]
    @State private var selection = IOSAppRoute.flow
    @State private var showsSettings = false
    @State private var selectedHistoryDate = Date.now
    @State private var flowSnapshotCache: FlowDashboardSnapshot?
    @State private var flowTodoGroupsCache: FlowDashboardTodoGroups?
    @State private var statisticsFlowCache: StatisticsHeatmapResult?
    @State private var statisticsTaskCache: AchievementHeatmapResult?
    @StateObject private var taskWindowCache = TaskWindowCache()

    private var selectionBinding: Binding<IOSAppRoute> {
        Binding(
            get: { selection },
            set: { route in
                if route == .flow {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        selection = route
                    }
                    return
                }

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
                    .tabBarMinimizeBehavior(.never)
            } else {
                tabs
            }
        }
        .sheet(isPresented: $showsSettings) {
            NavigationStack {
                IOSSettingsView()
            }
        }
        .onOpenURL { url in
            guard url.scheme == "thruflow" else { return }
            switch url.host {
            case "flow":
                selectionBinding.wrappedValue = .flow
            case "tasks":
                selectionBinding.wrappedValue = .tasks
            case "statistics":
                selectionBinding.wrappedValue = .statistics
            default:
                break
            }
        }
        .task(id: taskCacheSourceRevision) {
            taskWindowCache.refresh(
                todos: todos,
                calendar: calendar,
                dayBoundary: dayBoundary
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            taskWindowCache.refresh(
                todos: todos,
                calendar: calendar,
                dayBoundary: dayBoundary
            )
        }
    }

    private var tabs: some View {
        TabView(selection: selectionBinding) {
            ForEach(IOSAppRoute.tabs) { route in
                NavigationStack {
                    destination(for: route)
                }
                .tabItem {
                    if route == .flow {
                        Label {
                            Text(route.title)
                        } icon: {
                            FlowMenuIcon(width: 22)
                        }
                    } else {
                        Label(route.title, systemImage: route.systemImage)
                    }
                }
                .tag(route)
                .accessibilityLabel(route.title)
            }
        }
        .tint(.accentColor)
        .toolbarBackground(.hidden, for: .tabBar)
    }

    @ViewBuilder
    private func destination(for route: IOSAppRoute) -> some View {
        switch route {
        case .flow:
            DeferredFeatureMount(
                isActive: selection == .flow,
                title: IOSAppRoute.flow.title
            ) {
                IOSFlowView(
                    isVisible: true,
                    cachedSnapshot: $flowSnapshotCache,
                    cachedTodoGroups: $flowTodoGroupsCache,
                    open: open
                )
            }
        case .tasks:
            IOSTasksView(todos: todos, taskWindowCache: taskWindowCache)
        case .history:
            IOSHistoryView(selectedDate: $selectedHistoryDate)
        case .directions:
            IOSDirectionsView()
        case .statistics:
            DeferredFeatureMount(
                isActive: selection == .statistics,
                title: IOSAppRoute.statistics.title
            ) {
                IOSStatisticsView(
                    isVisible: true,
                    cachedFlowResult: $statisticsFlowCache,
                    cachedTaskResult: $statisticsTaskCache
                ) { date in
                    selectedHistoryDate = date
                    selectionBinding.wrappedValue = .history
                }
            }
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

    private var taskCacheSourceRevision: TaskWindowCache.SourceRevision {
        TaskWindowCache.sourceRevision(
            todoCount: todos.count,
            latestUpdate: todos.first?.updatedAt,
            calendar: calendar,
            dayBoundary: dayBoundary
        )
    }
}
