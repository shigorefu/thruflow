//
//  FlowDashboardView.swift
//  ThruFlow
//
//

import SwiftData
import SwiftUI

struct FlowDashboardView: View {
    private static let topPanelHeight: CGFloat = 410
    private static let maximumDashboardWidth: CGFloat = 1320
    private static let minimumFlowStageWidth: CGFloat = 340
    private static let widePlayerWidth: CGFloat = 320
    private static let panelSpacing: CGFloat = 16
    private static let wideLayoutMinimumWidth =
        minimumFlowStageWidth + widePlayerWidth + panelSpacing

    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    let areas: [Area]
    @State private var inspectedSegment: FlowDashboardSegment?
    @State private var hoveredTimelineItem: TimelineItem?
    @State private var selectedTimelineItem: TimelineItem?
    @State private var editingTodo: Todo?
    @State private var showsQuickComposer = false
    @State private var statisticsPage = DashboardStatisticsPage.distribution
    @State private var distributionMode = DashboardDistributionMode.task
    @State private var preparesDashboard = false
    @State private var trend: FlowDashboardTrend?

    @Binding private var cachedSnapshot: FlowDashboardSnapshot?
    @Binding private var cachedTodoGroups: FlowDashboardTodoGroups?
    let isVisible: Bool
    let onOpenTasks: (TaskCalendarFilter) -> Void

    private let progressCalculator = TodoProgressCalculator()
    init(
        isVisible: Bool = true,
        areas: [Area],
        cachedSnapshot: Binding<FlowDashboardSnapshot?>,
        cachedTodoGroups: Binding<FlowDashboardTodoGroups?>,
        onOpenTasks: @escaping (TaskCalendarFilter) -> Void = { _ in }
    ) {
        self.isVisible = isVisible
        self.areas = areas
        self.onOpenTasks = onOpenTasks
        _cachedSnapshot = cachedSnapshot
        _cachedTodoGroups = cachedTodoGroups
    }

    var body: some View {
        dashboardContent
        .background {
            if isVisible && preparesDashboard {
                FlowDashboardData(
                    areas: areas,
                    showsTrend: statisticsPage == .trend,
                    snapshot: $cachedSnapshot,
                    todoGroups: $cachedTodoGroups,
                    trend: $trend
                )
            }
        }
        .navigationTitle(isVisible ? String(localized: "Flow") : "")
        .sheet(item: $inspectedSegment) { segment in
            FlowHistoryInspectorView(
                session: segment.session,
                segment: segment.storedSegment
            )
        }
        .sheet(item: $editingTodo) { todo in
            TodoFormView(mode: .edit(todo))
        }
        .onChange(of: isVisible) { _, newValue in
            guard !newValue else { return }
            inspectedSegment = nil
            editingTodo = nil
            showsQuickComposer = false
        }
        .task(id: isVisible) {
            guard isVisible else {
                preparesDashboard = false
                return
            }
            await Task.yield()
            guard !Task.isCancelled else { return }
            preparesDashboard = true
        }
    }

    private var dashboardContent: some View {
        GeometryReader { viewport in
            let availableWidth = min(
                max(0, viewport.size.width - 40),
                Self.maximumDashboardWidth
            )
            let snapshot = cachedSnapshot ?? .empty(at: dayBoundary.day(containing: .now, calendar: calendar))

            ScrollView {
                dashboardLayout(
                    snapshot: snapshot,
                    availableWidth: availableWidth,
                    availableHeight: max(0, viewport.size.height - 40)
                )
                .frame(width: availableWidth)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
        }
        .background(modeBackgroundTint.ignoresSafeArea())
    }

    private func dashboardLayout(
        snapshot: FlowDashboardSnapshot,
        availableWidth: CGFloat,
        availableHeight: CGFloat
    ) -> some View {
        let lowerPanelHeight = max(340, availableHeight - Self.topPanelHeight - Self.panelSpacing)
        let leftColumnWidth = max(
            0,
            availableWidth - Self.widePlayerWidth - Self.panelSpacing
        )

        return Group {
            if availableWidth >= Self.wideLayoutMinimumWidth {
                VStack(spacing: Self.panelSpacing) {
                    HStack(alignment: .top, spacing: Self.panelSpacing) {
                        flowStage(snapshot: snapshot)
                            .frame(width: leftColumnWidth)
                            .frame(height: Self.topPanelHeight)

                        FlowMiniPlayerView(style: .dashboard)
                            .frame(width: Self.widePlayerWidth, height: Self.topPanelHeight)
                    }

                    HStack(alignment: .top, spacing: Self.panelSpacing) {
                        taskColumns(scrollsRows: true)
                            .frame(width: leftColumnWidth, height: lowerPanelHeight, alignment: .top)
                        statisticsPanel(snapshot: snapshot)
                            .frame(
                                width: Self.widePlayerWidth,
                                height: lowerPanelHeight
                            )
                    }
                }
                .frame(width: availableWidth)
            } else {
                VStack(spacing: Self.panelSpacing) {
                    FlowMiniPlayerView(style: .dashboard)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 360)
                        .fixedSize(horizontal: false, vertical: true)

                    flowStage(snapshot: snapshot)
                        .frame(minHeight: 340)
                        .fixedSize(horizontal: false, vertical: true)

                    taskColumns()
                    statisticsPanel(snapshot: snapshot)
                        .frame(height: 340)
                }
            }
        }
    }

