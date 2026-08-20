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
        case .directions: ProductSymbol.area
        case .statistics: "chart.bar.xaxis"
        case .settings: "gearshape"
        }
    }

    static var tabs: [IOSAppRoute] {
        [.flow, .tasks, .history, .directions, .statistics]
    }
}

struct IOSRootView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore
    @EnvironmentObject private var onboarding: OnboardingStore

    @Query(sort: \Direction.sortIndex) private var onboardingDirections: [Direction]
    @Query private var onboardingTodos: [Todo]
    @Query private var onboardingFlowSessions: [FlowSession]
    @Query private var onboardingFlowBreaks: [FlowBreak]

    @State private var selection = IOSAppRoute.flow
    @State private var showsSettings = false
    @State private var selectedHistoryDate = Date.now
    @State private var flowSnapshotCache: FlowDashboardSnapshot?
    @State private var flowTodoGroupsCache: FlowDashboardTodoGroups?
    @State private var statisticsSnapshotCache: StatisticsPeriodSnapshot?

    init() {
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
            if horizontalSizeClass == .regular {
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
        .sheet(item: onboardingPresentationBinding) { presentation in
            onboardingSheet(for: presentation)
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
            .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    showsSettings = true
                } label: {
                    Label(IOSAppRoute.settings.title, systemImage: IOSAppRoute.settings.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.bar)
                .accessibilityLabel(IOSAppRoute.settings.title)
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
                    destination(for: route)
                }
                .tabItem {
                    routeLabel(for: route)
                }
                .tag(route)
                .accessibilityLabel(route.title)
            }
        }
        .tint(.accentColor)
        .toolbarBackground(.hidden, for: .tabBar)
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
            DeferredFeatureMount(
                isActive: selection == .flow,
                title: IOSAppRoute.flow.title
            ) {
                IOSFlowView(
                    isVisible: !onboarding.isPresented,
                    cachedSnapshot: $flowSnapshotCache,
                    cachedTodoGroups: $flowTodoGroupsCache,
                    open: open
                )
            }
        case .tasks:
            IOSTasksView()
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
                    cachedSnapshot: $statisticsSnapshotCache
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

    @ViewBuilder
    private func onboardingSheet(for presentation: OnboardingPresentation) -> some View {
        switch presentation {
        case .areaEditor:
            NavigationStack {
                IOSDirectionEditorView(
                    mode: .create(),
                    initialDraft: onboardingAreaDraft
                ) { direction in
                    onboarding.resolveWorkspace(
                        hasUserContent: hasExternalOnboardingWorkspaceContent(
                            excludingAreaID: direction.id
                        )
                    )
                    _ = onboarding.recordArea(id: direction.id)
                }
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Button(String(localized: "ガイドをスキップ")) {
                            onboarding.skip()
                        }
                    }
                }
            }
            .interactiveDismissDisabled(false)

        case .taskComposer:
            NavigationStack {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    if let area = onboardingCreatedArea {
                        IOSTaskComposer(
                            directions: activeOnboardingDirections,
                            initialDraft: onboardingTaskDraft(area: area),
                            onClose: onboarding.dismissPresentation
                        ) { todo in
                            onboarding.resolveWorkspace(
                                hasUserContent: hasExternalOnboardingWorkspaceContent(
                                    excludingTaskID: todo.id
                                )
                            )
                            guard let area = todo.direction else { return }
                            _ = onboarding.recordTask(
                                id: todo.id,
                                presentation: OnboardingTaskPresentation(
                                    title: TodoDisplay.title(for: todo),
                                    areaName: area.name,
                                    areaSymbol: area.symbolName,
                                    areaColorHex: area.colorHex
                                )
                            )
                        }
                    } else {
                        ContentUnavailableView(
                            String(localized: "分野が見つかりません"),
                            systemImage: ProductSymbol.area
                        )
                    }
                }
                .background(Color(.systemGroupedBackground))
                .iosCenteredNavigationTitle(String(localized: "最初のタスクを作る"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "キャンセル")) {
                            onboarding.dismissPresentation()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "ガイドをスキップ")) {
                            onboarding.skip()
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .interactiveDismissDisabled(false)
        }
    }

    private var activeOnboardingDirections: [Direction] {
        onboardingDirections.filter { !$0.isArchived && !DefaultDirections.isTaskInboxRecord($0) }
    }

    private var onboardingCreatedArea: Direction? {
        guard let id = onboarding.createdAreaID else { return nil }
        return onboardingDirections.first { $0.id == id && !$0.isArchived }
    }

    private var onboardingAreaDraft: DirectionDraft {
        DirectionDraft(
            name: String(localized: "仕事"),
            type: .neutral,
            symbolName: "💼",
            colorHex: "#007AFF"
        )
    }

    private func onboardingTaskDraft(area: Direction) -> TodoDraft {
        TodoDraft(
            title: String(localized: "レポートを仕上げる"),
            direction: area,
            measurement: .checkbox,
            priority: .medium,
            scheduledDate: dayBoundary.day(containing: .now, calendar: calendar)
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
            directions: onboardingDirections.filter {
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
        case .directions: .directions
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
