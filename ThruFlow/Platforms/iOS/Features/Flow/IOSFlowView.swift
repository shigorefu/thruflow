import SwiftData
import SwiftUI

struct IOSFlowView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Area.updatedAt, order: .reverse) private var areas: [Area]
    @Query private var todos: [Todo]
    @Query private var sessions: [FlowSession]
    @Query private var flowBreaks: [FlowBreak]

    @Binding private var cachedSnapshot: FlowDashboardSnapshot?
    @Binding private var cachedTodoGroups: FlowDashboardTodoGroups?
    let isVisible: Bool
    let open: (IOSAppRoute) -> Void

    @State private var showsContextPicker = false
    @State private var showsMemo = false
    @State private var showsTaskComposer = false
    @State private var editorMode: IOSTaskEditorMode?
    @State private var selectedHistoryItem: HistoryCalendarItem?
    @State private var preparationRevision = 0
    @State private var taskFilter = IOSDashboardTaskFilter.task

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
        _sessions = Query(
            filter: #Predicate<FlowSession> { $0.startedAt >= cutoff },
            sort: \FlowSession.updatedAt,
            order: .reverse
        )
        _flowBreaks = Query(
            filter: #Predicate<FlowBreak> { $0.startedAt >= cutoff },
            sort: \FlowBreak.updatedAt,
            order: .reverse
        )
        _cachedSnapshot = cachedSnapshot
        _cachedTodoGroups = cachedTodoGroups
        self.open = open
    }

    var body: some View {
        dashboardContent
        .iosCenteredNavigationTitle(String(localized: "Flow"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        open(.settings)
                    } label: {
                        Label(String(localized: "設定"), systemImage: "gearshape")
                    }
                } label: {
                    IOSMoreMenuLabel()
                }
                .accessibilityLabel(String(localized: "その他"))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsTaskComposer, horizontalSizeClass != .regular {
                taskComposer
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .background {
                        Rectangle()
                            .fill(.background)
                            .ignoresSafeArea()
                    }
            }
        }
        .sheet(isPresented: $showsContextPicker) {
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
        .sheet(isPresented: $showsMemo) {
            IOSFlowMemoView(
                isBreakMemo: activeFlowStore.isAwaitingBreakMemo,
                cancel: cancelMemo,
                submit: submitMemo
            )
            .presentationDetents([.medium])
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
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            preparationRevision += 1
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
        .onChange(of: activeFlowStore.phase) { _, _ in
            presentMemoIfNeeded()
        }
        .onChange(of: activeFlowStore.timerState == nil) { _, isIdle in
            guard isIdle else { return }
            reconcileSelectedTodo()
        }
        .onChange(of: isVisible) { _, newValue in
            guard !newValue else { return }
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
        let snapshot = cachedSnapshot ?? .empty()

        return ScrollView {
            ViewThatFits(in: .horizontal) {
                wideDashboard(snapshot: snapshot)
                    .frame(minWidth: 900)

                compactDashboard(snapshot: snapshot)
            }
            .frame(maxWidth: 1_200)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
        }
        .background(backgroundColor.ignoresSafeArea())
    }

    private func compactDashboard(snapshot: FlowDashboardSnapshot) -> some View {
        LazyVStack(spacing: 16) {
            flowCard(snapshot: snapshot)
            playerCard()
            dashboardTasks()
            statisticsCard(snapshot: snapshot)
        }
    }

    private func wideDashboard(snapshot: FlowDashboardSnapshot) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                flowCard(snapshot: snapshot, minHeight: 320)
                    .frame(maxWidth: .infinity)

                playerCard(minHeight: 320)
                    .frame(width: 340)
            }

            HStack(alignment: .top, spacing: 16) {
                dashboardTasks(minHeight: 330)
                    .frame(maxWidth: .infinity)

                statisticsCard(snapshot: snapshot)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func statisticsCard(snapshot: FlowDashboardSnapshot) -> some View {
        IOSDashboardStatisticsView(
            snapshot: snapshot,
            sessions: sessions,
            flowBreaks: flowBreaks,
            todos: todos,
            standardTodos: cachedTodoGroups?.standard ?? [],
            habitTodos: cachedTodoGroups?.habits ?? [],
            niceTodos: cachedTodoGroups?.nice ?? [],
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

    private var selectedContextTitle: String {
        if let selectedTodo { return TodoDisplay.title(for: selectedTodo) }
        return selectedArea?.name ?? String(localized: "タスクを選択")
    }

    private func playerCard(minHeight: CGFloat? = nil) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let activeDay = dayBoundary.day(containing: timeline.date, calendar: calendar)

            playerCardContent(minHeight: minHeight, now: timeline.date)
                .task(id: activeDay) {
                    reconcileSelectedTodo(now: timeline.date)
                }
        }
    }

    private func playerCardContent(minHeight: CGFloat?, now: Date) -> some View {
        FlowTimerPanelShell(
            style: .mobile,
            minHeight: minHeight,
            timer: FlowTimerPresentation(
                progress: activeFlowStore.phaseProgress(now: now),
                tint: tint,
                eyebrow: activeFlowStore.phase.displayName,
                timeText: timerText(at: now),
                footer: activeFlowStore.selectedMode.displayName
            )
        ) {
            contextButton(now: now)
        } mode: {
            modePicker
        } controls: {
            controls(now: now)
        }
    }

    private func contextButton(now: Date) -> some View {
        FlowTimerContextButton(
            style: .mobile,
            presentation: FlowTimerContextPresentation(
                symbol: selectedArea?.symbolName ?? "🎯",
                areaTitle: selectedArea?.name ?? String(localized: "分野"),
                tint: tint,
                detail: nil,
                isPlaceholder: selectedArea == nil,
                showsProgress: selectedTodo != nil
            ),
            accessibilityLabel: selectedContextTitle,
            action: { showsContextPicker = true }
        ) {
            Text(selectedContextTitle)
        } progress: {
            Group {
                if let todo = selectedTodo {
                    TodoProgressControl(
                        todo: todo,
                        additionalFocusSeconds: activeTodoFocusSeconds(at: now)
                    ) {
                        if todo.setManuallyCompleted(!todo.isCompleted) {
                            _ = modelContext.saveReporting(.flowUpdate)
                        }
                    }
                }
            }
        }
    }

    private var modePicker: some View {
        FlowModeSelector(
            selection: modeBinding,
            isSelectionEnabled: activeFlowStore.canChangeMode,
            helpPresentation: .sheet
        )
    }

    private func controls(now: Date) -> some View {
        FlowTimerTransportControls(
            style: .mobile,
            presentation: FlowTimerTransportPresentation(
                primarySymbol: primarySymbol(at: now),
                primaryLabel: primaryActionTitle(at: now),
                primaryTint: tint,
                isPrimaryEnabled: selectedArea != nil,
                canSeek: canSeek,
                canDestroy: activeFlowStore.timerState != nil,
                canStop: activeFlowStore.timerState != nil,
                canStartBreak: activeFlowStore.canRequestBreak,
                destroyLabel: activeFlowStore.isBreakPhase
                    ? String(localized: "休憩を削除")
                    : String(localized: "Flowを破壊"),
                visuallyPressedAction: nil
            )
        ) { action in
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
    }

    private func flowCard(
        snapshot: FlowDashboardSnapshot,
        minHeight: CGFloat? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "今日のFlow"))
                        .font(.headline)
                    Text(snapshot.date, format: .dateTime.month().day().weekday())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                metric(value: focusText(snapshot.totalFocusSeconds), label: String(localized: "集中時間"))
                metric(value: blockText(snapshot.blocks), label: String(localized: "ブロック"))
            }

            IOSFlowStreamView(
                snapshot: snapshot,
                isActive: activeFlowStore.phase == .focusing,
                mode: activeFlowStore.selectedMode,
                breakStyle: activeFlowStore.flowStreamBreakStyle,
                breakInteraction: activeFlowStore.flowBreakInteraction,
                isRenderingEnabled: isVisible
            )
            .frame(height: 142)
            .background(modeSurfaceTint)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if isVisible {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    IOSFlowTimelineView(
                        snapshot: snapshot,
                        now: timeline.date,
                        onOpenHistory: inspectTimelineSelection
                    )
                }
            } else {
                IOSFlowTimelineView(
                    snapshot: snapshot,
                    now: .now,
                    onOpenHistory: inspectTimelineSelection
                )
            }
        }
        .padding(14)
        .frame(minHeight: minHeight, alignment: .topLeading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func dashboardTasks(minHeight: CGFloat = 220) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(String(localized: "今日のタスク"), systemImage: "checklist")
                    .font(.headline)
                Spacer()
                Button(action: presentTaskComposer) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "タスクを追加"))
                .popover(isPresented: regularTaskComposerPresentation, arrowEdge: .top) {
                    taskComposer
                        .frame(width: 520)
                        .presentationCompactAdaptation(.popover)
                }

                Button {
                    open(.tasks)
                } label: {
                    Image(systemName: "arrow.up.right")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "対象タスク"))
            }

            Picker(String(localized: "表示"), selection: $taskFilter) {
                ForEach(IOSDashboardTaskFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if filteredDashboardTodos.isEmpty {
                ContentUnavailableView(
                    String(localized: "今日の項目はありません"),
                    systemImage: "checkmark.circle"
                )
            } else {
                ForEach(filteredDashboardTodos) { todo in
                    IOSTaskRow(todo: todo) {
                        editorMode = .edit(todo)
                    }
                    if todo.id != filteredDashboardTodos.last?.id {
                        Divider()
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
    }

    private var modeBinding: Binding<FlowMode> {
        Binding(
            get: { activeFlowStore.selectedMode },
            set: { mode in
                withAnimation(.easeInOut(duration: 0.8)) {
                    activeFlowStore.selectMode(mode, modelContext: modelContext)
                }
            }
        )
    }

    private func primarySymbol(at date: Date) -> String {
        guard let state = activeFlowStore.timerState else { return "play.fill" }
        if state.phase == .paused { return "play.fill" }
        if activeFlowStore.isBreakPhase { return "forward.fill" }
        if activeFlowStore.isFocusOvertime(now: date) {
            return "cup.and.saucer.fill"
        }
        return "pause.fill"
    }

    private func primaryActionTitle(at date: Date) -> String {
        guard let state = activeFlowStore.timerState else {
            return String(localized: "Flowを開始")
        }
        if state.phase == .paused {
            return String(localized: "再開")
        }
        if activeFlowStore.isBreakPhase {
            return String(localized: "Flowを開始")
        }
        if activeFlowStore.isFocusOvertime(now: date) {
            return String(localized: "休憩")
        }
        return String(localized: "一時停止")
    }

    private var canSeek: Bool {
        activeFlowStore.phase == .focusing ||
            (activeFlowStore.phase == .paused && activeFlowStore.timerState?.phaseBeforePause == .focusing)
    }

    private func timerText(at date: Date) -> String {
        activeFlowStore.timerState == nil
            ? activeFlowStore.selectedMode.compactDurationText
            : activeFlowStore.remainingText(now: date)
    }

    private var tint: Color {
        if activeFlowStore.isBreakPhase { return Color.secondary }
        return Color(hex: selectedArea?.colorHex ?? "#007AFF")
    }

    private var backgroundColor: Color {
        tint.opacity(activeFlowStore.timerState == nil ? 0.025 : 0.055)
    }

    private var modeSurfaceTint: Color {
        switch activeFlowStore.selectedMode {
        case .sprint, .adaptive:
            Color.orange.opacity(0.035)
        case .twentyFiveFive:
            Color.cyan.opacity(0.035)
        case .fiftyTen:
            Color.indigo.opacity(0.045)
        }
    }

    private func activeTodoFocusSeconds(at date: Date) -> Int {
        guard activeFlowStore.timerState != nil else { return 0 }
        return activeFlowStore.actualFocusSeconds(now: date)
    }

    private func makeSnapshot(at date: Date) -> FlowDashboardSnapshot {
        let day = dayBoundary.day(containing: date, calendar: calendar)
        let interval = dayBoundary.interval(for: day, calendar: calendar)
        let daySessions = sessions.filter { interval.contains($0.startedAt) }
        let dayBreaks = flowBreaks.filter { interval.contains($0.startedAt) }

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
            sessionCount: sessions.count,
            latestSessionUpdate: sessions.first?.updatedAt,
            breakCount: flowBreaks.count,
            latestBreakUpdate: flowBreaks.first?.updatedAt,
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
        try? await Task.sleep(for: .milliseconds(220))
        guard !Task.isCancelled, isVisible else { return }
        prepareToday()
        reconcileSelectedTodo()
        configureInitialContextIfNeeded()
    }

    @MainActor
    private func refreshDashboardCache() async {
        guard isVisible else { return }

        try? await Task.sleep(for: .milliseconds(cachedSnapshot == nil ? 220 : 350))
        guard !Task.isCancelled, isVisible else { return }

        cachedSnapshot = makeSnapshot(at: .now)

        while !Task.isCancelled, isVisible, activeFlowStore.timerState != nil {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, isVisible else { return }
            cachedSnapshot = makeSnapshot(at: .now)
        }
    }

    @MainActor
    private func refreshTodoGroupsCache() async {
        guard isVisible else { return }

        try? await Task.sleep(for: .milliseconds(cachedTodoGroups == nil ? 160 : 280))
        guard !Task.isCancelled, isVisible else { return }

        cachedTodoGroups = FlowDashboardTodoGroupBuilder(
            calendar: calendar,
            dayBoundary: dayBoundary
        ).build(from: todos)
    }

    private func select(area: Area, todo: Todo?) {
        if activeFlowStore.timerState == nil {
            activeFlowStore.configure(area: area, todo: todo)
        } else {
            activeFlowStore.selectContext(area: area, todo: todo, modelContext: modelContext)
        }
    }

    private func inspectTimelineSelection(_ selection: IOSFlowTimelineSelection) {
        let today = dayBoundary.day(containing: .now, calendar: calendar)
        let interval = dayBoundary.interval(for: today, calendar: calendar)
        let items = HistoryCalendarBuilder(calendar: calendar)
            .build(
                interval: interval,
                sessions: sessions,
                breaks: flowBreaks,
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
        if let todo = todayTodos.first(where: { !$0.isCompleted }), let area = todo.area {
            activeFlowStore.configure(area: area, todo: todo)
        } else if let area = activeAreas.first {
            activeFlowStore.configure(area: area, todo: nil)
        }
    }

    private func reconcileSelectedTodo(now: Date = .now) {
        activeFlowStore.reconcileSelectedTodoForCurrentDay(
            todos: todos,
            areas: areas,
            now: now,
            calendar: calendar,
            dayBoundary: dayBoundary
        )
    }

    private func presentMemoIfNeeded() {
        showsMemo = activeFlowStore.isAwaitingBreakMemo || activeFlowStore.phase == .awaitingResult
    }

    private func cancelMemo() {
        if activeFlowStore.isAwaitingBreakMemo {
            activeFlowStore.cancelBreakMemo()
        } else {
            activeFlowStore.cancelResultMemo(modelContext: modelContext)
        }
        showsMemo = false
    }

    private func submitMemo(_ memo: String?) {
        if activeFlowStore.isAwaitingBreakMemo {
            activeFlowStore.completeBreakMemo(memo, modelContext: modelContext)
        } else {
            activeFlowStore.completeResult(memo, modelContext: modelContext)
        }
        showsMemo = false
    }

    private func presentTaskComposer() {
        withAnimation(.snappy(duration: 0.28)) {
            showsTaskComposer = true
        }
    }

    private func dismissTaskComposer() {
        withAnimation(.snappy(duration: 0.24)) {
            showsTaskComposer = false
        }
    }

    private var taskComposer: some View {
        IOSTaskComposer(
            areas: activeAreas,
            onClose: dismissTaskComposer
        )
    }

    private var regularTaskComposerPresentation: Binding<Bool> {
        Binding(
            get: { showsTaskComposer && horizontalSizeClass == .regular },
            set: { isPresented in
                if !isPresented {
                    showsTaskComposer = false
                }
            }
        )
    }

    private func focusText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return minutes >= 60 ? "\(minutes / 60):\(String(format: "%02d", minutes % 60))" : "\(minutes)\(String(localized: "分"))"
    }

    private func blockText(_ blocks: Double) -> String {
        blocks.formatted(.number.precision(.fractionLength(blocks.rounded() == blocks ? 0 : 1)))
    }
}

private struct FlowRefreshTaskID: Hashable {
    let isVisible: Bool
    let phaseRawValue: String?
}

private struct IOSFlowDashboardRefreshID: Hashable {
    let isVisible: Bool
    let sessionCount: Int
    let latestSessionUpdate: Date?
    let breakCount: Int
    let latestBreakUpdate: Date?
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
    let revision: Int
}

private enum IOSDashboardTaskFilter: String, CaseIterable, Identifiable {
    case task
    case habit
    case nice

    var id: String { rawValue }

    var title: String {
        switch self {
        case .task: String(localized: "タスク")
        case .habit: String(localized: "習慣一覧")
        case .nice: String(localized: "ナイス")
        }
    }
}

private struct IOSDashboardStatisticsView: View {
    let snapshot: FlowDashboardSnapshot
    let sessions: [FlowSession]
    let flowBreaks: [FlowBreak]
    let todos: [Todo]
    let standardTodos: [Todo]
    let habitTodos: [Todo]
    let niceTodos: [Todo]
    let calendar: Calendar
    let dayBoundary: AppDayBoundary

    @State private var page = IOSDashboardStatisticsPage.distribution
    @State private var distributionMode = IOSDashboardDistributionMode.task

    private var statisticsBuilder: DashboardStatisticsBuilder {
        DashboardStatisticsBuilder(calendar: calendar, dayBoundary: dayBoundary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(String(localized: "統計"), systemImage: "chart.bar.xaxis")
                    .font(.headline)
                Spacer()
                HStack(spacing: 5) {
                    ForEach(IOSDashboardStatisticsPage.allCases) { value in
                        Circle()
                            .fill(value == page ? Color.accentColor : Color.secondary.opacity(0.25))
                            .frame(width: 5, height: 5)
                    }
                }
            }

            Text(page.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Group {
                switch page {
                case .distribution:
                    distributionPage
                case .trend:
                    trendPage
                case .achievement:
                    achievementPage
                }
            }
            .id(page)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 330, alignment: .topLeading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
        .iosHorizontalPeriodSwipe { offset in
            movePage(offset)
        }
    }

    private var distributionPage: some View {
        VStack(spacing: 12) {
            Picker(String(localized: "集計単位"), selection: $distributionMode) {
                ForEach(IOSDashboardDistributionMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            distributionDonut

            VStack(alignment: .leading, spacing: 9) {
                ForEach(distributionRows.prefix(4)) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(row.symbol) \(row.title)")
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(focusText(row.focusSeconds))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        GeometryReader { proxy in
                            Capsule()
                                .fill(Color.primary.opacity(0.07))
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(hex: row.colorHex))
                                        .frame(
                                            width: proxy.size.width
                                                * CGFloat(snapshot.focusShare(for: row.focusSeconds))
                                        )
                                }
                        }
                        .frame(height: 5)
                    }
                }
            }

            if distributionRows.isEmpty {
                Text(String(localized: "Flowを記録すると時間配分が表示されます"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var distributionDonut: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 12)
            ForEach(distributionSlices) { slice in
                Circle()
                    .trim(from: slice.start, to: slice.end)
                    .stroke(
                        Color(hex: slice.colorHex),
                        style: StrokeStyle(lineWidth: 12, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 1) {
                Text(focusText(snapshot.totalFocusSeconds))
                    .font(.callout.weight(.bold))
                    .minimumScaleFactor(0.7)
                    .monospacedDigit()
                Text(String(localized: "今日の集中"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 112, height: 112)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.25), value: snapshot.totalFocusSeconds)
    }

    private var trendPage: some View {
        let days = statisticsBuilder.days(
            count: 7,
            endingOn: snapshot.date,
            sessions: sessions,
            breaks: flowBreaks
        )
        let comparison = statisticsBuilder.comparison(
            on: snapshot.date,
            sessions: sessions,
            breaks: flowBreaks,
            todos: todos
        )

        return VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "7日"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            IOSDashboardStatisticsBars(days: days)
                .frame(height: 112)

            Divider()

            comparisonRow(
                String(localized: "集中時間"),
                value: signedMinutes(comparison.focusSecondsDelta),
                systemImage: "timer"
            )
            comparisonRow(
                String(localized: "完了タスク"),
                value: signedCount(comparison.completedTaskDelta),
                systemImage: "checkmark.circle"
            )
            comparisonRow(
                String(localized: "ブロック"),
                value: signedBlocks(comparison.blocksDelta),
                systemImage: "square.stack.3d.up"
            )
            comparisonRow(
                String(localized: "伸びた方向"),
                value: growthText(comparison.growingArea),
                systemImage: "arrow.up.right"
            )
        }
    }

    private var achievementPage: some View {
        let required = standardTodos + habitTodos
        let completed = required.filter(\.isCompleted).count
        let ratio = required.isEmpty ? 0 : Double(completed) / Double(required.count)

        return VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: ratio)
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text("\(Int((ratio * 100).rounded()))%")
                    .font(.title3.bold())
                    .monospacedDigit()
            }
            .frame(width: 112, height: 112)

            achievementRow(
                String(localized: "タスク"),
                completed: standardTodos.filter(\.isCompleted).count,
                total: standardTodos.count
            )
            achievementRow(
                String(localized: "習慣一覧"),
                completed: habitTodos.filter(\.isCompleted).count,
                total: habitTodos.count
            )
            if !niceTodos.isEmpty {
                achievementRow(
                    String(localized: "ナイス"),
                    completed: niceTodos.filter(\.isCompleted).count,
                    total: niceTodos.count
                )
            }

            Text(String(localized: "今日の達成 \(completed) / \(required.count)"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private var distributionRows: [IOSDashboardDistributionRow] {
        switch distributionMode {
        case .task:
            snapshot.taskSummaries.map {
                IOSDashboardDistributionRow(
                    id: $0.id,
                    symbol: $0.symbol,
                    title: $0.title,
                    colorHex: $0.colorHex,
                    focusSeconds: $0.focusSeconds
                )
            }
        case .area:
            snapshot.areaSummaries.map {
                IOSDashboardDistributionRow(
                    id: $0.id.uuidString,
                    symbol: $0.symbol,
                    title: $0.name,
                    colorHex: $0.colorHex,
                    focusSeconds: $0.focusSeconds
                )
            }
        }
    }

    private var distributionSlices: [IOSDashboardFlowSlice] {
        guard snapshot.totalFocusSeconds > 0 else { return [] }

        var cursor = 0.0
        return distributionRows.map { row in
            let fraction = Double(row.focusSeconds) / Double(snapshot.totalFocusSeconds)
            let gap = distributionRows.count > 1 ? min(0.004, fraction * 0.18) : 0
            let slice = IOSDashboardFlowSlice(
                id: row.id,
                start: cursor + (gap / 2),
                end: cursor + fraction - (gap / 2),
                colorHex: row.colorHex
            )
            cursor += fraction
            return slice
        }
    }

    private func movePage(_ offset: Int) {
        let pages = IOSDashboardStatisticsPage.allCases
        guard let current = pages.firstIndex(of: page) else { return }
        let next = (current + offset + pages.count) % pages.count
        withAnimation(.easeInOut(duration: 0.2)) {
            page = pages[next]
        }
    }

    private func comparisonRow(_ title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.caption)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    private func achievementRow(_ title: String, completed: Int, total: Int) -> some View {
        HStack {
            Text(title)
                .font(.caption)
            Spacer()
            Text("\(completed) / \(total)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
    }

    private func focusText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes >= 60 {
            return "\(minutes / 60):\(String(format: "%02d", minutes % 60))"
        }
        return "\(minutes)\(String(localized: "分"))"
    }

    private func signedMinutes(_ seconds: Int) -> String {
        signedValue(Int((Double(seconds) / 60).rounded()), suffix: String(localized: "分"))
    }

    private func signedCount(_ count: Int) -> String {
        signedValue(count, suffix: "")
    }

    private func signedBlocks(_ blocks: Double) -> String {
        let sign = blocks > 0 ? "+" : ""
        let value = abs(blocks) < 0.001 ? 0 : blocks
        let text = value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
        return "\(sign)\(text)"
    }

    private func signedValue(_ value: Int, suffix: String) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(value)\(suffix)"
    }

    private func growthText(_ growth: DashboardStatisticsAreaGrowth?) -> String {
        guard let growth else { return String(localized: "変化なし") }
        let minutes = max(1, growth.focusSecondsDelta / 60)
        return "\(growth.symbol) \(growth.name) +\(minutes)\(String(localized: "分"))"
    }
}

private enum IOSDashboardStatisticsPage: Int, CaseIterable, Identifiable {
    case distribution
    case trend
    case achievement

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .distribution: String(localized: "時間配分")
        case .trend: String(localized: "Flow推移")
        case .achievement: String(localized: "達成状況")
        }
    }
}

private enum IOSDashboardDistributionMode: String, CaseIterable, Identifiable {
    case task
    case area

    var id: String { rawValue }
    var title: String { self == .task ? String(localized: "タスク別") : String(localized: "方向別") }
}

private struct IOSDashboardDistributionRow: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let colorHex: String
    let focusSeconds: Int
}

private struct IOSDashboardFlowSlice: Identifiable {
    let id: String
    let start: Double
    let end: Double
    let colorHex: String
}

private struct IOSDashboardStatisticsBars: View {
    let days: [DashboardStatisticsDay]

    var body: some View {
        GeometryReader { proxy in
            let maximum = max(days.map(\.focusSeconds).max() ?? 0, 1)

            HStack(alignment: .bottom, spacing: 7) {
                ForEach(days) { day in
                    let minimumHeight: CGFloat = day.focusSeconds > 0 ? 4 : 2
                    let availableHeight = max(proxy.size.height - 23, 0)
                    let proportionalHeight = availableHeight
                        * CGFloat(day.focusSeconds)
                        / CGFloat(maximum)
                    let barHeight = max(minimumHeight, proportionalHeight)

                    VStack(spacing: 5) {
                        Spacer(minLength: 0)
                        Capsule()
                            .fill(Color(hex: day.colorHex))
                            .frame(width: 7, height: barHeight)
                        Text(day.date.formatted(.dateTime.day()))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(dayAccessibilityLabel(day))
                }
            }
        }
    }

    private func dayAccessibilityLabel(_ day: DashboardStatisticsDay) -> String {
        "\(day.date.formatted(date: .abbreviated, time: .omitted)), \(day.focusSeconds / 60)\(String(localized: "分"))"
    }
}
