import Foundation
import SwiftData
import SwiftUI

struct WatchFlowDashboardView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Direction.sortIndex) private var directions: [Direction]
    @Query private var todos: [Todo]

    private let todoSorter = FlowDashboardTodoSorter()
    @State private var selectedPage = WatchDashboardPage.timer

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedPage) {
                WatchTimerView()
                    .tag(WatchDashboardPage.timer)

                WatchFlowStreamView(isVisible: selectedPage == .flow)
                    .tag(WatchDashboardPage.flow)

                WatchTasksView()
                    .tag(WatchDashboardPage.tasks)

                WatchStatisticsView()
                    .tag(WatchDashboardPage.statistics)
            }
            .tabViewStyle(.verticalPage(transitionStyle: .blur))
        }
        .onAppear {
            prepareToday()
            configureInitialContextIfNeeded()
        }
        .onChange(of: directions.map(\.id)) {
            prepareToday()
            configureInitialContextIfNeeded()
        }
        .onChange(of: todos.map(\.id)) {
            configureInitialContextIfNeeded()
        }
    }

    private var activeDirections: [Direction] {
        directions.filter { $0.archivedAt == nil }
    }

    private var todayTodos: [Todo] {
        todoSorter.sorted(
            todos.filter {
                TodayTodoFilter(
                    calendar: calendar,
                    dayBoundary: dayBoundary
                ).includes($0)
            }
        )
    }

    private func prepareToday() {
        guard !activeDirections.isEmpty else { return }
        let today = dayBoundary.day(containing: .now, calendar: calendar)
        _ = try? HabitTodoMaterializer(
            calendar: calendar,
            dayBoundary: dayBoundary
        ).materialize(
            directions: activeDirections,
            dates: [today],
            modelContext: modelContext
        )
    }

    private func configureInitialContextIfNeeded() {
        guard activeFlowStore.selectedDirectionID == nil else { return }

        if let todo = todayTodos.first(where: { !$0.isCompleted }),
           let direction = todo.direction {
            activeFlowStore.configure(direction: direction, todo: todo)
        } else if let direction = activeDirections.first {
            activeFlowStore.configure(direction: direction, todo: nil)
        }
    }

}

private enum WatchDashboardPage: Hashable {
    case timer
    case flow
    case tasks
    case statistics
}

private struct WatchFlowStreamView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore
    @Query(sort: \Direction.sortIndex) private var directions: [Direction]
    @Query private var sessions: [FlowSession]
    @Query private var flowBreaks: [FlowBreak]

    let isVisible: Bool
    @State private var isImmersive = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let snapshot = FlowDashboardBuilder(
                calendar: calendar,
                dayBoundary: dayBoundary
            ).build(
                date: timeline.date,
                sessions: sessions,
                breaks: flowBreaks,
                activeSessionID: activeFlowStore.activeSession?.id,
                activeFocusSeconds: activeFlowStore.actualFocusSeconds(now: timeline.date),
                visualIdentityID: DailyFlowIdentity.resolve(from: directions)
            )

            FlowStreamSurface(
                blocks: snapshot.blocks,
                flowCount: snapshot.flowCount,
                palette: snapshot.palette,
                paletteWeights: snapshot.paletteWeights,
                dailySeed: snapshot.dailyVisualSeed,
                isActive: activeFlowStore.phase == .focusing,
                mode: activeFlowStore.selectedMode,
                breakStyle: activeFlowStore.flowStreamBreakStyle,
                breakInteraction: activeFlowStore.flowBreakInteraction,
                isRenderingEnabled: isVisible
            )
            .ignoresSafeArea()
            .overlay {
                if !isImmersive {
                    VStack {
                        HStack {
                            Text(String(localized: "今日のFlow"))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay {
                                    Capsule()
                                        .strokeBorder(Color.white.opacity(0.22))
                                }
                            Spacer()
                        }

                        Spacer()

                        HStack {
                            Text(BlockUnit.displayText(forFocusedSeconds: snapshot.totalFocusSeconds))
                            Spacer()
                            Text("\(snapshot.flowCount) Flow")
                        }
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.16))
                        }
                    }
                    .padding(8)
                    .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isImmersive.toggle()
                }
            }
        }
        .accessibilityHint(
            isImmersive
                ? String(localized: "情報を表示")
                : String(localized: "情報を隠す")
        )
    }
}

