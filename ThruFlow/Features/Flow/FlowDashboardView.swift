//
//  FlowDashboardView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/12.
//

import SwiftData
import SwiftUI

struct FlowDashboardView: View {
    private static let topPanelHeight: CGFloat = 410

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Direction.name, order: .forward) private var directions: [Direction]
    @Query(sort: \Todo.sortIndex, order: .forward) private var todos: [Todo]
    @Query(sort: \FlowSession.startedAt, order: .forward) private var sessions: [FlowSession]

    @State private var inspectedSession: FlowSession?
    @State private var hoveredTimelineSegmentID: UUID?
    @State private var selectedTimelineSegmentID: UUID?
    @State private var editingTodo: Todo?
    @State private var showsQuickComposer = false

    private let builder = FlowDashboardBuilder()
    private let todayFilter = TodayTodoFilter()
    private let requiredPlanner = RequiredTodoPlanner()
    private let progressCalculator = TodoProgressCalculator()
    private let historyEditor = FlowHistoryEditor()

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
                        .frame(height: Self.topPanelHeight)

                    FlowMiniPlayerView(style: .dashboard)
                        .frame(width: 310, height: Self.topPanelHeight)
                }

                GridRow(alignment: .top) {
                    taskColumns
                    statisticsPanel(snapshot: snapshot)
                        .frame(width: 310)
                        .frame(maxHeight: .infinity)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        .frame(minHeight: 185, idealHeight: 200, maxHeight: 215)
        .background(modeSurfaceTint)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func timelineSurface(snapshot: FlowDashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日のタイムライン")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            GeometryReader { proxy in
                let selectedSegment = snapshot.segments.first { $0.id == selectedTimelineSegmentID }
                let anchorPoint = timelineAnchorPoint(for: selectedSegment, totalWidth: proxy.size.width)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.07))
                        .frame(height: 16)

                    ForEach(snapshot.segments) { segment in
                        let width = segmentWidth(segment, totalWidth: proxy.size.width)
                        let centerX = proxy.size.width * segment.startFraction + (width / 2)

                        Button {
                            selectedTimelineSegmentID = segment.id
                        } label: {
                            ZStack {
                                Color.clear

                                Capsule()
                                    .fill(Color(hex: segment.colorHex))
                                    .frame(
                                        width: width,
                                        height: segment.isActive ? 18 : 12
                                    )
                            }
                            .frame(width: max(width, 14), height: 20)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .position(x: centerX, y: proxy.size.height / 2)
                        .zIndex(hoveredTimelineSegmentID == segment.id ? 2 : 1)
                        .accessibilityLabel("\(segment.taskTitle)、\(focusText(segment.focusSeconds))")
                    }

                    if let hoveredSegment = snapshot.segments.first(where: { $0.id == hoveredTimelineSegmentID }),
                       selectedTimelineSegmentID == nil {
                        TimelineSegmentHoverCard(segment: hoveredSegment)
                            .position(
                                x: timelineCardX(for: hoveredSegment, totalWidth: proxy.size.width),
                                y: -24
                            )
                            .allowsHitTesting(false)
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
                            .zIndex(3)
                    }

                }
                .frame(maxHeight: .infinity)
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        hoveredTimelineSegmentID = timelineSegment(
                            at: location.x,
                            segments: snapshot.segments,
                            totalWidth: proxy.size.width
                        )?.id
                    case .ended:
                        hoveredTimelineSegmentID = nil
                    }
                }
                .popover(
                    isPresented: timelinePopoverBinding,
                    attachmentAnchor: .point(anchorPoint),
                    arrowEdge: .bottom
                ) {
                    if let selectedSegment {
                        TimelineSegmentPopover(
                            segment: selectedSegment,
                            onDelete: selectedSegment.isActive ? nil : {
                                deleteTimelineSegment(selectedSegment)
                            },
                            onOpenHistory: selectedSegment.isActive ? nil : {
                                selectedTimelineSegmentID = nil
                                inspectedSession = selectedSegment.session
                            }
                        )
                    }
                }
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
                onOpen: { editingTodo = $0 },
                addControl: AnyView(dashboardAddButton)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private var activeDirections: [Direction] {
        directions.filter { !$0.isArchived }
    }

    private var dashboardAddButton: some View {
        Button {
            showsQuickComposer = true
        } label: {
            Image(systemName: "plus")
        }
        .buttonStyle(.plain)
        .help("タスクを追加")
        .accessibilityLabel("タスクを追加")
        .popover(isPresented: $showsQuickComposer, arrowEdge: .top) {
            QuickTodoCreationPopover(directions: activeDirections)
        }
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

    private var timelinePopoverBinding: Binding<Bool> {
        Binding(
            get: { selectedTimelineSegmentID != nil },
            set: { isPresented in
                if !isPresented {
                    selectedTimelineSegmentID = nil
                }
            }
        )
    }

    private func timelineCardX(for segment: FlowDashboardSegment, totalWidth: CGFloat) -> CGFloat {
        let width = segmentWidth(segment, totalWidth: totalWidth)
        let center = totalWidth * segment.startFraction + (width / 2)
        return min(max(center, 95), max(95, totalWidth - 95))
    }

    private func timelineAnchorPoint(
        for segment: FlowDashboardSegment?,
        totalWidth: CGFloat
    ) -> UnitPoint {
        guard let segment, totalWidth > 0 else { return .center }
        let width = segmentWidth(segment, totalWidth: totalWidth)
        let center = totalWidth * segment.startFraction + (width / 2)
        return UnitPoint(x: min(max(center / totalWidth, 0), 1), y: 0.5)
    }

    private func timelineSegment(
        at x: CGFloat,
        segments: [FlowDashboardSegment],
        totalWidth: CGFloat
    ) -> FlowDashboardSegment? {
        segments
            .compactMap { segment -> (segment: FlowDashboardSegment, distance: CGFloat)? in
                let width = max(segmentWidth(segment, totalWidth: totalWidth), 14)
                let center = totalWidth * CGFloat(segment.startFraction)
                    + (segmentWidth(segment, totalWidth: totalWidth) / 2)
                let distance = abs(x - center)
                guard distance <= width / 2 else { return nil }
                return (segment, distance)
            }
            .min { $0.distance < $1.distance }?
            .segment
    }

    private func deleteTimelineSegment(_ segment: FlowDashboardSegment) {
        selectedTimelineSegmentID = nil

        if let storedSegment = segment.storedSegment {
            historyEditor.delete(
                segment: storedSegment,
                from: segment.session,
                modelContext: modelContext
            )
        } else {
            historyEditor.delete(session: segment.session, modelContext: modelContext)
        }

        try? modelContext.save()
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

private struct TimelineSegmentHoverCard: View {
    let segment: FlowDashboardSegment

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(segment.symbol) \(segment.taskTitle)")
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            Text("\(TimelineSegmentFormat.interval(segment)) · \(TimelineSegmentFormat.duration(segment.focusSeconds))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(width: 190, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(Color.primary.opacity(0.12))
        }
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
    }
}

private struct TimelineSegmentPopover: View {
    let segment: FlowDashboardSegment
    let onDelete: (() -> Void)?
    let onOpenHistory: (() -> Void)?

    @State private var showsDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(segment.symbol)
                    .font(.title2)
                    .frame(width: 42, height: 42)
                    .background(Color(hex: segment.colorHex).opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(segment.taskTitle)
                        .font(.headline)
                    Text(segment.directionName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if segment.isActive {
                    Text("実行中")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(hex: segment.colorHex))
                } else if onDelete != nil {
                    Button {
                        showsDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.callout.weight(.semibold))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .help("この区間を削除")
                    .accessibilityLabel("このFlow区間を削除")
                }
            }

            Divider()

            segmentDetail("時間", value: TimelineSegmentFormat.interval(segment), systemImage: "clock")
            segmentDetail("集中", value: TimelineSegmentFormat.duration(segment.focusSeconds), systemImage: "timer")
            segmentDetail("Flow", value: segment.session.mode.displayName, systemImage: "waveform.path")

            if let onOpenHistory {
                Button(action: onOpenHistory) {
                    Label("Flow履歴を開く", systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: segment.colorHex))
            }
        }
        .padding(16)
        .frame(width: 290)
        .confirmationDialog(
            "このFlow区間を削除しますか？",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                onDelete?()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この区間の集中時間がタスクと方向の進捗から差し引かれます。")
        }
    }

    private func segmentDetail(_ title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout.weight(.medium))
                .monospacedDigit()
        }
    }
}

private enum TimelineSegmentFormat {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H:mm"
        return formatter
    }()

    static func interval(_ segment: FlowDashboardSegment) -> String {
        "\(timeFormatter.string(from: segment.startedAt))–\(timeFormatter.string(from: segment.endedAt))"
    }

    static func duration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return remainingSeconds == 0 ? "\(minutes)分" : "\(minutes)分\(remainingSeconds)秒"
    }
}

private struct DashboardTodoColumn: View {
    let title: String
    let systemImage: String
    let todos: [Todo]
    let progressText: (Todo) -> String
    let onToggle: (Todo) -> Void
    let onOpen: (Todo) -> Void
    var addControl: AnyView?

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

                if let addControl {
                    addControl
                }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self, FlowSegment.self], inMemory: true)
}
