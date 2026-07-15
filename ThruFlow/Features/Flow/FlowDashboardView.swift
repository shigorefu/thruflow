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

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Direction.name, order: .forward) private var directions: [Direction]
    @Query(sort: \Todo.sortIndex, order: .forward) private var todos: [Todo]
    @Query(sort: \FlowSession.startedAt, order: .forward) private var sessions: [FlowSession]
    @Query(sort: \FlowBreak.startedAt, order: .forward) private var flowBreaks: [FlowBreak]

    @State private var inspectedSession: FlowSession?
    @State private var hoveredTimelineItem: TimelineItem?
    @State private var selectedTimelineItem: TimelineItem?
    @State private var editingTodo: Todo?
    @State private var showsQuickComposer = false

    private let builder = FlowDashboardBuilder()
    private let todayFilter = TodayTodoFilter()
    private let requiredPlanner = RequiredTodoPlanner()
    private let progressCalculator = TodoProgressCalculator()
    private let historyEditor = FlowHistoryEditor()
    private let breakEditor = FlowBreakEditor()
    private let todoSorter = FlowDashboardTodoSorter()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let snapshot = snapshot(now: timeline.date)

            GeometryReader { viewport in
                ScrollView {
                    dashboardLayout(
                        snapshot: snapshot,
                        availableHeight: max(0, viewport.size.height - 40),
                        now: timeline.date
                    )
                    .frame(maxWidth: 1320)
                    .padding(20)
                    .frame(maxWidth: .infinity)
                }
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
            breaks: flowBreaks,
            activeSessionID: activeFlowStore.activeSession?.id,
            activeFocusSeconds: activeFlowStore.actualFocusSeconds(now: now)
        )
    }

    private func dashboardLayout(
        snapshot: FlowDashboardSnapshot,
        availableHeight: CGFloat,
        now: Date
    ) -> some View {
        let lowerPanelHeight = max(280, availableHeight - Self.topPanelHeight - 16)

        return ViewThatFits(in: .horizontal) {
            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                GridRow(alignment: .top) {
                    flowStage(snapshot: snapshot, now: now)
                        .frame(minWidth: 560, maxWidth: .infinity)
                        .frame(height: Self.topPanelHeight)

                    FlowMiniPlayerView(style: .dashboard)
                        .frame(width: 310, height: Self.topPanelHeight)
                }

                GridRow(alignment: .top) {
                    taskColumns
                        .frame(height: lowerPanelHeight)
                    statisticsPanel(snapshot: snapshot)
                        .frame(width: 310)
                        .frame(height: lowerPanelHeight)
                }
            }
            .frame(minWidth: 900)

            VStack(spacing: 16) {
                FlowMiniPlayerView(style: .dashboard)
                    .frame(maxWidth: .infinity)
                    .frame(height: 360)

                flowStage(snapshot: snapshot, now: now)
                    .frame(height: 340)

                taskColumns
                statisticsPanel(snapshot: snapshot)
            }
        }
    }

    private func flowStage(snapshot: FlowDashboardSnapshot, now: Date) -> some View {
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
            timelineSurface(snapshot: snapshot, now: now)
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

    private func timelineSurface(snapshot: FlowDashboardSnapshot, now: Date) -> some View {
        let range = FlowTimelineRange(
            date: now,
            segments: snapshot.segments,
            breaks: snapshot.breaks
        )

        return VStack(alignment: .leading, spacing: 8) {
            Text("今日のタイムライン")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            GeometryReader { proxy in
                let selectedSegment = snapshot.segments.first { selectedTimelineItem == .segment($0.id) }
                let selectedBreak = snapshot.breaks.first { selectedTimelineItem == .flowBreak($0.id) }
                let anchorPoint = timelineAnchorPoint(
                    from: selectedSegment?.startedAt ?? selectedBreak?.startedAt,
                    to: selectedSegment?.endedAt ?? selectedBreak?.endedAt,
                    range: range,
                    totalWidth: proxy.size.width
                )

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(timelineTrackColor)
                        .frame(height: 18)
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.primary.opacity(0.06))
                        }

                    ForEach(snapshot.seriesSpans) { span in
                        let width = intervalWidth(
                            from: span.startedAt,
                            to: span.endedAt,
                            range: range,
                            totalWidth: proxy.size.width,
                            minimumWidth: 12
                        )

                        Capsule()
                            .fill(Color.secondary.opacity(0.42))
                            .frame(width: width, height: 18)
                            .position(
                                x: intervalCenter(
                                    from: span.startedAt,
                                    to: span.endedAt,
                                    range: range,
                                    totalWidth: proxy.size.width
                                ),
                                y: proxy.size.height / 2
                            )
                            .allowsHitTesting(false)
                    }

                    ForEach(timelineSessionGroups(snapshot.segments)) { group in
                        let width = intervalWidth(
                            from: group.startedAt,
                            to: group.endedAt,
                            range: range,
                            totalWidth: proxy.size.width,
                            minimumWidth: 5
                        )
                        let height: CGFloat = 18

                        ZStack(alignment: .leading) {
                            ForEach(group.segments) { segment in
                                let segmentStart = max(0, segment.startedAt.timeIntervalSince(group.startedAt))
                                let segmentDuration = max(1, segment.endedAt.timeIntervalSince(segment.startedAt))
                                let groupDuration = max(1, group.endedAt.timeIntervalSince(group.startedAt))

                                Rectangle()
                                    .fill(Color(hex: segment.colorHex))
                                    .frame(
                                        width: max(1, width * segmentDuration / groupDuration),
                                        height: height
                                    )
                                    .offset(x: width * segmentStart / groupDuration)
                            }
                        }
                        .frame(width: width, height: height, alignment: .leading)
                        .clipShape(RoundedRectangle(cornerRadius: height / 2))
                        .shadow(
                            color: Color(hex: group.segments.first?.colorHex ?? "#8E8E93")
                                .opacity(group.isActive ? 0.55 : 0.40),
                            radius: group.isActive ? 5 : 4
                        )
                        .position(
                            x: intervalCenter(
                                from: group.startedAt,
                                to: group.endedAt,
                                range: range,
                                totalWidth: proxy.size.width
                            ),
                            y: proxy.size.height / 2
                        )
                        .allowsHitTesting(false)
                    }

                    ForEach(snapshot.breaks) { flowBreak in
                        let width = intervalWidth(
                            from: flowBreak.startedAt,
                            to: flowBreak.endedAt,
                            range: range,
                            totalWidth: proxy.size.width,
                            minimumWidth: 5
                        )

                        Button {
                            guard !flowBreak.isActive else { return }
                            selectedTimelineItem = .flowBreak(flowBreak.id)
                        } label: {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    hoveredTimelineItem == .flowBreak(flowBreak.id)
                                        ? Color.white.opacity(0.13)
                                        : Color.white.opacity(0.001)
                                )
                                .frame(width: max(width, 10), height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .position(
                            x: intervalCenter(
                                from: flowBreak.startedAt,
                                to: flowBreak.endedAt,
                                range: range,
                                totalWidth: proxy.size.width
                            ),
                            y: proxy.size.height / 2
                        )
                        .zIndex(hoveredTimelineItem == .flowBreak(flowBreak.id) ? 2 : 1)
                        .help(breakHelpText(flowBreak))
                        .accessibilityLabel(breakHelpText(flowBreak))
                    }

                    ForEach(snapshot.segments) { segment in
                        let width = segmentWidth(segment, range: range, totalWidth: proxy.size.width)
                        let centerX = intervalCenter(
                            from: segment.startedAt,
                            to: segment.endedAt,
                            range: range,
                            totalWidth: proxy.size.width
                        )

                        Button {
                            selectedTimelineItem = .segment(segment.id)
                        } label: {
                            Color.clear
                            .frame(width: max(width, 14), height: 20)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .position(x: centerX, y: proxy.size.height / 2)
                        .zIndex(hoveredTimelineItem == .segment(segment.id) ? 2 : 1)
                        .accessibilityLabel("\(segment.taskTitle)、\(focusText(segment.focusSeconds))")
                    }

                    if let hoveredSegment = snapshot.segments.first(where: {
                        hoveredTimelineItem == .segment($0.id)
                    }), selectedTimelineItem == nil {
                        TimelineSegmentHoverCard(segment: hoveredSegment)
                            .position(
                                x: timelineCardX(
                                    from: hoveredSegment.startedAt,
                                    to: hoveredSegment.endedAt,
                                    range: range,
                                    totalWidth: proxy.size.width
                                ),
                                y: -24
                            )
                            .allowsHitTesting(false)
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
                            .zIndex(3)
                    }

                    if let hoveredBreak = snapshot.breaks.first(where: {
                        hoveredTimelineItem == .flowBreak($0.id)
                    }), selectedTimelineItem == nil {
                        TimelineBreakHoverCard(flowBreak: hoveredBreak)
                            .position(
                                x: timelineCardX(
                                    from: hoveredBreak.startedAt,
                                    to: hoveredBreak.endedAt,
                                    range: range,
                                    totalWidth: proxy.size.width
                                ),
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
                        hoveredTimelineItem = timelineItem(
                            at: location.x,
                            snapshot: snapshot,
                            range: range,
                            totalWidth: proxy.size.width
                        )
                    case .ended:
                        hoveredTimelineItem = nil
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
                                selectedTimelineItem = nil
                                inspectedSession = selectedSegment.session
                            }
                        )
                    } else if let selectedBreak {
                        TimelineBreakPopover(
                            flowBreak: selectedBreak,
                            onSave: { minutes in
                                let result = try breakEditor.updateDuration(
                                    of: selectedBreak.storedBreak,
                                    minutes: minutes,
                                    modelContext: modelContext,
                                    protectedSessionID: activeFlowStore.activeSession?.id
                                )
                                selectedTimelineItem = nil
                                return result
                            }
                        )
                    }
                }
            }
            .frame(height: 24)

            HStack {
                let dates = range.labelDates()
                ForEach(Array(dates.enumerated()), id: \.offset) { index, date in
                    Text(timelineLabel(date))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if index != dates.indices.last { Spacer() }
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
                showsPriority: true,
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

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 12)

                    ForEach(completionSlices) { slice in
                        Circle()
                            .trim(from: slice.start, to: slice.end)
                            .stroke(
                                Color(hex: slice.colorHex),
                                style: StrokeStyle(lineWidth: 12, lineCap: .butt)
                            )
                            .rotationEffect(.degrees(-90))
                    }

                    Text("\(Int((completionRate * 100).rounded()))%")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }
                .frame(width: 112, height: 112)
                .animation(.easeInOut(duration: 0.25), value: completedTodoCount)

                Text("今日の達成  \(completedTodoCount) / \(todayTodos.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)

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
        todoSorter.sorted(todos.filter { todayFilter.includes($0) })
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

    private var completionSlices: [DashboardCompletionSlice] {
        guard !todayTodos.isEmpty else { return [] }

        let completedGroups = Dictionary(
            grouping: todayTodos.filter(\.isCompleted)
        ) { todo in
            todo.direction?.id.uuidString ?? "other"
        }
        .sorted { $0.key < $1.key }

        var cursor = 0.0
        return completedGroups.map { key, todos in
            let fraction = Double(todos.count) / Double(todayTodos.count)
            let slice = DashboardCompletionSlice(
                id: key,
                start: cursor,
                end: cursor + fraction,
                colorHex: todos.first?.direction?.colorHex ?? "#8E8E93"
            )
            cursor += fraction
            return slice
        }
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
        var hasChanges = false

        for (offset, direction) in activeDirections.enumerated() {
            guard direction.type == .habit,
                  requiredPlanner.shouldAppearToday(direction, on: now) else {
                continue
            }

            if let pendingTodo = requiredPlanner.pendingWeeklyTodoToRollForward(
                for: direction,
                in: knownTodos,
                on: now
            ) {
                pendingTodo.reschedule(to: Calendar.current.startOfDay(for: now), now: now)
                hasChanges = true
                continue
            }

            guard let todo = requiredPlanner.makeRequiredTodo(
                    for: direction,
                    existingTodos: knownTodos,
                    on: now,
                    sortIndex: minimumSortIndex - offset - 1
                  ) else {
                continue
            }

            modelContext.insert(todo)
            knownTodos.append(todo)
            hasChanges = true
        }

        if hasChanges {
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

    private var timelineTrackColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.46 : 0.12)
    }

    private func timelineSessionGroups(_ segments: [FlowDashboardSegment]) -> [TimelineSessionGroup] {
        Dictionary(grouping: segments, by: { $0.session.id })
            .values
            .compactMap { values in
                guard let first = values.min(by: { $0.startedAt < $1.startedAt }),
                      let last = values.max(by: { $0.endedAt < $1.endedAt }) else {
                    return nil
                }
                return TimelineSessionGroup(
                    id: first.session.id,
                    startedAt: first.startedAt,
                    endedAt: last.endedAt,
                    segments: values.sorted { $0.startedAt < $1.startedAt },
                    isActive: values.contains(where: \.isActive)
                )
            }
            .sorted { $0.startedAt < $1.startedAt }
    }

    private func segmentWidth(
        _ segment: FlowDashboardSegment,
        range: FlowTimelineRange,
        totalWidth: CGFloat
    ) -> CGFloat {
        intervalWidth(
            from: segment.startedAt,
            to: segment.endedAt,
            range: range,
            totalWidth: totalWidth,
            minimumWidth: 6
        )
    }

    private func intervalWidth(
        from start: Date,
        to end: Date,
        range: FlowTimelineRange,
        totalWidth: CGFloat,
        minimumWidth: CGFloat
    ) -> CGFloat {
        max(minimumWidth, totalWidth * (range.fraction(for: end) - range.fraction(for: start)))
    }

    private func intervalCenter(
        from start: Date,
        to end: Date,
        range: FlowTimelineRange,
        totalWidth: CGFloat
    ) -> CGFloat {
        let visibleStart = totalWidth * range.fraction(for: start)
        let visibleEnd = totalWidth * range.fraction(for: end)
        return visibleStart + ((visibleEnd - visibleStart) / 2)
    }

    private func breakHelpText(_ flowBreak: FlowDashboardBreak) -> String {
        let name = flowBreak.isLongBreak ? "Long Break" : "休憩"
        return "☕️ \(name) \(TimelineSegmentFormat.duration(flowBreak.durationSeconds))"
    }

    private var timelinePopoverBinding: Binding<Bool> {
        Binding(
            get: { selectedTimelineItem != nil },
            set: { isPresented in
                if !isPresented {
                    selectedTimelineItem = nil
                }
            }
        )
    }

    private func timelineCardX(
        from start: Date,
        to end: Date,
        range: FlowTimelineRange,
        totalWidth: CGFloat
    ) -> CGFloat {
        let center = intervalCenter(from: start, to: end, range: range, totalWidth: totalWidth)
        return min(max(center, 95), max(95, totalWidth - 95))
    }

    private func timelineAnchorPoint(
        from start: Date?,
        to end: Date?,
        range: FlowTimelineRange,
        totalWidth: CGFloat
    ) -> UnitPoint {
        guard let start, let end, totalWidth > 0 else { return .center }
        let center = intervalCenter(from: start, to: end, range: range, totalWidth: totalWidth)
        return UnitPoint(x: min(max(center / totalWidth, 0), 1), y: 0.5)
    }

    private func timelineItem(
        at x: CGFloat,
        snapshot: FlowDashboardSnapshot,
        range: FlowTimelineRange,
        totalWidth: CGFloat
    ) -> TimelineItem? {
        let segmentCandidates = snapshot.segments.compactMap { segment -> (TimelineItem, CGFloat)? in
                let segmentVisualWidth = segmentWidth(segment, range: range, totalWidth: totalWidth)
                let width = max(segmentVisualWidth, 14)
                let center = intervalCenter(
                    from: segment.startedAt,
                    to: segment.endedAt,
                    range: range,
                    totalWidth: totalWidth
                )
                let distance = abs(x - center)
                guard distance <= width / 2 else { return nil }
                return (.segment(segment.id), distance)
            }
        let breakCandidates = snapshot.breaks.compactMap { flowBreak -> (TimelineItem, CGFloat)? in
            let visualWidth = intervalWidth(
                from: flowBreak.startedAt,
                to: flowBreak.endedAt,
                range: range,
                totalWidth: totalWidth,
                minimumWidth: 10
            )
            let width = max(visualWidth, 14)
            let center = intervalCenter(
                from: flowBreak.startedAt,
                to: flowBreak.endedAt,
                range: range,
                totalWidth: totalWidth
            )
            let distance = abs(x - center)
            guard distance <= width / 2 else { return nil }
            return (.flowBreak(flowBreak.id), distance)
        }

        return (segmentCandidates + breakCandidates)
            .min { $0.1 < $1.1 }?
            .0
    }

    private func timelineLabel(_ date: Date) -> String {
        return date.formatted(.dateTime.hour().minute())
    }

    private func deleteTimelineSegment(_ segment: FlowDashboardSegment) {
        selectedTimelineItem = nil

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

private enum TimelineItem: Equatable {
    case segment(UUID)
    case flowBreak(UUID)
}

private struct TimelineSessionGroup: Identifiable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let segments: [FlowDashboardSegment]
    let isActive: Bool
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

private struct TimelineBreakHoverCard: View {
    let flowBreak: FlowDashboardBreak

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(flowBreak.isLongBreak ? "Long Break" : "休憩", systemImage: "cup.and.saucer.fill")
                .font(.caption.weight(.semibold))

            Text("\(TimelineSegmentFormat.interval(from: flowBreak.startedAt, to: flowBreak.endedAt)) · \(TimelineSegmentFormat.duration(flowBreak.durationSeconds))")
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

private struct TimelineBreakPopover: View {
    let flowBreak: FlowDashboardBreak
    let onSave: (Int) throws -> FlowBreakEditResult

    @State private var minutes: Int
    @State private var errorText: String?

    init(
        flowBreak: FlowDashboardBreak,
        onSave: @escaping (Int) throws -> FlowBreakEditResult
    ) {
        self.flowBreak = flowBreak
        self.onSave = onSave
        _minutes = State(initialValue: max(1, Int(ceil(Double(flowBreak.durationSeconds) / 60))))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 42, height: 42)
                    .background(Color.gray.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(flowBreak.isLongBreak ? "Long Break" : "休憩")
                        .font(.headline)
                    Text("開始時刻は固定されます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Label("開始", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(TimelineSegmentFormat.time(flowBreak.startedAt))
                    .monospacedDigit()
            }

            HStack {
                Label("終了", systemImage: "clock.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(TimelineSegmentFormat.time(adjustedEndAt))
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                Text("休憩時間")
                    .font(.callout.weight(.medium))
                Spacer()
                TextField("分", value: $minutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 76)
                    .onSubmit(save)
                Text("分")
                    .foregroundStyle(.secondary)
            }

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: save) {
                Text("保存")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(minutes < FlowBreakEditor.minimumDurationMinutes || minutes > FlowBreakEditor.maximumDurationMinutes)
        }
        .padding(16)
        .frame(width: 290)
    }

    private var adjustedEndAt: Date {
        flowBreak.startedAt.addingTimeInterval(TimeInterval(max(0, minutes) * 60))
    }

    private func save() {
        do {
            _ = try onSave(minutes)
            errorText = nil
        } catch FlowBreakEditorError.activeFlowWouldMove {
            errorText = "実行中のFlowは移動できません。現在のFlowを終了してから編集してください。"
        } catch {
            errorText = "休憩時間を保存できませんでした。"
        }
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
        interval(from: segment.startedAt, to: segment.endedAt)
    }

    static func interval(from start: Date, to end: Date) -> String {
        "\(time(start))–\(time(end))"
    }

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func duration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return remainingSeconds == 0 ? "\(minutes)分" : "\(minutes)分\(remainingSeconds)秒"
    }
}

private struct DashboardCompletionSlice: Identifiable {
    let id: String
    let start: Double
    let end: Double
    let colorHex: String
}

private struct DashboardTodoColumn: View {
    let title: String
    let systemImage: String
    let todos: [Todo]
    var showsPriority = false
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
                            .font(todoTitleFont(todo))
                            .foregroundStyle(todoTitleColor(todo))
                            .strikethrough(todo.isCompleted)
                            .lineLimit(1)

                        Text(todoDetail(todo))
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

    private func todoTitleFont(_ todo: Todo) -> Font {
        todoTitleIsPlaceholder(todo)
            ? .subheadline.weight(.medium).italic()
            : .subheadline.weight(.medium)
    }

    private func todoTitleColor(_ todo: Todo) -> Color {
        if todoTitleIsPlaceholder(todo) {
            return .secondary.opacity(0.7)
        }
        return todo.isCompleted ? .secondary : .primary
    }

    private func todoTitleIsPlaceholder(_ todo: Todo) -> Bool {
        todo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func todoDetail(_ todo: Todo) -> String {
        guard showsPriority else { return progressText(todo) }
        return "\(priorityLabel(todo)) ・ \(progressText(todo))"
    }

    private func priorityLabel(_ todo: Todo) -> String {
        if todo.priority == .low, todo.isRoomIfPossible {
            return "余裕があれば"
        }
        return todo.priority.displayName
    }
}

#Preview {
    FlowDashboardView()
        .environmentObject(ActiveFlowStore())
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self], inMemory: true)
}
