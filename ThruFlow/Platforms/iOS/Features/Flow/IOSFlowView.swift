import SwiftData
import SwiftUI

struct IOSFlowView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Direction.sortIndex) private var directions: [Direction]
    @Query(sort: \Todo.sortIndex) private var todos: [Todo]
    @Query(sort: \FlowSession.startedAt) private var sessions: [FlowSession]
    @Query(sort: \FlowBreak.startedAt) private var flowBreaks: [FlowBreak]

    let open: (IOSAppRoute) -> Void

    @State private var showsContextPicker = false
    @State private var showsMemo = false
    @State private var editorMode: IOSTaskEditorMode?

    private let dashboardBuilder = FlowDashboardBuilder()
    private let todoSorter = FlowDashboardTodoSorter()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let dashboard = snapshot(at: timeline.date)

            ScrollView {
                LazyVStack(spacing: 16) {
                    flowCard(snapshot: dashboard, now: timeline.date)
                    playerCard
                    dashboardPager(snapshot: dashboard)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
            .background(backgroundColor.ignoresSafeArea())
        }
        .navigationTitle(String(localized: "Flow"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        open(.settings)
                    } label: {
                        Label(String(localized: "設定"), systemImage: "gearshape")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(String(localized: "その他"))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomNavigation
        }
        .sheet(isPresented: $showsContextPicker) {
            NavigationStack {
                IOSFlowContextPicker(
                    todos: todayTodos.filter { !$0.isCompleted },
                    directions: activeDirections,
                    selectedTodoID: activeFlowStore.selectedTodoID,
                    selectedDirectionID: activeFlowStore.selectedDirectionID
                ) { direction, todo in
                    select(direction: direction, todo: todo)
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
                IOSTaskEditorView(mode: mode, directions: activeDirections)
            }
        }
        .task {
            prepareToday()
            configureInitialContextIfNeeded()
        }
        .task(id: activeFlowStore.timerState?.phase) {
            guard activeFlowStore.timerState != nil else { return }
            while !Task.isCancelled, activeFlowStore.timerState != nil {
                try? await Task.sleep(for: .seconds(1))
                activeFlowStore.refresh(modelContext: modelContext)
                presentMemoIfNeeded()
            }
        }
        .onChange(of: activeFlowStore.isAwaitingBreakMemo) { _, _ in
            presentMemoIfNeeded()
        }
        .onChange(of: activeFlowStore.phase) { _, _ in
            presentMemoIfNeeded()
        }
    }

    private var activeDirections: [Direction] {
        directions.filter { !$0.isArchived }
    }

    private var todayTodos: [Todo] {
        todoSorter.sorted(todos.filter { TodayTodoFilter(calendar: calendar).includes($0) })
    }

    private var selectedTodo: Todo? {
        todos.first { $0.id == activeFlowStore.selectedTodoID }
    }

    private var selectedDirection: Direction? {
        if let direction = selectedTodo?.direction { return direction }
        return directions.first { $0.id == activeFlowStore.selectedDirectionID }
    }

    private var selectedContextTitle: String {
        if let selectedTodo { return TodoDisplay.title(for: selectedTodo) }
        return selectedDirection?.name ?? String(localized: "タスクを選択")
    }

    private var playerCard: some View {
        VStack(spacing: 12) {
            contextButton
            modePicker

            HStack(spacing: 18) {
                timer
                controls
            }
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var contextButton: some View {
        Button {
            showsContextPicker = true
        } label: {
            HStack(spacing: 12) {
                if let todo = selectedTodo {
                    TodoProgressControl(
                        todo: todo,
                        additionalFocusSeconds: activeTodoFocusSeconds
                    ) {
                        if todo.setManuallyCompleted(!todo.isCompleted) {
                            try? modelContext.save()
                        }
                    }
                }

                Text(selectedDirection?.symbolName ?? "🎯")
                    .font(.title2)
                    .frame(width: 46, height: 46)
                    .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedContextTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if selectedTodo != nil, let direction = selectedDirection {
                        Text(direction.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var modePicker: some View {
        FlowModeSelector(
            selection: modeBinding,
            isSelectionEnabled: activeFlowStore.canChangeMode,
            helpPresentation: .sheet
        )
    }

    private var timer: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.13), lineWidth: 11)
            Circle()
                .trim(from: 0, to: activeFlowStore.phaseProgress(now: activeFlowStore.displayDate))
                .stroke(tint, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: activeFlowStore.displayDate)

            VStack(spacing: 3) {
                Text(activeFlowStore.phase.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(timerText)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(activeFlowStore.selectedMode.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 164, height: 164)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 5) {
                controlButton("gobackward.minus") {
                    activeFlowStore.seekBackward(modelContext: modelContext)
                }
                .disabled(!canSeek)
                .accessibilityLabel(String(localized: "ブロックを短縮"))

                Button(action: primaryAction) {
                    Image(systemName: primarySymbol)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 62, height: 62)
                        .background(tint, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(selectedDirection == nil)

                controlButton("goforward.plus") {
                    activeFlowStore.seekForward(modelContext: modelContext)
                }
                .disabled(!canSeek)
                .accessibilityLabel(String(localized: "ブロックを延長"))
            }

            HStack(spacing: 8) {
                controlButton("trash.fill", role: .destructive) {
                    activeFlowStore.destroy(modelContext: modelContext)
                }
                .disabled(activeFlowStore.timerState == nil)
                .accessibilityLabel(
                    activeFlowStore.isBreakPhase
                        ? String(localized: "休憩を削除")
                        : String(localized: "Flowを破壊")
                )

                controlButton("stop.fill") {
                    activeFlowStore.stop(modelContext: modelContext)
                    presentMemoIfNeeded()
                }
                .disabled(activeFlowStore.timerState == nil)
                .accessibilityLabel(String(localized: "Flowを停止して保存"))

                controlButton("cup.and.saucer.fill") {
                    activeFlowStore.requestBreakMemo(modelContext: modelContext)
                    presentMemoIfNeeded()
                }
                .disabled(activeFlowStore.timerState == nil || activeFlowStore.isBreakPhase)
                .accessibilityLabel(String(localized: "休憩を開始"))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func controlButton(
        _ systemName: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .frame(width: 38, height: 38)
                .background(Color.primary.opacity(0.055), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func flowCard(snapshot: FlowDashboardSnapshot, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "今日のFlow"))
                        .font(.headline)
                    Text(now, format: .dateTime.month().day().weekday())
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
                mode: activeFlowStore.selectedMode
            )
            .frame(height: 142)
            .background(modeSurfaceTint)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            IOSFlowTimelineView(snapshot: snapshot, now: now)
        }
        .padding(14)
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

    private func dashboardPager(snapshot: FlowDashboardSnapshot) -> some View {
        TabView {
            dashboardTasks
            IOSDashboardStatisticsView(snapshot: snapshot)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 310)
    }

    private var dashboardTasks: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(String(localized: "今日のタスク"), systemImage: "checklist")
                    .font(.headline)
                Spacer()
                Button {
                    open(.tasks)
                } label: {
                    Image(systemName: "arrow.up.right")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "タスク"))
            }

            if todayTodos.isEmpty {
                ContentUnavailableView(
                    String(localized: "今日の項目はありません"),
                    systemImage: "checkmark.circle"
                )
            } else {
                ForEach(todayTodos.prefix(5)) { todo in
                    IOSTaskRow(todo: todo) {
                        editorMode = .edit(todo)
                    }
                    if todo.id != todayTodos.prefix(5).last?.id {
                        Divider()
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
    }

    private var bottomNavigation: some View {
        HStack(spacing: 4) {
            navigationButton(String(localized: "タスク"), systemImage: "checklist", route: .tasks)
            navigationButton(String(localized: "履歴"), systemImage: "clock.arrow.circlepath", route: .history)
            navigationButton(
                String(localized: "方向"),
                systemImage: "point.3.connected.trianglepath.dotted",
                route: .directions
            )
            navigationButton(String(localized: "統計"), systemImage: "chart.bar.xaxis", route: .statistics)
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.primary.opacity(0.09))
        }
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private func navigationButton(_ title: String, systemImage: String, route: IOSAppRoute) -> some View {
        Button {
            open(route)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private var modeBinding: Binding<FlowMode> {
        Binding(
            get: { activeFlowStore.selectedMode },
            set: { activeFlowStore.selectMode($0, modelContext: modelContext) }
        )
    }

    private var primarySymbol: String {
        guard let state = activeFlowStore.timerState else { return "play.fill" }
        if state.phase == .paused { return "play.fill" }
        if activeFlowStore.isBreakPhase { return "forward.fill" }
        return "pause.fill"
    }

    private var canSeek: Bool {
        activeFlowStore.phase == .focusing || activeFlowStore.phase == .paused
    }

    private var timerText: String {
        activeFlowStore.timerState == nil
            ? activeFlowStore.selectedMode.shortDurationText
            : activeFlowStore.remainingText(now: activeFlowStore.displayDate)
    }

    private var tint: Color {
        if activeFlowStore.isBreakPhase { return Color.secondary }
        return Color(hex: selectedDirection?.colorHex ?? "#007AFF")
    }

    private var backgroundColor: Color {
        tint.opacity(activeFlowStore.timerState == nil ? 0.025 : 0.055)
    }

    private var modeSurfaceTint: Color {
        switch activeFlowStore.selectedMode {
        case .twelveThree, .adaptive:
            Color.orange.opacity(0.035)
        case .twentyFiveFive:
            Color.cyan.opacity(0.035)
        case .fiftyTen:
            Color.indigo.opacity(0.045)
        }
    }

    private var activeTodoFocusSeconds: Int {
        guard activeFlowStore.timerState != nil else { return 0 }
        return activeFlowStore.actualFocusSeconds(now: activeFlowStore.displayDate)
    }

    private func snapshot(at date: Date) -> FlowDashboardSnapshot {
        dashboardBuilder.build(
            date: date,
            sessions: sessions,
            breaks: flowBreaks,
            activeSessionID: activeFlowStore.activeSession?.id,
            activeFocusSeconds: activeFlowStore.actualFocusSeconds(now: date)
        )
    }

    private func select(direction: Direction, todo: Todo?) {
        if activeFlowStore.timerState == nil {
            activeFlowStore.configure(direction: direction, todo: todo)
        } else {
            activeFlowStore.selectContext(direction: direction, todo: todo, modelContext: modelContext)
        }
    }

    private func primaryAction() {
        if activeFlowStore.isBreakPhase {
            guard let direction = selectedDirection else { return }
            activeFlowStore.startNextFlow(
                direction: direction,
                todo: selectedTodo,
                modelContext: modelContext
            )
            return
        }

        if let state = activeFlowStore.timerState {
            state.phase == .paused
                ? activeFlowStore.resume(modelContext: modelContext)
                : activeFlowStore.pause(modelContext: modelContext)
            return
        }

        guard let direction = selectedDirection else { return }
        activeFlowStore.start(direction: direction, todo: selectedTodo, modelContext: modelContext)
    }

    private func prepareToday() {
        let inbox = DefaultDirections.existingTaskInbox(in: directions) ?? {
            let direction = DefaultDirections.makeTaskInbox()
            modelContext.insert(direction)
            return direction
        }()
        _ = inbox

        let planner = RequiredTodoPlanner(calendar: calendar)
        var existingTodos = todos
        var nextSortIndex = (todos.map(\.sortIndex).max() ?? -1) + 1

        for direction in directions where direction.type == .habit && !direction.isArchived {
            guard let todo = planner.makeRequiredTodo(
                for: direction,
                existingTodos: existingTodos,
                sortIndex: nextSortIndex
            ) else { continue }

            modelContext.insert(todo)
            existingTodos.append(todo)
            nextSortIndex += 1
        }
        try? modelContext.save()
    }

    private func configureInitialContextIfNeeded() {
        guard activeFlowStore.selectedDirectionID == nil else { return }
        if let todo = todayTodos.first(where: { !$0.isCompleted }), let direction = todo.direction {
            activeFlowStore.configure(direction: direction, todo: todo)
        } else if let direction = activeDirections.first {
            activeFlowStore.configure(direction: direction, todo: nil)
        }
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

    private func focusText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return minutes >= 60 ? "\(minutes / 60):\(String(format: "%02d", minutes % 60))" : "\(minutes)\(String(localized: "分"))"
    }

    private func blockText(_ blocks: Double) -> String {
        blocks.formatted(.number.precision(.fractionLength(blocks.rounded() == blocks ? 0 : 1)))
    }
}

private struct IOSDashboardStatisticsView: View {
    let snapshot: FlowDashboardSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(String(localized: "統計"), systemImage: "chart.bar.fill")
                .font(.headline)

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: min(snapshot.blocks / 6, 1))
                        .stroke(primaryColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(snapshot.totalFocusSeconds / 60)")
                            .font(.title2.weight(.semibold))
                            .monospacedDigit()
                        Text(String(localized: "分"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 112, height: 112)

                VStack(alignment: .leading, spacing: 9) {
                    ForEach(snapshot.directionSummaries.prefix(3)) { summary in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("\(summary.symbol) \(summary.name)")
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                Spacer()
                                Text("\(summary.focusSeconds / 60)\(String(localized: "分"))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            GeometryReader { proxy in
                                Capsule()
                                    .fill(Color.primary.opacity(0.07))
                                    .overlay(alignment: .leading) {
                                        Capsule()
                                            .fill(Color(hex: summary.colorHex))
                                            .frame(width: proxy.size.width * share(for: summary.focusSeconds))
                                    }
                            }
                            .frame(height: 5)
                        }
                    }
                }
            }

            if snapshot.directionSummaries.isEmpty {
                Text(String(localized: "Flowを記録すると時間配分が表示されます"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
    }

    private var primaryColor: Color {
        Color(hex: snapshot.directionSummaries.first?.colorHex ?? "#8E8E93")
    }

    private func share(for focusSeconds: Int) -> CGFloat {
        guard snapshot.totalFocusSeconds > 0 else { return 0 }
        return CGFloat(focusSeconds) / CGFloat(snapshot.totalFocusSeconds)
    }
}