private struct WatchTimerView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Direction.sortIndex) private var directions: [Direction]
    @Query private var todos: [Todo]

    @State private var showsMemo = false
    @State private var restButtonReactionSequence = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            GeometryReader { proxy in
                let isCompact = proxy.size.width < 180
                let ringSize = isCompact
                    ? min(66, proxy.size.width * 0.41)
                    : min(proxy.size.width * 0.44, max(76, proxy.size.height - 112))

                VStack(spacing: 4) {
                    contextPicker
                    modePicker(isCompact: isCompact)

                    HStack(spacing: isCompact ? 3 : 6) {
                        timerRing(now: timeline.date, size: ringSize)
                        controls(isCompact: isCompact)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 4)
            }
        }
        .sheet(isPresented: $showsMemo) {
            WatchFlowMemoView {
                showsMemo = false
            }
        }
    }

    private var contextPicker: some View {
        NavigationLink {
            WatchFlowContextPicker()
        } label: {
            HStack(spacing: 6) {
                Text(selectedDirection?.symbolName ?? "🎯")
                VStack(alignment: .leading, spacing: 0) {
                    Text(selectedContextTitle)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(selectedDirection?.name ?? String(localized: "方向"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 7)
            .frame(height: 32)
            .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(tint.opacity(0.2))
            }
        }
        .buttonStyle(.plain)
    }

    private func modePicker(isCompact: Bool) -> some View {
        NavigationLink {
            WatchFlowModePicker()
        } label: {
            HStack {
                Text(activeFlowStore.selectedMode.displayName)
                Spacer()
                if !isCompact {
                    Text(activeFlowStore.selectedMode.compactDurationText)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 7)
            .frame(height: 26)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func timerRing(now: Date, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.2), lineWidth: 8)
            Circle()
                .trim(from: 0, to: activeFlowStore.phaseProgress(now: now))
                .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text(activeFlowStore.phase.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(timerText(now: now))
                    .font(.system(size: max(18, size * 0.24), weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(activeFlowStore.selectedMode.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    private func controls(isCompact: Bool) -> some View {
        let secondarySize: CGFloat = isCompact ? 24 : 28
        let primarySize: CGFloat = isCompact ? 36 : 44
        let spacing: CGFloat = isCompact ? 2 : 3

        return VStack(spacing: isCompact ? 3 : 5) {
            HStack(spacing: spacing) {
                timerButton("gobackward.5", size: secondarySize) {
                    activeFlowStore.seekBackward(modelContext: modelContext)
                }
                .disabled(!canSeek)

                Button(action: primaryAction) {
                    Image(systemName: primarySymbol)
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: primarySize, height: primarySize)
                        .background(tint, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(selectedDirection == nil)

                timerButton("goforward.5", size: secondarySize) {
                    activeFlowStore.seekForward(modelContext: modelContext)
                }
                .disabled(!canSeek)
            }

            HStack(spacing: spacing) {
                timerButton(
                    "trash.fill",
                    role: .destructive,
                    tint: .red,
                    size: secondarySize
                ) {
                    activeFlowStore.destroy(modelContext: modelContext)
                }
                .disabled(activeFlowStore.timerState == nil)

                timerButton("stop.fill", size: secondarySize) {
                    activeFlowStore.stop(modelContext: modelContext)
                    showsMemo = activeFlowStore.phase == .awaitingResult
                }
                .disabled(activeFlowStore.timerState == nil)

                timerButton(
                    "cup.and.saucer.fill",
                    size: secondarySize,
                    symbolEffectValue: restButtonReactionSequence
                ) {
                    restButtonReactionSequence &+= 1
                    activeFlowStore.requestBreakMemo(modelContext: modelContext)
                    showsMemo = activeFlowStore.isAwaitingBreakMemo
                }
                .disabled(!activeFlowStore.canRequestBreak)
                .sensoryFeedback(
                    .impact(weight: .light),
                    trigger: restButtonReactionSequence
                )
            }
        }
    }

    private var activeDirections: [Direction] {
        directions.filter { $0.archivedAt == nil }
    }

    private var todayTodos: [Todo] {
        FlowDashboardTodoSorter().sorted(
            todos.filter {
                TodayTodoFilter(
                    calendar: calendar,
                    dayBoundary: dayBoundary
                ).includes($0)
            }
        )
    }

    private var selectedDirection: Direction? {
        activeDirections.first { $0.id == activeFlowStore.selectedDirectionID }
    }

    private var selectedTodo: Todo? {
        todayTodos.first { $0.id == activeFlowStore.selectedTodoID }
    }

    private var selectedContextTitle: String {
        if let selectedTodo {
            return TodoDisplay.title(for: selectedTodo)
        }
        return selectedDirection?.name ?? String(localized: "タスクを選択")
    }

    private var tint: Color {
        activeFlowStore.isBreakPhase
            ? .secondary
            : Color(hex: selectedDirection?.colorHex ?? "#0A84FF")
    }

    private var primarySymbol: String {
        guard let state = activeFlowStore.timerState else { return "play.fill" }
        if state.phase == .paused { return "play.fill" }
        if activeFlowStore.isBreakPhase { return "forward.fill" }
        return "pause.fill"
    }

    private var canSeek: Bool {
        activeFlowStore.phase == .focusing ||
            (
                activeFlowStore.phase == .paused &&
                    activeFlowStore.timerState?.phaseBeforePause == .focusing
            )
    }

    private func timerText(now: Date) -> String {
        activeFlowStore.timerState == nil
            ? activeFlowStore.selectedMode.compactDurationText
            : activeFlowStore.remainingText(now: now)
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
        activeFlowStore.start(
            direction: direction,
            todo: selectedTodo,
            modelContext: modelContext
        )
    }

    private func timerButton(
        _ systemName: String,
        role: ButtonRole? = nil,
        tint: Color = .secondary,
        size: CGFloat = 28,
        symbolEffectValue: Int = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .symbolEffect(.bounce, value: symbolEffectValue)
                .frame(width: size, height: size)
                .background(Color.primary.opacity(0.055), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct WatchFlowContextPicker: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Direction.sortIndex) private var directions: [Direction]
    @Query private var todos: [Todo]

    var body: some View {
        List {
            if !todayTodos.isEmpty {
                Section(String(localized: "今日のタスク")) {
                    ForEach(todayTodos) { todo in
                        Button {
                            select(direction: todo.direction, todo: todo)
                        } label: {
                            Label {
                                Text(TodoDisplay.title(for: todo))
                                    .lineLimit(1)
                            } icon: {
                                Text(todo.direction?.symbolName ?? "📝")
                            }
                        }
                    }
                }
            }

            Section(String(localized: "方向")) {
                ForEach(activeDirections) { direction in
                    Button {
                        select(direction: direction, todo: nil)
                    } label: {
                        Label {
                            Text(direction.name)
                                .lineLimit(1)
                        } icon: {
                            Text(direction.symbolName)
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "タスクを選択"))
    }

    private var activeDirections: [Direction] {
        directions.filter { $0.archivedAt == nil }
    }

    private var todayTodos: [Todo] {
        FlowDashboardTodoSorter().sorted(
            todos.filter {
                TodayTodoFilter(
                    calendar: calendar,
                    dayBoundary: dayBoundary
                ).includes($0)
            }
        )
    }

    private func select(direction: Direction?, todo: Todo?) {
        guard let direction else { return }
        if activeFlowStore.timerState == nil {
            activeFlowStore.configure(direction: direction, todo: todo)
        } else {
            activeFlowStore.selectContext(
                direction: direction,
                todo: todo,
                modelContext: modelContext
            )
        }
        dismiss()
    }
}

private struct WatchFlowModePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    private let modes: [FlowMode] = [.sprint, .twentyFiveFive, .fiftyTen]

    var body: some View {
        List(modes) { mode in
            Button {
                activeFlowStore.selectMode(mode, modelContext: modelContext)
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.displayName)
                        Text(mode.blockSummary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if activeFlowStore.selectedMode == mode {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "Flowタイプ"))
    }
}

private struct WatchFlowMemoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @State private var memo = ""
    let onComplete: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField(String(localized: "何をしましたか"), text: $memo)

                Button(String(localized: "送信")) {
                    submit(memo)
                }

                Button(String(localized: "メモなしで送信")) {
                    submit(nil)
                }

                Button(String(localized: "キャンセル"), role: .cancel) {
                    cancel()
                }
            }
            .navigationTitle(String(localized: "メモ"))
        }
    }

    private func submit(_ value: String?) {
        if activeFlowStore.isAwaitingBreakMemo {
            activeFlowStore.completeBreakMemo(value, modelContext: modelContext)
        } else {
            activeFlowStore.completeResult(value, modelContext: modelContext)
        }
        onComplete()
        dismiss()
    }

    private func cancel() {
        if activeFlowStore.isAwaitingBreakMemo {
            activeFlowStore.cancelBreakMemo()
        } else {
            activeFlowStore.cancelResultMemo(modelContext: modelContext)
        }
        onComplete()
        dismiss()
    }
}

private struct WatchTasksView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [Todo]
    @State private var showsTaskForm = false

    var body: some View {
        List {
            if todayTodos.isEmpty {
                ContentUnavailableView(
                    String(localized: "今日の項目はありません"),
                    systemImage: "checkmark.circle"
                )
            } else {
                ForEach(todayTodos) { todo in
                    HStack(spacing: 5) {
                        TodoProgressControl(todo: todo) {
                            guard todo.measurement == .checkbox else { return }
                            todo.setCompleted(!todo.isCompleted)
                            try? modelContext.save()
                        }
                        Text(todo.direction?.symbolName ?? "📝")
                        VStack(alignment: .leading, spacing: 1) {
                            Text(TodoDisplay.title(for: todo))
                                .lineLimit(2)
                                .strikethrough(todo.isCompleted)
                            Text(progressText(todo))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "今日のタスク"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsTaskForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "タスクを追加"))
            }
        }
        .sheet(isPresented: $showsTaskForm) {
            WatchTaskCreationForm()
        }
    }

    private var todayTodos: [Todo] {
        FlowDashboardTodoSorter().sorted(
            todos.filter {
                TodayTodoFilter(
                    calendar: calendar,
                    dayBoundary: dayBoundary
                ).includes($0)
            }
        )
    }

    private func progressText(_ todo: Todo) -> String {
        TodoProgressCalculator().summary(
            measurement: todo.measurement,
            plannedAmount: todo.plannedAmount,
            actualProgress: todo.actualProgress,
            focusDurationSeconds: todo.recordedFocusSeconds
        )
    }
}

private struct WatchStatisticsView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query private var todos: [Todo]
    @Query private var sessions: [FlowSession]
    @Query private var flowBreaks: [FlowBreak]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let snapshot = FlowDashboardBuilder(
                calendar: calendar,
                dayBoundary: dayBoundary
            ).build(
                date: timeline.date,
                sessions: sessions,
                breaks: flowBreaks,
                activeSessionID: activeFlowStore.activeSession?.id,
                activeFocusSeconds: activeFlowStore.actualFocusSeconds(now: timeline.date)
            )

            ScrollView {
                VStack(spacing: 10) {
                    Gauge(value: completionProgress) {
                        Text(String(localized: "達成状況"))
                    } currentValueLabel: {
                        Text("\(Int((completionProgress * 100).rounded()))%")
                            .font(.headline)
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(.green)
                    .frame(height: 105)

                    statisticRow(
                        String(localized: "集中時間"),
                        value: focusText(snapshot.totalFocusSeconds),
                        systemImage: "timer"
                    )
                    statisticRow(
                        String(localized: "ブロック"),
                        value: blockText(snapshot.blocks),
                        systemImage: "square.stack.3d.up"
                    )
                    statisticRow(
                        "Flow",
                        value: "\(snapshot.flowCount)",
                        systemImage: "waveform.path"
                    )
                    statisticRow(
                        String(localized: "完了"),
                        value: "\(todayTodos.filter(\.isCompleted).count)/\(todayTodos.count)",
                        systemImage: "checkmark.circle"
                    )
                }
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle(String(localized: "統計"))
    }

    private var todayTodos: [Todo] {
        todos.filter {
            TodayTodoFilter(
                calendar: calendar,
                dayBoundary: dayBoundary
            ).includes($0)
        }
    }

    private var completionProgress: Double {
        guard !todayTodos.isEmpty else { return 0 }
        return Double(todayTodos.filter(\.isCompleted).count) / Double(todayTodos.count)
    }

    private func statisticRow(
        _ title: String,
        value: String,
        systemImage: String
    ) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.caption)
        .padding(8)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private func focusText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return minutes >= 60
            ? "\(minutes / 60):\(String(format: "%02d", minutes % 60))"
            : "\(minutes)\(String(localized: "分"))"
    }

    private func blockText(_ blocks: Double) -> String {
        blocks.formatted(
            .number.precision(.fractionLength(blocks.rounded() == blocks ? 0 : 1))
        )
    }
}