    private func flowStage(snapshot: FlowDashboardSnapshot) -> some View {
        FlowDashboardStage(
            snapshot: snapshot,
            isLoaded: cachedSnapshot != nil,
            isVisible: isVisible
        ) { now in
            FlowDashboardTimeline(
                snapshot: snapshot,
                now: now,
                hoveredTimelineItem: $hoveredTimelineItem,
                selectedTimelineItem: $selectedTimelineItem,
                onInspectSegment: { inspectedSegment = $0 }
            )
        }
    }

    private func statisticsPanel(snapshot: FlowDashboardSnapshot) -> some View {
        FlowDashboardStatisticsPanel(
            snapshot: snapshot,
            isLoaded: cachedSnapshot != nil,
            todoGroups: cachedTodoGroups,
            trend: trend,
            statisticsPage: $statisticsPage,
            distributionMode: $distributionMode
        )
    }

    private func taskColumns(scrollsRows: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 14) {
            DashboardTodoColumn(
                title: String(localized: "タスク"),
                systemImage: "checklist",
                todos: standardTodos,
                scrollsRows: scrollsRows,
                isLoading: cachedTodoGroups == nil,
                showsPriority: true,
                progressText: progressText,
                onToggle: toggleTodo,
                onOpen: { editingTodo = $0 },
                onOpenSection: { onOpenTasks(.tasks) },
                addControl: AnyView(dashboardAddButton)
            )
            DashboardTodoColumn(
                title: String(localized: "習慣一覧"),
                systemImage: "repeat",
                todos: habitTodos,
                scrollsRows: scrollsRows,
                isLoading: cachedTodoGroups == nil,
                progressText: progressText,
                onToggle: toggleTodo,
                onOpen: { editingTodo = $0 },
                onOpenSection: { onOpenTasks(.habits) }
            )

            if !niceTodos.isEmpty {
                DashboardTodoColumn(
                    title: String(localized: "ナイス"),
                    systemImage: "sparkles",
                    todos: niceTodos,
                    scrollsRows: scrollsRows,
                    progressText: progressText,
                    onToggle: toggleTodo,
                    onOpen: { editingTodo = $0 }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .productContentFade(on: cachedTodoGroups != nil)
    }

    private var standardTodos: [Todo] {
        cachedTodoGroups?.standard ?? []
    }

    private var habitTodos: [Todo] {
        cachedTodoGroups?.habits ?? []
    }

    private var niceTodos: [Todo] {
        cachedTodoGroups?.nice ?? []
    }

    private var activeAreas: [Area] {
        areas
            .filter { !$0.isArchived }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var dashboardAddButton: some View {
        Button {
            showsQuickComposer = true
        } label: {
            Image(systemName: "plus")
        }
        .buttonStyle(.plain)
        .help(String(localized: "タスクを追加"))
        .accessibilityLabel(String(localized: "タスクを追加"))
        .popover(isPresented: $showsQuickComposer, arrowEdge: .top) {
            QuickTodoCreationPopover(areas: activeAreas)
        }
    }

    private var modeBackgroundTint: Color {
        switch activeFlowStore.selectedMode {
        case .sprint, .adaptive:
            Color.orange.opacity(0.025)
        case .twentyFiveFive:
            Color.blue.opacity(0.025)
        case .fiftyTen:
            Color.indigo.opacity(0.035)
        }
    }

    private func progressText(_ todo: Todo) -> String {
        progressCalculator.summary(
            measurement: todo.measurement,
            plannedAmount: todo.plannedAmount,
            actualProgress: todo.actualProgress,
            focusDurationSeconds: todo.focusDurationSeconds
        )
    }

    private func toggleTodo(_ todo: Todo) {
        guard todo.setManuallyCompleted(!todo.isCompleted) else { return }
        _ = modelContext.saveReporting(.flowUpdate)
    }


}

#Preview {
    FlowDashboardPreviewHost()
}

private struct FlowDashboardPreviewHost: View {
    @State private var snapshot: FlowDashboardSnapshot?
    @State private var todoGroups: FlowDashboardTodoGroups?

    var body: some View {
        FlowDashboardView(
            areas: [],
            cachedSnapshot: $snapshot,
            cachedTodoGroups: $todoGroups
        )
        .environmentObject(ActiveFlowStore())
        .environmentObject(AppSettings())
        .modelContainer(for: [Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self], inMemory: true)
    }
}
