//
//  MacOSRootView.swift
//  ThruFlow
//
//  Created by エドワード on 2026/07/08.
//

import SwiftUI
import SwiftData

struct MacOSRootView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Direction.updatedAt, order: .reverse) private var directions: [Direction]
    @Query(sort: \Todo.updatedAt, order: .reverse) private var todos: [Todo]
    @State private var selection: AppSection? = .flow
    @State private var historyDate = Calendar.current.startOfDay(for: .now)
    @State private var didReconcileFlowProgress = false
    @State private var flowSnapshotCache: FlowDashboardSnapshot?
    @State private var flowTodoGroupsCache: FlowDashboardTodoGroups?
    @State private var statisticsFlowCache: StatisticsHeatmapResult?
    @State private var statisticsAchievementCache: AchievementHeatmapResult?
    @StateObject private var taskWindowCache = TaskWindowCache()

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label {
                    Text(String(localized: "Flow"))
                } icon: {
                    FlowMenuIcon()
                }
                    .tag(AppSection.flow)

                Label(String(localized: "タスク"), systemImage: "checklist")
                    .tag(AppSection.tasks)

                Label(String(localized: "履歴"), systemImage: "clock.arrow.circlepath")
                    .tag(AppSection.history)

                Label(String(localized: "方向"), systemImage: "point.3.connected.trianglepath.dotted")
                    .tag(AppSection.directions)

                Label(String(localized: "統計"), systemImage: "square.grid.3x3")
                    .tag(AppSection.statistics)
            }
            .navigationTitle(String(localized: "スルフロ"))
            .navigationSplitViewColumnWidth(min: 175, ideal: 190, max: 240)
        } detail: {
            detailContent
        }
        .task {
            historyDate = dayBoundary.day(containing: .now, calendar: calendar)
            guard !didReconcileFlowProgress else { return }
            didReconcileFlowProgress = true
            let modelContainer = modelContext.container
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled else { return }
            let reconciler = FlowProgressReconciliationActor(modelContainer: modelContainer)
            try? await reconciler.reconcileAll()
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

    @ViewBuilder
    private var detailContent: some View {
        switch selection ?? .flow {
        case .flow:
            DeferredFeatureMount(
                isActive: (selection ?? .flow) == .flow,
                title: String(localized: "Flow")
            ) {
                FlowDashboardView(
                    isVisible: true,
                    directions: directions,
                    cachedSnapshot: $flowSnapshotCache,
                    cachedTodoGroups: $flowTodoGroupsCache
                )
            }
        case .tasks:
            TasksView(todos: todos, taskWindowCache: taskWindowCache)
        case .history:
            DayHistoryView(initialDate: historyDate)
                .id(historyDate)
        case .directions:
            DirectionListView()
        case .statistics:
            DeferredFeatureMount(
                isActive: selection == .statistics,
                title: String(localized: "統計")
            ) {
                StatisticsView(
                    isVisible: true,
                    directions: directions,
                    cachedFlowResult: $statisticsFlowCache,
                    cachedAchievementResult: $statisticsAchievementCache
                ) { date in
                    historyDate = calendar.startOfDay(for: date)
                    selection = .history
                }
            }
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
