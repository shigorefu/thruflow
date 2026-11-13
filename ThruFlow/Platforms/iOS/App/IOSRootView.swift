import SwiftData
import SwiftUI

struct IOSRootView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore
    @EnvironmentObject private var onboarding: OnboardingStore

    @Query(sort: \Area.sortIndex) private var onboardingAreas: [Area]
    @Query private var onboardingTodos: [Todo]
    @Query private var onboardingFlowSessions: [FlowSession]
    @Query private var onboardingFlowBreaks: [FlowBreak]

    @State private var selection = IOSAppRoute.flow
    @State private var showsSettings = false
    @State private var showsConnectors = false
    @State private var selectedHistoryDate = Date.now
    @State private var flowSnapshotCache: FlowDashboardSnapshot?
    @State private var flowTodoGroupsCache: FlowDashboardTodoGroups?
    @State private var statisticsCache = StatisticsPresentationCache()
    @State private var statisticsSelection = StatisticsPeriodFilter()

    init() {
        let initialRoute: IOSAppRoute = switch ScreenshotMode.initialScreen() {
        case .flow: .flow
        case .tasks: .tasks
        case .history: .history
        case .directions: .areas
        case .statistics, .statisticsDots: .statistics
        }
        _selection = State(initialValue: initialRoute)
        if ScreenshotMode.isEnabled() {
            _selectedHistoryDate = State(initialValue: ScreenshotMode.referenceDate)
            _statisticsSelection = State(initialValue: StatisticsPeriodFilter(
                period: .month,
                anchorDate: ScreenshotMode.referenceDate
            ))
        }

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

    private var selectionBinding: Binding<IOSAppRoute> {
        Binding(
            get: { selection },
            set: { selection = $0 }
        )
    }

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                adaptiveTabs
            } else if horizontalSizeClass == .regular {
                regularWidthShell
            } else {
                compactWidthShell
            }
        }
        .sheet(isPresented: $showsSettings) {
            NavigationStack {
                IOSSettingsView()
            }
        }
        .sheet(isPresented: $showsConnectors) {
            IOSConnectorsView()
        }
        .sheet(item: onboardingPresentationBinding) { presentation in
            IOSOnboardingSheet(
                onboarding: onboarding,
                presentation: presentation,
                areas: onboardingAreas,
                calendar: calendar,
                dayBoundary: dayBoundary,
                hasExternalWorkspaceContent: hasExternalOnboardingWorkspaceContent(excludingAreaID:excludingTaskID:)
            )
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
                selectionBinding.wrappedValue = .flow
            }
        }
    }

    @available(iOS 18.0, *)
    private var adaptiveTabs: some View {
        // Keep the same destination hierarchy when the system changes between
        // tabs and sidebar, so feature drafts and presented editors survive.
        adaptiveTabContent
            .tabViewStyle(.sidebarAdaptable)
            .defaultAdaptableTabBarPlacement(ScreenshotMode.isEnabled() ? .tabBar : .sidebar)
            .tabViewSidebarFooter { sidebarActions }
            .tint(.accentColor)
    }

    @available(iOS 18.0, *)
    @ViewBuilder
    private var adaptiveTabContent: some View {
        if #available(iOS 26.0, *) {
            modernTabs.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            modernTabs
        }
    }

    @available(iOS 18.0, *)
    private var modernTabs: some View {
        TabView(selection: selectionBinding) {
            ForEach(IOSAppRoute.tabs) { route in
                Tab(value: route) {
                    NavigationStack {
                        tabContent(for: route)
                    }
                } label: {
                    routeLabel(for: route)
                }
            }
        }
    }

    private var sidebarActions: some View {
        VStack(spacing: 0) {
            Button { showsConnectors = true } label: {
                ConnectorNavigationLabel()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .accessibilityIdentifier("connectors.open")

            Button { showsSettings = true } label: {
                Label(IOSAppRoute.settings.title, systemImage: IOSAppRoute.settings.systemImage)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .accessibilityLabel(IOSAppRoute.settings.title)
            .accessibilityIdentifier("settings.open")
        }
    }

    @ViewBuilder
    private var compactWidthShell: some View {
        if #available(iOS 26.0, *) {
            tabs
                .tabBarMinimizeBehavior(.onScrollDown)
        } else {
            tabs
        }
    }

    private var regularWidthShell: some View {
        NavigationSplitView {
            List(selection: sidebarSelectionBinding) {
                ForEach(IOSAppRoute.tabs) { route in
                    routeLabel(for: route)
                        .tag(route)
                }
            }
            .navigationTitle(String(localized: "スルフロ"))
            .navigationSplitViewColumnWidth(min: 220, ideal: 250)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                sidebarActions
                .background(.bar)
            }
        } detail: {
            NavigationStack {
                destination(for: selection)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var sidebarSelectionBinding: Binding<IOSAppRoute?> {
        Binding(
            get: { selection },
            set: { route in
                guard let route else { return }
                selectionBinding.wrappedValue = route
            }
        )
    }

    private var tabs: some View {
        TabView(selection: selectionBinding) {
            ForEach(IOSAppRoute.tabs) { route in
                NavigationStack {
                    tabContent(for: route)
                }
                .tabItem {
                    routeLabel(for: route)
                }
                .tag(route)
                .accessibilityLabel(route.title)
            }
        }
        .tint(.accentColor)
    }

    @ViewBuilder
    private func tabContent(for route: IOSAppRoute) -> some View {
        let content = destination(for: route)
        if #available(iOS 26.0, *) {
            content
                .toolbarBackgroundVisibility(.hidden, for: .tabBar)
                .scrollEdgeEffectHidden(true, for: .bottom)
        } else if #available(iOS 18.0, *) {
            content.toolbarBackgroundVisibility(.hidden, for: .tabBar)
        } else {
            content.toolbarBackground(.hidden, for: .tabBar)
        }
    }

    @ViewBuilder
    private func routeLabel(for route: IOSAppRoute) -> some View {
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

    @ViewBuilder
    private func destination(for route: IOSAppRoute) -> some View {
        switch route {
        case .flow:
            IOSFlowView(
                isVisible: selection == .flow && !onboarding.isPresented,
                cachedSnapshot: $flowSnapshotCache,
                cachedTodoGroups: $flowTodoGroupsCache,
                open: open
            )
        case .tasks:
            IOSTasksView(isVisible: selection == .tasks)
        case .history:
            IOSHistoryView(isVisible: selection == .history, selectedDate: $selectedHistoryDate)
        case .areas:
            IOSAreasView(isVisible: selection == .areas)
        case .statistics:
            IOSStatisticsView(
                isVisible: selection == .statistics,
                cache: $statisticsCache,
                selection: $statisticsSelection
            ) { date in
                selectedHistoryDate = date
                selectionBinding.wrappedValue = .history
            }
        case .connectors:
            IOSConnectorsView()
        case .settings:
            IOSSettingsView()
        }
    }

    private func open(_ route: IOSAppRoute) {
        if route == .settings {
            showsSettings = true
        } else if route == .connectors {
            showsConnectors = true
        } else {
            selectionBinding.wrappedValue = route
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
            areas: onboardingAreas.filter {
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

    private func showOnboardingScreenIfNeeded() {
        guard onboarding.isPresented else { return }
        let route: IOSAppRoute = switch onboarding.step.screen {
        case .flow: .flow
        case .areas: .areas
        case .tasks: .tasks
        case .history: .history
        case .statistics: .statistics
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selection = route
        }
    }
}
