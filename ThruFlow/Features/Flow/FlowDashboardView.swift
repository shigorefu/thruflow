//
//  FlowDashboardView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/12.
//

import SwiftData
import SwiftUI

struct FlowDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Direction.name, order: .forward) private var directions: [Direction]
    @Query(sort: \Todo.sortIndex, order: .forward) private var todos: [Todo]
    @Query(sort: \FlowSession.startedAt, order: .forward) private var sessions: [FlowSession]

    @State private var inspectedSession: FlowSession?
    @State private var editingTodo: Todo?

    private let builder = FlowDashboardBuilder()
    private let todayFilter = TodayTodoFilter()
    private let requiredPlanner = RequiredTodoPlanner()
    private let progressCalculator = TodoProgressCalculator()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let snapshot = snapshot(now: timeline.date)

            ScrollView {
                dashboardLayout(snapshot: snapshot)
                .frame(maxWidth: 1320)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .background(modeBackgroundTint.ignoresSafeArea())
        }
        .navigationTitle("Flow")
        .sheet(item: $inspectedSession) { session in
            FlowHistoryInspectorView(session: session)
        }
        .sheet(item: $editingTodo) { todo in
            TodoFormView(mode: .edit(todo))
        }
        .onAppear {
            ensureTodayHabits()
        }
        .onChange(of: directions.map(\.updatedAt)) { _, _ in
            ensureTodayHabits()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            ensureTodayHabits()
        }
    }

    private func snapshot(now: Date) -> FlowDashboardSnapshot {
        builder.build(
            date: now,
            sessions: sessions,
            activeSessionID: activeFlowStore.activeSession?.id,
            activeFocusSeconds: activeFlowStore.actualFocusSeconds(now: now)
        )
    }

    private func dashboardLayout(snapshot: FlowDashboardSnapshot) -> some View {
        ViewThatFits(in: .horizontal) {
            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                GridRow(alignment: .top) {
                    flowStage(snapshot: snapshot)
                        .frame(minWidth: 560, maxWidth: .infinity)

                    FlowMiniPlayerView(style: .dashboard)
                        .frame(width: 310)
                }

                GridRow(alignment: .top) {
                    taskColumns
                    statisticsPanel(snapshot: snapshot)
                        .frame(width: 310)
                }
            }
            .frame(minWidth: 900)

            VStack(spacing: 16) {
                flowStage(snapshot: snapshot)
                FlowMiniPlayerView(style: .dashboard)
                taskColumns
                statisticsPanel(snapshot: snapshot)
            }
        }
    }

    private func flowStage(snapshot: FlowDashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("今日のFlow")
                        .font(.title2.weight(.semibold))
                    Text(dateText(snapshot.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                metric(value: focusText(snapshot.totalFocusSeconds), label: "集中時間")
                metric(value: blockText(snapshot.blocks), label: "ブロック")
                metric(value: "\(snapshot.flowCount)", label: "Flow")
            }

            streamSurface(snapshot: snapshot)
            timelineSurface(snapshot: snapshot)
        }
        .padding(18)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.headline.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func streamSurface(snapshot: FlowDashboardSnapshot) -> some View {
        ZStack(alignment: .bottomLeading) {
            FlowStreamView(
                blocks: snapshot.blocks,
                flowCount: snapshot.flowCount,
                palette: snapshot.palette,
                isActive: activeFlowStore.phase == .focusing,
                mode: activeFlowStore.selectedMode
            )

            if snapshot.totalFocusSeconds == 0 {
                Text("Flowを始めると、今日の流れがここから育ちます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
        }
        .frame(minHeight: 300, idealHeight: 360, maxHeight: 420)
        .background(modeSurfaceTint)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func timelineSurface(snapshot: FlowDashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日のタイムライン")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.07))
                        .frame(height: 16)

                    ForEach(snapshot.segments) { segment in
                        Button {
                            guard !segment.isActive else { return }
                            inspectedSession = segment.session
                        } label: {
                            Capsule()
                                .fill(Color(hex: segment.colorHex))
                                .frame(
                                    width: segmentWidth(segment, totalWidth: proxy.size.width),
                                    height: segment.isActive ? 18 : 12
                                )
                        }
                        .buttonStyle(.plain)
                        .offset(x: proxy.size.width * segment.startFraction)
                        .help("\(segment.symbol) \(segment.taskTitle) · \(focusText(segment.focusSeconds))")
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 20)

            HStack {
                ForEach(["0:00", "6:00", "12:00", "18:00", "24:00"], id: \.self) { label in
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if label != "24:00" { Spacer() }
                }
            }
        }
    }

    private var taskColumns: some View {
        HStack(alignment: .top, spacing: 14) {
            DashboardTodoColumn(
                title: "タスク",
                systemImage: "checklist",
                todos: standardTodos,
                progressText: progressText,
                onToggle: toggleTodo,
                onOpen: { editingTodo = $0 }
            )

            DashboardTodoColumn(
                title: "習慣",
                systemImage: "repeat",
                todos: habitTodos,
                progressText: progressText,
                onToggle: toggleTodo,
                onOpen: { editingTodo = $0 }
            )

            if !niceTodos.isEmpty {
                DashboardTodoColumn(
                    title: "ナイス",
                    systemImage: "sparkles",
                    todos: niceTodos,
                    progressText: progressText,
                    onToggle: toggleTodo,
                    onOpen: { editingTodo = $0 }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func statisticsPanel(snapshot: FlowDashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("統計", systemImage: "chart.bar.xaxis")
                .font(.headline)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: completionRate)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int((completionRate * 100).rounded()))%")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                }
                .frame(width: 66, height: 66)

                VStack(alignment: .leading, spacing: 3) {
                    Text("今日の達成")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(completedTodoCount) / \(todayTodos.count)")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                ForEach(snapshot.directionSummaries.prefix(4)) { summary in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("\(summary.symbol) \(summary.name)")
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(focusText(summary.focusSeconds))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        GeometryReader { proxy in
                            Capsule()
                                .fill(Color.primary.opacity(0.07))
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(hex: summary.colorHex))
                                        .frame(width: proxy.size.width * directionRatio(summary, snapshot: snapshot))
                                }
                        }
                        .frame(height: 6)
                    }
                }

                if snapshot.directionSummaries.isEmpty {
                    Text("Flowを記録すると方向別の時間が表示されます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }

    private var todayTodos: [Todo] {
        todos
            .filter { todayFilter.includes($0) }
            .sorted {
                if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
                return $0.sortIndex < $1.sortIndex
            }
    }

    private var standardTodos: [Todo] {
        todayTodos.filter { ($0.direction?.type ?? .neutral) == .neutral }
    }

    private var habitTodos: [Todo] {
        todayTodos.filter { $0.direction?.type == .habit }
    }

    private var niceTodos: [Todo] {
        todayTodos.filter { $0.direction?.type == .nice }
    }

    private var completedTodoCount: Int {
        todayTodos.filter(\.isCompleted).count
    }

    private var completionRate: Double {
        guard !todayTodos.isEmpty else { return 0 }
        return Double(completedTodoCount) / Double(todayTodos.count)
    }

    private var modeBackgroundTint: Color {
        switch activeFlowStore.selectedMode {
        case .twelveThree, .adaptive:
            Color.orange.opacity(0.025)
        case .twentyFiveFive:
            Color.blue.opacity(0.025)
        case .fiftyTen:
            Color.indigo.opacity(0.035)
        }
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

    private func progressText(_ todo: Todo) -> String {
        progressCalculator.summary(
            measurement: todo.measurement,
            plannedAmount: todo.plannedAmount,
            actualProgress: todo.actualProgress,
            focusDurationSeconds: todo.focusDurationSeconds
        )
    }

    private func toggleTodo(_ todo: Todo) {
        todo.setCompleted(!todo.isCompleted)
        try? modelContext.save()
    }

    private func ensureTodayHabits(now: Date = .now) {
        let activeDirections = directions.filter { !$0.isArchived }
        var knownTodos = todos
        let minimumSortIndex = todos.map(\.sortIndex).min() ?? 0
        var inserted = false

        for (offset, direction) in activeDirections.enumerated() {
            guard direction.type == .habit,
                  requiredPlanner.shouldAppearToday(direction, on: now),
                  let todo = requiredPlanner.makeRequiredTodo(
                    for: direction,
                    existingTodos: knownTodos,
                    on: now,
                    sortIndex: minimumSortIndex - offset - 1
                  ) else {
                continue
            }

            modelContext.insert(todo)
            knownTodos.append(todo)
            inserted = true
        }

        if inserted {
            try? modelContext.save()
        }
    }

    private func directionRatio(
        _ summary: FlowDashboardDirectionSummary,
        snapshot: FlowDashboardSnapshot
    ) -> Double {
        guard let maximum = snapshot.directionSummaries.map(\.focusSeconds).max(), maximum > 0 else { return 0 }
        return Double(summary.focusSeconds) / Double(maximum)
    }

    private func segmentWidth(_ segment: FlowDashboardSegment, totalWidth: CGFloat) -> CGFloat {
        max(6, totalWidth * (segment.endFraction - segment.startFraction))
    }

    private func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "ja_JP")).month(.wide).day().weekday(.wide))
    }

    private func focusText(_ seconds: Int) -> String {
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        return hours > 0 ? "\(hours)時間\(minutes)分" : "\(minutes)分"
    }

    private func blockText(_ blocks: Double) -> String {
        let rounded = (blocks * 10).rounded() / 10
        return rounded == rounded.rounded() ? "\(Int(rounded))" : String(format: "%.1f", rounded)
    }
}

private struct DashboardTodoColumn: View {
    let title: String
    let systemImage: String
    let todos: [Todo]
    let progressText: (Todo) -> String
    let onToggle: (Todo) -> Void
    let onOpen: (Todo) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                Spacer()
                Text("\(todos.filter { !$0.isCompleted }.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if todos.isEmpty {
                Text("今日の項目はありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 70, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    ForEach(todos.prefix(6)) { todo in
                        todoRow(todo)

                        if todo.id != todos.prefix(6).last?.id {
                            Divider().opacity(0.5)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }

    private func todoRow(_ todo: Todo) -> some View {
        HStack(spacing: 10) {
            TodoProgressControl(todo: todo) {
                onToggle(todo)
            }

            Button {
                onOpen(todo)
            } label: {
                HStack(spacing: 8) {
                    Text(todo.direction?.symbolName ?? "📥")

                    VStack(alignment: .leading, spacing: 2) {
                        Text(TodoDisplay.title(for: todo))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                            .strikethrough(todo.isCompleted)
                            .lineLimit(1)

                        Text(progressText(todo))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 9)
    }
}

#Preview {
    FlowDashboardView()
        .environmentObject(ActiveFlowStore())
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self], inMemory: true)
}
