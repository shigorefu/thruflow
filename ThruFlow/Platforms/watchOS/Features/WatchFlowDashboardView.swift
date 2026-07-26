import Foundation
import SwiftData
import SwiftUI

struct WatchFlowDashboardView: View {
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
            todos.filter { TodayTodoFilter(calendar: calendar).includes($0) }
        )
    }

    private func prepareToday() {
        guard !activeDirections.isEmpty else { return }
        _ = try? HabitTodoMaterializer(calendar: calendar).materialize(
            directions: activeDirections,
            dates: [.now],
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
    @Environment(\.calendar) private var calendar
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore
    @Query(sort: \Direction.sortIndex) private var directions: [Direction]
    @Query private var sessions: [FlowSession]
    @Query private var flowBreaks: [FlowBreak]

    let isVisible: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let snapshot = FlowDashboardBuilder(calendar: calendar).build(
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
                isRenderingEnabled: isVisible
            )
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                HStack {
                    Text(
                        "\(snapshot.blocks.formatted(.number.precision(.fractionLength(1)))) Block"
                    )
                    Spacer()
                    Text("\(snapshot.flowCount) Flow")
                }
                .font(.caption2.weight(.semibold))
                .padding(8)
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle(String(localized: "今日のFlow"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WatchTimerView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Direction.sortIndex) private var directions: [Direction]
    @Query private var todos: [Todo]

    @State private var showsMemo = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            GeometryReader { proxy in
                let ringSize = min(
                    proxy.size.width * 0.48,
                    max(72, proxy.size.height - 118)
                )

                VStack(spacing: 4) {
                    contextPicker
                    modePicker
                    timerRing(now: timeline.date, size: ringSize)
                    controls
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
            .frame(height: 34)
            .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(tint.opacity(0.2))
            }
        }
        .buttonStyle(.plain)
    }

    private var modePicker: some View {
        NavigationLink {
            WatchFlowModePicker()
        } label: {
            HStack {
                Text(activeFlowStore.selectedMode.displayName)
                Spacer()
                Text(activeFlowStore.selectedMode.compactDurationText)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 7)
            .frame(height: 28)
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
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text(activeFlowStore.selectedMode.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    private var controls: some View {
        HStack(spacing: 1) {
            timerButton("trash.fill", role: .destructive, tint: .red) {
                activeFlowStore.destroy(modelContext: modelContext)
            }
            .disabled(activeFlowStore.timerState == nil)

            timerButton("stop.fill") {
                activeFlowStore.stop(modelContext: modelContext)
                showsMemo = activeFlowStore.phase == .awaitingResult
            }
            .disabled(activeFlowStore.timerState == nil)

            timerButton("gobackward.5") {
                activeFlowStore.seekBackward(modelContext: modelContext)
            }
            .disabled(!canSeek)

            Button(action: primaryAction) {
                Image(systemName: primarySymbol)
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(tint, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(selectedDirection == nil)

            timerButton("goforward.5") {
                activeFlowStore.seekForward(modelContext: modelContext)
            }
            .disabled(!canSeek)

            timerButton("cup.and.saucer.fill") {
                activeFlowStore.requestBreakMemo(modelContext: modelContext)
                showsMemo = activeFlowStore.isAwaitingBreakMemo
            }
            .disabled(activeFlowStore.timerState == nil || activeFlowStore.isBreakPhase)
        }
        .frame(height: 40)
        .padding(.horizontal, 3)
        .background(Color.primary.opacity(0.055), in: Capsule())
    }

    private var activeDirections: [Direction] {
        directions.filter { $0.archivedAt == nil }
    }

    private var todayTodos: [Todo] {
        FlowDashboardTodoSorter().sorted(
            todos.filter { TodayTodoFilter(calendar: calendar).includes($0) }
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
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 27, height: 34)
        }
        .buttonStyle(.plain)
    }
}

private struct WatchFlowContextPicker: View {
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
            todos.filter { TodayTodoFilter(calendar: calendar).includes($0) }
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
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [Todo]

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
    }

    private var todayTodos: [Todo] {
        FlowDashboardTodoSorter().sorted(
            todos.filter { TodayTodoFilter(calendar: calendar).includes($0) }
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
    @Environment(\.calendar) private var calendar
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query private var todos: [Todo]
    @Query private var sessions: [FlowSession]
    @Query private var flowBreaks: [FlowBreak]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let snapshot = FlowDashboardBuilder(calendar: calendar).build(
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
        .navigationTitle(String(localized: "今日の統計"))
    }

    private var todayTodos: [Todo] {
        todos.filter { TodayTodoFilter(calendar: calendar).includes($0) }
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
