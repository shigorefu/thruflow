import Combine
import SwiftData
import SwiftUI

struct IOSFlowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.calendar) private var calendar
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Area.updatedAt, order: .reverse) private var areas: [Area]
    @Query(sort: \Project.createdAt) private var projects: [Project]
    @Query private var todos: [Todo]

    @Binding private var cachedSnapshot: FlowDashboardSnapshot?
    @Binding private var cachedTodoGroups: FlowDashboardTodoGroups?
    let isVisible: Bool
    let open: (IOSAppRoute) -> Void

    @State private var showsContextPicker = false
    @State private var showsMemo = false
    @State private var presentedTaskSwitchID: UUID?
    @State private var isMemoDismissing = false
    @State private var wallClockRevision = Date.now
    @State private var showsTaskComposer = false
    @State private var editorMode: IOSTaskEditorMode?
    @State private var selectedHistoryItem: HistoryCalendarItem?
    @State private var preparationRevision = 0
    @State private var taskFilter = IOSDashboardTaskFilter.task
    @State private var loadsRecentRecords = false
    @State private var recentRecords: IOSFlowRecentRecords?

    private var dashboardBuilder: FlowDashboardBuilder {
        FlowDashboardBuilder(calendar: calendar, dayBoundary: dayBoundary)
    }

    init(
        isVisible: Bool = true,
        cachedSnapshot: Binding<FlowDashboardSnapshot?>,
        cachedTodoGroups: Binding<FlowDashboardTodoGroups?>,
        open: @escaping (IOSAppRoute) -> Void
    ) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -16, to: .now) ?? .distantPast
        let todoUpperBound = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .distantFuture
        let missingScheduledDate = Date.distantPast
        self.isVisible = isVisible
        _todos = Query(
            filter: #Predicate<Todo> { todo in
                (todo.scheduledDate ?? missingScheduledDate) >= cutoff &&
                    (todo.scheduledDate ?? missingScheduledDate) < todoUpperBound
            },
            sort: \Todo.updatedAt,
            order: .reverse
        )
        _cachedSnapshot = cachedSnapshot
        _cachedTodoGroups = cachedTodoGroups
        self.open = open
    }

    var body: some View {
        dashboardContent
        .background {
            if isVisible, loadsRecentRecords {
                IOSFlowRecentRecordsQuery { records in
                    recentRecords = records
                }
            }
        }
        .iosCenteredNavigationTitle(String(localized: "Flow"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        open(.connectors)
                    } label: {
                        Label {
                            Text(String(localized: "コネクタ"))
                        } icon: {
                            Image(systemName: "puzzlepiece.extension")
                        }
                    }
                    .accessibilityIdentifier("connectors.open")

                    Button {
                        open(.settings)
                    } label: {
                        Label(String(localized: "設定"), systemImage: "gearshape")
                    }
                } label: {
                    IOSMoreMenuLabel()
                }
                .accessibilityLabel(String(localized: "その他"))
                .accessibilityIdentifier("flow.more")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsTaskComposer {
                taskComposer
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                    .transition(reduceMotion ? .identity : .offset(y: 12).combined(with: .opacity))
                    .background {
                        Rectangle()
                            .fill(.background)
                            .ignoresSafeArea()
                    }
            }
        }
        .sheet(isPresented: $showsContextPicker, onDismiss: presentMemoIfNeeded) {
            NavigationStack {
                IOSFlowContextPicker(
                    todos: todayTodos,
                    areas: activeAreas,
                    selectedTodoID: activeFlowStore.selectedTodoID,
                    selectedAreaID: activeFlowStore.selectedAreaID
                ) { area, todo in
                    select(area: area, todo: todo)
                    showsContextPicker = false
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showsMemo, onDismiss: {
            presentedTaskSwitchID = nil
            isMemoDismissing = false
            presentMemoIfNeeded()
        }) {
            IOSFlowMemoView(
                isBreakMemo: activeFlowStore.isAwaitingBreakMemo,
                isTaskSwitchMemo: presentedTaskSwitchID != nil,
                todo: activeFlowStore.memoTodo,
                cancel: cancelMemo,
                submit: submitMemo
            )
            .presentationDetents([.medium, .large])
            .interactiveDismissDisabled(presentedTaskSwitchID != nil)
        }
        .transaction(value: showsMemo) { transaction in
            if reduceMotion {
                transaction.disablesAnimations = true
            }
        }
        .sheet(item: $editorMode) { mode in
            NavigationStack {
                IOSTaskEditorView(mode: mode, areas: activeAreas)
            }
        }
        .sheet(item: $selectedHistoryItem) { item in
            IOSHistoryItemDetail(item: item)
                .presentationDetents(item.kind == .flow ? [.large] : [.medium])
        }
        .onChange(of: scenePhase) { _, phase in
            guard isVisible, phase == .active else { return }
            wallClockRevision = .now
            reconcileSelectedTodo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemClockDidChange)
            .merge(with: NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange))) { _ in
            guard isVisible else { return }
            wallClockRevision = .now
            reconcileSelectedTodo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            preparationRevision += 1
        }
        .task(id: isVisible) {
            guard isVisible else {
                loadsRecentRecords = false
                return
            }
            await Task.yield()
            guard !Task.isCancelled, isVisible else { return }
            loadsRecentRecords = true
            presentMemoIfNeeded()
        }
        .task(id: preparationTaskID) {
            await prepareTodayAfterPresentation()
        }
        .task(id: refreshTaskID) {
            guard isVisible, activeFlowStore.timerState != nil else { return }
            while !Task.isCancelled, activeFlowStore.timerState != nil {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, isVisible else { return }
                activeFlowStore.refresh(modelContext: modelContext)
                presentMemoIfNeeded()
            }
        }
        .task(id: dashboardSnapshotRefreshID) {
            await refreshDashboardCache()
        }
        .task(id: todoGroupsRefreshID) {
            await refreshTodoGroupsCache()
        }
        .onChange(of: activeFlowStore.isAwaitingBreakMemo) { _, _ in
            presentMemoIfNeeded()
        }
        .onChange(of: activeFlowStore.pendingTaskSwitch?.id) { _, _ in
            presentMemoIfNeeded()
        }
        .onChange(of: activeFlowStore.phase) { _, _ in
            if isVisible, let recentRecords {
                cachedSnapshot = makeSnapshot(at: .now, records: recentRecords)
            }
            presentMemoIfNeeded()
        }
        .onChange(of: activeFlowStore.timerState == nil) { _, isIdle in
            guard isIdle else { return }
            reconcileSelectedTodo()
        }
        .onChange(of: isVisible) { _, newValue in
            guard !newValue else { return }
            loadsRecentRecords = false
            selectedHistoryItem = nil
        }
    }

    private var refreshTaskID: FlowRefreshTaskID {
        FlowRefreshTaskID(
            isVisible: isVisible,
            phaseRawValue: activeFlowStore.timerState?.phase.rawValue
        )
    }

    private var dashboardContent: some View {
        ScrollView {
            IOSFlowDashboardLayout(allowsColumns: horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize) {
                IOSFlowTodayCard(
                    snapshot: cachedSnapshot,
                    isActive: activeFlowStore.phase == .focusing,
                    mode: activeFlowStore.selectedMode,
                    breakStyle: activeFlowStore.flowStreamBreakStyle,
                    breakInteraction: activeFlowStore.flowBreakInteraction,
                    isVisible: isVisible,
                    onOpenHistory: inspectTimelineSelection
                )
                IOSFlowPlayerCard(
                    isVisible: isVisible,
                    wallClockRevision: wallClockRevision,
                    selectedTodo: selectedTodo,
                    selectedArea: selectedArea,
                    tint: tint,
                    onOpenContextPicker: { showsContextPicker = true },
                    onEditTodo: { editorMode = .edit($0) },
                    onToggleTodoCompletion: toggleTodoCompletion,
                    onSelectMode: { activeFlowStore.selectMode($0, modelContext: modelContext) },
                    onTransportAction: handleTransportAction,
                    onAppDayChange: { reconcileSelectedTodo(now: $0) }
                )
                IOSFlowTasksCard(
                    taskFilter: $taskFilter,
                    isLoading: cachedTodoGroups == nil,
                    todos: filteredDashboardTodos,
                    onAddTask: presentTaskComposer,
                    onOpenTasks: { open(.tasks) },
                    onEditTodo: { editorMode = .edit($0) }
                )
                statisticsCard()
            }
            .frame(maxWidth: 1_200)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
        }
        .background(backgroundColor.ignoresSafeArea())
    }

    private func statisticsCard() -> some View {
        IOSDashboardStatisticsView(
            snapshot: cachedSnapshot,
            recentRecords: recentRecords,
            todos: todos,
            todoGroups: cachedTodoGroups,
            calendar: calendar,
            dayBoundary: dayBoundary
        )
    }

    private var activeAreas: [Area] {
        areas
            .filter { !$0.isArchived }
            .sorted { lhs, rhs in
                if lhs.sortIndex != rhs.sortIndex {
                    return lhs.sortIndex < rhs.sortIndex
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    private var todayTodos: [Todo] {
        cachedTodoGroups?.all ?? []
    }

    private var filteredDashboardTodos: [Todo] {
        guard let groups = cachedTodoGroups else { return [] }
        switch taskFilter {
        case .task:
            return groups.standard
        case .habit:
            return groups.habits
        case .nice:
            return groups.nice
        }
    }

    private var selectedTodo: Todo? {
        todos.first { $0.id == activeFlowStore.selectedTodoID }
    }

    private var selectedArea: Area? {
        if let area = selectedTodo?.area { return area }
        return areas.first { $0.id == activeFlowStore.selectedAreaID }
    }

    private var tint: Color {
        if activeFlowStore.isBreakPhase { return Color.secondary }
        return Color(hex: selectedArea?.colorHex ?? "#007AFF")
    }

    private var backgroundColor: Color {
        tint.opacity(activeFlowStore.timerState == nil ? 0.025 : 0.055)
    }

    private func makeSnapshot(at date: Date, records: IOSFlowRecentRecords) -> FlowDashboardSnapshot {
        let day = dayBoundary.day(containing: date, calendar: calendar)
        let interval = dayBoundary.interval(for: day, calendar: calendar)
        let daySessions = records.sessions.filter { interval.contains($0.startedAt) }
        let dayBreaks = records.breaks.filter { interval.contains($0.startedAt) }

        return dashboardBuilder.build(
            date: date,
            sessions: daySessions,
            breaks: dayBreaks,
            activeSessionID: activeFlowStore.activeSession?.id,
            activeFocusSeconds: activeFlowStore.actualFocusSeconds(now: date),
            visualIdentityID: DailyFlowIdentity.resolve(from: areas)
        )
    }

    private var dashboardSnapshotRefreshID: IOSFlowDashboardRefreshID {
        IOSFlowDashboardRefreshID(
            isVisible: isVisible,
            recordsRevision: recentRecords?.revision,
            areaCount: areas.count,
            latestAreaUpdate: areas.first?.updatedAt,
            activeSessionID: activeFlowStore.activeSession?.id,
            phase: activeFlowStore.timerState?.phase.rawValue
        )
    }

    private var preparationTaskID: IOSFlowPreparationID {
        IOSFlowPreparationID(
            isVisible: isVisible,
            areaCount: areas.count,
            latestAreaUpdate: areas.first?.updatedAt,
            todoCount: todos.count,
            latestTodoUpdate: todos.first?.updatedAt,
            projectRevisions: projects.map {
                IOSFlowProjectRevision(
                    id: $0.id, updatedAt: $0.updatedAt, completedAt: $0.completedAt,
                    areaUpdatedAt: $0.area?.updatedAt, areaArchivedAt: $0.area?.archivedAt
                )
            }.sorted { $0.id.uuidString < $1.id.uuidString },
            revision: preparationRevision
        )
    }

    private var todoGroupsRefreshID: IOSFlowTodoRefreshID {
        IOSFlowTodoRefreshID(
            isVisible: isVisible,
            todoCount: todos.count,
            latestTodoUpdate: todos.first?.updatedAt
        )
    }

    @MainActor
    private func prepareTodayAfterPresentation() async {
        guard isVisible else { return }
        await Task.yield()
        guard !Task.isCancelled, isVisible else { return }
        prepareToday()
        reconcileSelectedTodo()
        configureInitialContextIfNeeded()
    }

    @MainActor
    private func refreshDashboardCache() async {
        guard isVisible, !Task.isCancelled, let recentRecords else { return }
        cachedSnapshot = makeSnapshot(at: .now, records: recentRecords)

        while !Task.isCancelled, isVisible, activeFlowStore.timerState != nil {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, isVisible else { return }
            cachedSnapshot = makeSnapshot(at: .now, records: recentRecords)
        }
    }

    @MainActor
    private func refreshTodoGroupsCache() async {
        guard isVisible else { return }

        if cachedTodoGroups == nil { await Task.yield() }
        guard !Task.isCancelled, isVisible else { return }

        cachedTodoGroups = FlowDashboardTodoGroupBuilder(
            calendar: calendar,
            dayBoundary: dayBoundary
        ).build(from: todos)
    }

    private func select(area: Area, todo: Todo?) {
        activeFlowStore.selectPickerContext(
            area: area, todo: todo, modelContext: modelContext,
            calendar: calendar, dayBoundary: dayBoundary
        )
    }

    private func inspectTimelineSelection(_ selection: IOSFlowTimelineSelection) {
        guard let recentRecords else { return }
        let today = dayBoundary.day(containing: .now, calendar: calendar)
        let interval = dayBoundary.interval(for: today, calendar: calendar)
        let items = HistoryCalendarBuilder(calendar: calendar)
            .build(
                interval: interval,
                sessions: recentRecords.sessions,
                breaks: recentRecords.breaks,
                referenceDate: .now
            )
            .items
        let resolver = FlowDashboardHistoryItemResolver()

        switch selection {
        case .segment(let segment):
            selectedHistoryItem = resolver.item(for: segment, in: items)
        case .flowBreak(let flowBreak):
            selectedHistoryItem = resolver.item(for: flowBreak, in: items)
        }
    }

    private func toggleTodoCompletion(_ todo: Todo) {
        if todo.setManuallyCompleted(!todo.isCompleted) {
            _ = modelContext.saveReporting(.flowUpdate)
        }
    }

    private func handleTransportAction(_ action: FlowTimerPanelAction) {
        switch action {
        case .seekBackward:
            activeFlowStore.seekBackward(modelContext: modelContext)
        case .primary:
            primaryAction()
        case .seekForward:
            activeFlowStore.seekForward(modelContext: modelContext)
        case .destroy:
            activeFlowStore.destroy(modelContext: modelContext)
        case .stop:
            activeFlowStore.stop(modelContext: modelContext)
            presentMemoIfNeeded()
        case .startBreak:
            activeFlowStore.requestBreakMemo(modelContext: modelContext)
            presentMemoIfNeeded()
        }
    }

    private func primaryAction() {
        if activeFlowStore.isBreakPhase {
            guard let area = selectedArea else { return }
            activeFlowStore.startNextFlow(
                area: area,
                todo: selectedTodo,
                modelContext: modelContext
            )
            return
        }

        if let state = activeFlowStore.timerState {
            if state.phase == .paused {
                activeFlowStore.resume(modelContext: modelContext)
            } else if activeFlowStore.isFocusOvertime(now: .now) {
                activeFlowStore.requestBreakMemo(modelContext: modelContext)
                presentMemoIfNeeded()
            } else {
                activeFlowStore.pause(modelContext: modelContext)
            }
            return
        }

        guard let area = selectedArea else { return }
        activeFlowStore.start(area: area, todo: selectedTodo, modelContext: modelContext)
    }

    private func prepareToday() {
        let inbox = DefaultAreas.existingTaskInbox(in: areas) ?? {
            let area = DefaultAreas.makeTaskInbox()
            modelContext.insert(area)
            return area
        }()
        _ = inbox
        let now = Date.now
        let today = dayBoundary.day(containing: now, calendar: calendar)
        do {
            _ = try HabitTodoMaterializer(
                calendar: calendar,
                dayBoundary: dayBoundary
            ).materialize(
                areas: areas,
                dates: [today],
                modelContext: modelContext,
                now: now,
                knownTodos: todos,
                reconcilesDuplicates: false
            )
        } catch {
            modelContext.rollback()
            PersistenceIssueCenter.shared.report(error, operation: .habitMaterialization)
        }
    }

    private func configureInitialContextIfNeeded() {
        guard activeFlowStore.selectedAreaID == nil else { return }
        let groups = cachedTodoGroups ?? FlowDashboardTodoGroupBuilder(
            calendar: calendar,
            dayBoundary: dayBoundary
        ).build(from: todos)
        if let todo = groups.all.first(where: { !$0.isCompleted }), let area = todo.area {
            activeFlowStore.configure(area: area, todo: todo)
        } else if let area = activeAreas.first {
            activeFlowStore.configure(area: area, todo: nil)
        }
    }

    private func reconcileSelectedTodo(now: Date = .now) {
        guard isVisible else { return }
        activeFlowStore.reconcileSelectedTodoForCurrentDay(
            todos: todos,
            areas: areas,
            now: now,
            calendar: calendar,
            dayBoundary: dayBoundary
        )
    }

    private func presentMemoIfNeeded() {
        guard isVisible, !showsContextPicker, !isMemoDismissing else { return }
        if showsMemo, let requestID = presentedTaskSwitchID {
            if activeFlowStore.pendingTaskSwitch?.id != requestID { dismissMemo() }
            return
        }
        guard !showsMemo else { return }
        presentedTaskSwitchID = activeFlowStore.pendingTaskSwitch?.id
        showsMemo = presentedTaskSwitchID != nil || activeFlowStore.isAwaitingBreakMemo
            || activeFlowStore.phase == .awaitingResult
    }

    private func cancelMemo() {
        if let requestID = presentedTaskSwitchID {
            if activeFlowStore.pendingTaskSwitch?.id == requestID {
                activeFlowStore.cancelTaskSwitchMemo()
            }
        } else if activeFlowStore.isAwaitingBreakMemo {
            activeFlowStore.cancelBreakMemo()
        } else {
            activeFlowStore.cancelResultMemo(modelContext: modelContext)
        }
        dismissMemo()
    }

    private func submitMemo(_ memo: String?, taskTitle: String?, project: Project?) {
        let didSave: Bool
        if let requestID = presentedTaskSwitchID {
            guard activeFlowStore.pendingTaskSwitch?.id == requestID else {
                dismissMemo()
                return
            }
            didSave = activeFlowStore.completeTaskSwitchMemo(
                memo, taskTitle: taskTitle, taskProject: project, modelContext: modelContext
            )
        } else if activeFlowStore.isAwaitingBreakMemo {
            didSave = activeFlowStore.completeBreakMemo(memo, taskTitle: taskTitle, taskProject: project, modelContext: modelContext)
        } else {
            didSave = activeFlowStore.completeResult(memo, taskTitle: taskTitle, taskProject: project, modelContext: modelContext)
        }
        if didSave { dismissMemo() }
    }

    private func dismissMemo() {
        isMemoDismissing = true
        showsMemo = false
    }

    private func presentTaskComposer() {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
            showsTaskComposer = true
        }
    }

    private func dismissTaskComposer() {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.20)) {
            showsTaskComposer = false
        }
    }

    private var taskComposer: some View {
        IOSTaskComposer(
            areas: activeAreas,
            onClose: dismissTaskComposer
        )
    }

}

private struct FlowRefreshTaskID: Hashable {
    let isVisible: Bool
    let phaseRawValue: String?
}

private struct IOSFlowDashboardRefreshID: Hashable {
    let isVisible: Bool
    let recordsRevision: IOSFlowRecentRecordsRevision?
    let areaCount: Int
    let latestAreaUpdate: Date?
    let activeSessionID: UUID?
    let phase: String?
}

private struct IOSFlowTodoRefreshID: Hashable {
    let isVisible: Bool
    let todoCount: Int
    let latestTodoUpdate: Date?
}

private struct IOSFlowPreparationID: Hashable {
    let isVisible: Bool
    let areaCount: Int
    let latestAreaUpdate: Date?
    let todoCount: Int
    let latestTodoUpdate: Date?
    let projectRevisions: [IOSFlowProjectRevision]
    let revision: Int
}

private struct IOSFlowProjectRevision: Hashable {
    let id: UUID
    let updatedAt: Date
    let completedAt: Date?
    let areaUpdatedAt: Date?
    let areaArchivedAt: Date?
}
