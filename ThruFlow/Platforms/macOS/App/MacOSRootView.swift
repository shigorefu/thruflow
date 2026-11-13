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
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore
    @EnvironmentObject private var onboarding: OnboardingStore

    @Query(sort: \Area.updatedAt, order: .reverse) private var areas: [Area]
    @Query private var onboardingTodos: [Todo]
    @Query private var onboardingFlowSessions: [FlowSession]
    @Query private var onboardingFlowBreaks: [FlowBreak]
    @State private var selection: AppSection?
    @State private var visitedSections: Set<AppSection> = []
    @State private var showsConnectors = false
    @State private var tasksInitialFilter: TaskCalendarFilter = .all
    @State private var tasksFilterRevision = 0
    @State private var hasPresentedTaskRows = false
    @State private var historyNavigationRevision = 0
    @State private var historyDate: Date?
    @State private var didReconcileFlowProgress = false
    @State private var flowSnapshotCache: FlowDashboardSnapshot?
    @State private var flowTodoGroupsCache: FlowDashboardTodoGroups?
    @State private var statisticsCache = StatisticsPresentationCache()
    @State private var statisticsSelection = StatisticsPeriodFilter(
        period: ScreenshotMode.isEnabled() ? .month : .week
    )

    init() {
        let initialSelection: AppSection = switch ScreenshotMode.initialScreen() {
        case .flow: .flow
        case .tasks: .tasks
        case .history: .history
        case .directions: .areas
        case .statistics, .statisticsTrend, .statisticsBreakdown, .statisticsDots: .statistics
        }
        _selection = State(initialValue: initialSelection)

        var todoDescriptor = FetchDescriptor<Todo>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\Todo.createdAt)]
        )
        todoDescriptor.fetchLimit = 1
        _onboardingTodos = Query(todoDescriptor)

        var sessionDescriptor = FetchDescriptor<FlowSession>(
            sortBy: [SortDescriptor(\FlowSession.startedAt)]
        )
        sessionDescriptor.fetchLimit = 1
        _onboardingFlowSessions = Query(sessionDescriptor)

        var breakDescriptor = FetchDescriptor<FlowBreak>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\FlowBreak.startedAt)]
        )
        breakDescriptor.fetchLimit = 1
        _onboardingFlowBreaks = Query(breakDescriptor)
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
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

                    Label(String(localized: "方向"), systemImage: ProductSymbol.area)
                        .tag(AppSection.areas)

                    Label(String(localized: "統計"), systemImage: "chart.bar.xaxis")
                        .tag(AppSection.statistics)
                }

                Divider()

                Button {
                    showsConnectors = true
                } label: {
                    ConnectorNavigationLabel()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .accessibilityIdentifier("connectors.open")

                SettingsLink {
                    Label(String(localized: "設定"), systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .accessibilityIdentifier("settings.open")
            }
            .navigationTitle(String(localized: "スルフロ"))
            .navigationSplitViewColumnWidth(min: 175, ideal: 190, max: 240)
        } detail: {
            GeometryReader { viewport in
                ZStack {
                    detailContent
                }
                .frame(width: viewport.size.width, height: viewport.size.height)
            }
            .navigationTitle(currentSection.title)
        }
        .onChange(of: currentSection, initial: true) { oldSection, section in
            if oldSection != section {
                MacOSFocusController.dismissCurrentTextEditor()
            }
            visitedSections.insert(section)
        }
        .task {
            guard !didReconcileFlowProgress else { return }
            didReconcileFlowProgress = true
            let modelContainer = modelContext.container
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled else { return }
            let reconciler = FlowProgressReconciliationActor(modelContainer: modelContainer)
            do {
                try await reconciler.reconcileAll()
            } catch {
                PersistenceIssueCenter.shared.log(error, operation: .flowSynchronization)
            }
        }
        .onAppear {
            showOnboardingScreenIfNeeded()
        }
        .task(id: onboardingWorkspaceHasUserContent) {
            await resolveOnboardingExperience()
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
        .sheet(isPresented: $showsConnectors) {
            MacOSConnectorsView()
        }
        .sheet(item: onboardingPresentationBinding) { presentation in
            MacOSOnboardingSheet(
                onboarding: onboarding,
                presentation: presentation,
                areas: areas,
                calendar: calendar,
                dayBoundary: dayBoundary,
                hasExternalWorkspaceContent: hasExternalOnboardingWorkspaceContent(excludingAreaID:excludingTaskID:)
            )
        }
    }

    private var currentSection: AppSection { selection ?? .flow }

    private func hasVisited(_ section: AppSection) -> Bool {
        currentSection == section || visitedSections.contains(section)
    }

    @ViewBuilder
    private var detailContent: some View {
        if currentSection == .flow {
            FlowDashboardView(
                isVisible: !onboarding.isPresented,
                areas: areas,
                cachedSnapshot: $flowSnapshotCache,
                cachedTodoGroups: $flowTodoGroupsCache,
                onOpenTasks: { filter in
                    tasksInitialFilter = filter
                    tasksFilterRevision &+= 1
                    selection = .tasks
                }
            )
        }
        if hasVisited(.tasks) {
            TasksView(
                initialFilter: tasksInitialFilter,
                filterRevision: tasksFilterRevision,
                isVisible: currentSection == .tasks,
                onFirstRows: beginTaskRowReveal
            )
            .macSectionVisibility(currentSection == .tasks)
        }
        if hasVisited(.history) {
            DayHistoryView(
                initialDate: historyDate ?? dayBoundary.day(containing: .now, calendar: calendar),
                navigationRevision: historyNavigationRevision,
                isVisible: currentSection == .history
            )
            .macSectionVisibility(currentSection == .history)
        }
        if hasVisited(.areas) {
            AreaListView(isVisible: currentSection == .areas)
                .macSectionVisibility(currentSection == .areas)
        }
        if hasVisited(.statistics) {
            StatisticsView(
                areas: areas,
                cache: $statisticsCache,
                selection: $statisticsSelection,
                isVisible: currentSection == .statistics
            ) { date in
                historyDate = calendar.startOfDay(for: date)
                historyNavigationRevision &+= 1
                selection = .history
            }
            .macSectionVisibility(currentSection == .statistics)
        }
    }

    private func beginTaskRowReveal() -> Bool {
        guard currentSection == .tasks, !hasPresentedTaskRows else { return false }
        hasPresentedTaskRows = true
        return true
    }

    private func showOnboardingScreenIfNeeded() {
        guard onboarding.isPresented else { return }
        selection = switch onboarding.step.screen {
        case .flow: .flow
        case .areas: .areas
        case .tasks: .tasks
        case .history: .history
        case .statistics: .statistics
        }
    }

    private var onboardingPresentationBinding: Binding<OnboardingPresentation?> {
        Binding(
            get: { onboarding.presentation },
            set: { presentation in
                if presentation == nil {
                    onboarding.dismissPresentation()
                }
            }
        )
    }

    private var onboardingWorkspaceHasUserContent: Bool {
        hasExternalOnboardingWorkspaceContent()
    }

    private func hasExternalOnboardingWorkspaceContent(
        excludingAreaID: UUID? = nil,
        excludingTaskID: UUID? = nil
    ) -> Bool {
        OnboardingWorkspaceInspector.inspect(
            areas: areas.filter {
                $0.id != onboarding.createdAreaID && $0.id != excludingAreaID
            },
            todos: onboardingTodos.filter {
                $0.id != onboarding.createdTaskID && $0.id != excludingTaskID
            },
            flowSessions: onboardingFlowSessions,
            flowBreaks: onboardingFlowBreaks
        ).hasUserContent
    }

    private func resolveOnboardingExperience() async {
        guard onboarding.isPresented else { return }

        if onboardingWorkspaceHasUserContent {
            onboarding.resolveWorkspace(hasUserContent: true)
            return
        }

        if onboarding.launchKind == .firstRun,
           onboarding.experience == .undecided,
           AppModelContainerFactory.usesCloudKitForCurrentProcess {
            await OnboardingWorkspaceSettler.waitForInitialImportOrTimeout()
            guard !Task.isCancelled else { return }
        }

        onboarding.resolveWorkspace(hasUserContent: onboardingWorkspaceHasUserContent)
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
    case areas
    case statistics

    var title: String {
        switch self {
        case .flow: String(localized: "Flow")
        case .tasks: String(localized: "タスク")
        case .history: String(localized: "履歴")
        case .areas: String(localized: "方向")
        case .statistics: String(localized: "統計")
        }
    }
}

private extension View {
    func macSectionVisibility(_ isVisible: Bool) -> some View {
        opacity(isVisible ? 1 : 0)
            .disabled(!isVisible)
            .allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible)
    }
}

#Preview {
    MacOSRootView()
        .environmentObject(ActiveFlowStore())
        .environmentObject(OnboardingStore())
        .environmentObject(ConnectorStore())
        .modelContainer(for: [Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self], inMemory: true)
}
