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
    @EnvironmentObject private var onboarding: OnboardingStore

    @Query(sort: \Direction.updatedAt, order: .reverse) private var directions: [Direction]
    @State private var selection: AppSection? = .flow
    @State private var historyDate = Calendar.current.startOfDay(for: .now)
    @State private var didReconcileFlowProgress = false
    @State private var flowSnapshotCache: FlowDashboardSnapshot?
    @State private var flowTodoGroupsCache: FlowDashboardTodoGroups?
    @State private var statisticsPeriodCache: StatisticsPeriodSnapshot?

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

                Label(String(localized: "統計"), systemImage: "chart.bar.xaxis")
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
        .onAppear {
            showOnboardingScreenIfNeeded()
        }
        .onChange(of: onboarding.step) { _, _ in
            showOnboardingScreenIfNeeded()
        }
        .onChange(of: onboarding.isPresented) { _, isPresented in
            if isPresented {
                showOnboardingScreenIfNeeded()
            } else {
                selection = .flow
            }
        }
        .onOpenURL(perform: openWidgetURL)
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
            TasksView()
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
                    cachedSnapshot: $statisticsPeriodCache
                ) { date in
                    historyDate = calendar.startOfDay(for: date)
                    selection = .history
                }
            }
        }
    }

    private func showOnboardingScreenIfNeeded() {
        guard onboarding.isPresented else { return }
        selection = switch onboarding.step.screen {
        case .flow: .flow
        case .directions: .directions
        case .tasks: .tasks
        case .history: .history
        case .statistics: .statistics
        }
    }

    private func openWidgetURL(_ url: URL) {
        guard url.scheme == "thruflow" else { return }
        selection = switch url.host {
        case "flow": .flow
        case "tasks": .tasks
        case "statistics": .statistics
        default: selection
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
        .environmentObject(OnboardingStore())
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self], inMemory: true)
}
