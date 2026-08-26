//
//  FlowDashboardView.swift
//  ThruFlow
//
//

import SwiftData
import SwiftUI

struct FlowDashboardView: View {
    private static let topPanelHeight: CGFloat = 410
    private static let maximumDashboardWidth: CGFloat = 1320
    private static let minimumFlowStageWidth: CGFloat = 340
    private static let widePlayerWidth: CGFloat = 320
    private static let panelSpacing: CGFloat = 16
    private static let wideLayoutMinimumWidth =
        minimumFlowStageWidth + widePlayerWidth + panelSpacing

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    let directions: [Direction]
    @Query private var todos: [Todo]
    @Query private var sessions: [FlowSession]
    @Query private var flowBreaks: [FlowBreak]

    @State private var inspectedSegment: FlowDashboardSegment?
    @State private var hoveredTimelineItem: TimelineItem?
    @State private var selectedTimelineItem: TimelineItem?
    @State private var editingTodo: Todo?
    @State private var showsQuickComposer = false
    @State private var statisticsPage = DashboardStatisticsPage.distribution
    @State private var distributionMode = DashboardDistributionMode.task
    @State private var habitPreparationRevision = 0

    @Binding private var cachedSnapshot: FlowDashboardSnapshot?
    @Binding private var cachedTodoGroups: FlowDashboardTodoGroups?
    let isVisible: Bool

    private let progressCalculator = TodoProgressCalculator()
    private let historyEditor = FlowHistoryEditor()
    private let breakEditor = FlowBreakEditor()
    private var builder: FlowDashboardBuilder {
        FlowDashboardBuilder(calendar: calendar, dayBoundary: dayBoundary)
    }

    private var statisticsBuilder: DashboardStatisticsBuilder {
        DashboardStatisticsBuilder(calendar: calendar, dayBoundary: dayBoundary)
    }

    init(
        isVisible: Bool = true,
        directions: [Direction],
        cachedSnapshot: Binding<FlowDashboardSnapshot?>,
        cachedTodoGroups: Binding<FlowDashboardTodoGroups?>
    ) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -16, to: .now) ?? .distantPast
        let todoUpperBound = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .distantFuture
        let missingScheduledDate = Date.distantPast
        self.isVisible = isVisible
        self.directions = directions
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
    }

    var body: some View {
        dashboardContent
        .navigationTitle(isVisible ? String(localized: "Flow") : "")
        .sheet(item: $inspectedSegment) { segment in
            FlowHistoryInspectorView(
                session: segment.session,
                segment: segment.storedSegment
            )
        }
        .sheet(item: $editingTodo) { todo in
            TodoFormView(mode: .edit(todo))
        }
        .onChange(of: isVisible) { _, newValue in
            guard !newValue else { return }
            inspectedSegment = nil
            editingTodo = nil
            showsQuickComposer = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            habitPreparationRevision += 1
        }
        .task(id: habitPreparationID) {
            await prepareTodayHabitsAfterPresentation()
        }
        .task(id: snapshotRefreshID) {
            await refreshDashboardCache()
        }
        .task(id: todoGroupsRefreshID) {
            await refreshTodoGroupsCache()
        }
    }

    private var dashboardContent: some View {
        GeometryReader { viewport in
            let availableWidth = min(
                max(0, viewport.size.width - 40),
                Self.maximumDashboardWidth
            )
            let snapshot = cachedSnapshot ?? .empty()

            ScrollView {
                dashboardLayout(
                    snapshot: snapshot,
                    availableWidth: availableWidth,
                    availableHeight: max(0, viewport.size.height - 40)
                )
                .frame(width: availableWidth)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
        }
        .background(modeBackgroundTint.ignoresSafeArea())
    }

    private func makeSnapshot(now: Date) -> FlowDashboardSnapshot {
        let day = dayBoundary.day(containing: now, calendar: calendar)
        let interval = dayBoundary.interval(for: day, calendar: calendar)
        let daySessions = sessions.filter { interval.contains($0.startedAt) }
        let dayBreaks = flowBreaks.filter { interval.contains($0.startedAt) }

        return builder.build(
            date: now,
            sessions: daySessions,
            breaks: dayBreaks,
            activeSessionID: activeFlowStore.activeSession?.id,
            activeFocusSeconds: activeFlowStore.actualFocusSeconds(now: now),
            visualIdentityID: DailyFlowIdentity.resolve(from: directions)
        )
    }

    private var snapshotRefreshID: FlowDashboardRefreshID {
        FlowDashboardRefreshID(
            isVisible: isVisible,
            sessionCount: sessions.count,
            latestSessionUpdate: sessions.first?.updatedAt,
            breakCount: flowBreaks.count,
            latestBreakUpdate: flowBreaks.first?.updatedAt,
            directionCount: directions.count,
            latestDirectionUpdate: directions.first?.updatedAt,
            activeSessionID: activeFlowStore.activeSession?.id,
            phase: activeFlowStore.timerState?.phase.rawValue
        )
    }

    private var habitPreparationID: FlowDashboardHabitPreparationID {
        FlowDashboardHabitPreparationID(
            isVisible: isVisible,
            directionCount: directions.count,
            latestDirectionUpdate: directions.first?.updatedAt,
            todoCount: todos.count,
            latestTodoUpdate: todos.first?.updatedAt,
            revision: habitPreparationRevision
        )
    }

    private var todoGroupsRefreshID: FlowDashboardTodoRefreshID {
        FlowDashboardTodoRefreshID(
            isVisible: isVisible,
            todoCount: todos.count,
            latestTodoUpdate: todos.first?.updatedAt
        )
    }

    @MainActor
    private func prepareTodayHabitsAfterPresentation() async {
        guard isVisible else { return }
        try? await Task.sleep(for: .milliseconds(220))
        guard !Task.isCancelled, isVisible else { return }
        ensureTodayHabits()
    }

    @MainActor
    private func refreshDashboardCache() async {
        guard isVisible else { return }

        // Let navigation and the cached first frame finish before touching
        // SwiftData-backed models for a fresh dashboard projection.
        try? await Task.sleep(for: .milliseconds(cachedSnapshot == nil ? 300 : 450))
        guard !Task.isCancelled, isVisible else { return }

        cachedSnapshot = makeSnapshot(now: .now)

        while !Task.isCancelled, isVisible, activeFlowStore.timerState != nil {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, isVisible else { return }
            cachedSnapshot = makeSnapshot(now: .now)
        }
    }

    @MainActor
    private func refreshTodoGroupsCache() async {
        guard isVisible else { return }

        // Task cards are secondary dashboard content. Keep navigation responsive
        // by projecting the SwiftData archive only after the first frame.
        try? await Task.sleep(for: .milliseconds(cachedTodoGroups == nil ? 180 : 300))
        guard !Task.isCancelled, isVisible else { return }

        cachedTodoGroups = FlowDashboardTodoGroupBuilder(
            calendar: calendar,
            dayBoundary: dayBoundary
        ).build(from: todos)
    }

    private func dashboardLayout(
        snapshot: FlowDashboardSnapshot,
        availableWidth: CGFloat,
        availableHeight: CGFloat
    ) -> some View {
        let lowerPanelHeight = max(340, availableHeight - Self.topPanelHeight - Self.panelSpacing)
        let leftColumnWidth = max(
            0,
            availableWidth - Self.widePlayerWidth - Self.panelSpacing
        )

        return Group {
            if availableWidth >= Self.wideLayoutMinimumWidth {
                VStack(spacing: Self.panelSpacing) {
                    HStack(alignment: .top, spacing: Self.panelSpacing) {
                        flowStage(snapshot: snapshot)
                            .frame(width: leftColumnWidth)
                            .frame(height: Self.topPanelHeight)

                        FlowMiniPlayerView(style: .dashboard)
                            .frame(width: Self.widePlayerWidth, height: Self.topPanelHeight)
                    }

                    HStack(alignment: .top, spacing: Self.panelSpacing) {
                        taskColumns
                            .frame(width: leftColumnWidth)
                            .frame(height: lowerPanelHeight)
                        statisticsPanel(snapshot: snapshot)
                            .frame(
                                width: Self.widePlayerWidth,
                                height: lowerPanelHeight
                            )
                    }
                }
                .frame(width: availableWidth)
            } else {
                VStack(spacing: Self.panelSpacing) {
                    FlowMiniPlayerView(style: .dashboard)
                        .frame(maxWidth: .infinity)
                        .frame(height: 360)

                    flowStage(snapshot: snapshot)
                        .frame(height: 340)

                    taskColumns
                    statisticsPanel(snapshot: snapshot)
                        .frame(height: 340)
                }
            }
        }
    }

    private func flowStage(snapshot: FlowDashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "今日のFlow"))
                        .font(.title2.weight(.semibold))
                    Text(dateText(snapshot.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                metric(value: focusText(snapshot.totalFocusSeconds), label: String(localized: "集中時間"))
                metric(value: blockText(snapshot.blocks), label: String(localized: "ブロック"))
                metric(value: "\(snapshot.flowCount)", label: String(localized: "集中回数"))
            }

            streamSurface(snapshot: snapshot)
            if isVisible {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    timelineSurface(snapshot: snapshot, now: timeline.date)
                }
            } else {
                timelineSurface(snapshot: snapshot, now: .now)
            }
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
                paletteWeights: snapshot.paletteWeights,
                dailySeed: snapshot.dailyVisualSeed,
                isActive: activeFlowStore.phase == .focusing,
                mode: activeFlowStore.selectedMode,
                breakStyle: activeFlowStore.flowStreamBreakStyle,
                breakInteraction: activeFlowStore.flowBreakInteraction,
                isRenderingEnabled: isVisible
            )

            if snapshot.totalFocusSeconds == 0 {
                Text(String(localized: "Flowを始めると、今日の流れがここから育ちます"))
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
            Text(String(localized: "今日のタイムライン"))
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

                    ForEach(snapshot.sessionGroups) { group in
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
                        .accessibilityLabel(
                            String(localized: "\(segment.taskTitle), \(focusText(segment.focusSeconds))")
                        )
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
                                inspectedSegment = selectedSegment
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
                title: String(localized: "タスク"),
                systemImage: "checklist",
                todos: standardTodos,
                showsPriority: true,
                progressText: progressText,
                onToggle: toggleTodo,
                onOpen: { editingTodo = $0 },
                addControl: AnyView(dashboardAddButton)
            )
            DashboardTodoColumn(
                title: String(localized: "習慣一覧"),
                systemImage: "repeat",
                todos: habitTodos,
                progressText: progressText,
                onToggle: toggleTodo,
                onOpen: { editingTodo = $0 }
            )

            if !niceTodos.isEmpty {
                DashboardTodoColumn(
                    title: String(localized: "ナイス"),
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(String(localized: "統計"), systemImage: "chart.bar.xaxis")
                    .font(.headline)
                Spacer()
                HStack(spacing: 5) {
                    ForEach(DashboardStatisticsPage.allCases) { page in
                        Circle()
                            .fill(page == statisticsPage ? Color.accentColor : Color.secondary.opacity(0.25))
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.trailing, 4)
                Button { moveStatisticsPage(-1) } label: {
                    Image(systemName: "chevron.left")
                }
                Button { moveStatisticsPage(1) } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.plain)

            Text(statisticsPage.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Group {
                switch statisticsPage {
                case .distribution:
                    statisticsDistributionPage(snapshot: snapshot)
                case .trend:
                    statisticsTrendPage(snapshot: snapshot)
                case .achievement:
                    statisticsAchievementPage
                }
            }
            .id(statisticsPage)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
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

    private func statisticsDistributionPage(snapshot: FlowDashboardSnapshot) -> some View {
        VStack(spacing: 12) {
            Picker(String(localized: "集計単位"), selection: $distributionMode) {
                ForEach(DashboardDistributionMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            statisticsDonut(snapshot: snapshot)

            VStack(alignment: .leading, spacing: 9) {
                ForEach(distributionRows(snapshot: snapshot).prefix(4)) { row in
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
                                        .frame(width: proxy.size.width * distributionRatio(row, snapshot: snapshot))
                                }
                        }
                        .frame(height: 5)
                    }
                }
            }

            if distributionRows(snapshot: snapshot).isEmpty {
                Text(String(localized: "Flowを記録すると時間配分が表示されます"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func statisticsDonut(snapshot: FlowDashboardSnapshot) -> some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 12)
            ForEach(distributionSlices(snapshot: snapshot)) { slice in
                Circle()
                    .trim(from: slice.start, to: slice.end)
                    .stroke(Color(hex: slice.colorHex), style: StrokeStyle(lineWidth: 12, lineCap: .butt))
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
        .frame(width: 108, height: 108)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.25), value: snapshot.totalFocusSeconds)
    }

    private func statisticsTrendPage(snapshot: FlowDashboardSnapshot) -> some View {
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

            DashboardStatisticsBars(days: days)
                .frame(height: 112)

            Divider()

            comparisonRow(String(localized: "集中時間"), value: signedMinutes(comparison.focusSecondsDelta), systemImage: "timer")
            comparisonRow(String(localized: "完了タスク"), value: signedCount(comparison.completedTaskDelta), systemImage: "checkmark.circle")
            comparisonRow(String(localized: "ブロック"), value: signedBlocks(comparison.blocksDelta), systemImage: "square.stack.3d.up")
            comparisonRow(
                String(localized: "伸びた方向"),
                value: growthText(comparison.growingDirection),
                systemImage: "arrow.up.right"
            )
        }
    }

    private var statisticsAchievementPage: some View {
        let standard = standardTodos
        let habits = habitTodos
        let nice = niceTodos
        let required = standard + habits
        let completed = required.filter(\.isCompleted).count
        let ratio = required.isEmpty ? 0 : Double(completed) / Double(required.count)

        return VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: ratio)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int((ratio * 100).rounded()))%")
                    .font(.title3.bold())
                    .monospacedDigit()
            }
            .frame(width: 112, height: 112)

            achievementRow(String(localized: "タスク"), completed: standard.filter(\.isCompleted).count, total: standard.count)
            achievementRow(String(localized: "習慣一覧"), completed: habits.filter(\.isCompleted).count, total: habits.count)
            if !nice.isEmpty {
                achievementRow(String(localized: "ナイス"), completed: nice.filter(\.isCompleted).count, total: nice.count)
            }

            Text(String(localized: "今日の達成 \(completed) / \(required.count)"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private var todayTodos: [Todo] {
        cachedTodoGroups?.all ?? []
    }

    private var standardTodos: [Todo] {
        cachedTodoGroups?.standard ?? []
    }

    private var habitTodos: [Todo] {
        cachedTodoGroups?.habits ?? []
    }

    private var niceTodos: [Todo] {
        cachedTodoGroups?.nice ?? []
    }

    private var activeDirections: [Direction] {
        directions
            .filter { !$0.isArchived }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var dashboardAddButton: some View {
        Button {
            showsQuickComposer = true
        } label: {
            Image(systemName: "plus")
        }
        .buttonStyle(.plain)
        .help(String(localized: "タスクを追加"))
        .accessibilityLabel(String(localized: "タスクを追加"))
        .popover(isPresented: $showsQuickComposer, arrowEdge: .top) {
            QuickTodoCreationPopover(directions: activeDirections)
        }
    }

    private func moveStatisticsPage(_ offset: Int) {
        let pages = DashboardStatisticsPage.allCases
        guard let current = pages.firstIndex(of: statisticsPage) else { return }
        let next = (current + offset + pages.count) % pages.count
        withAnimation(.easeInOut(duration: 0.2)) {
            statisticsPage = pages[next]
        }
    }

    private func distributionRows(snapshot: FlowDashboardSnapshot) -> [DashboardDistributionRow] {
        switch distributionMode {
        case .task:
            snapshot.taskSummaries.map {
                DashboardDistributionRow(
                    id: $0.id,
                    symbol: $0.symbol,
                    title: $0.title,
                    colorHex: $0.colorHex,
                    focusSeconds: $0.focusSeconds
                )
            }
        case .direction:
            snapshot.directionSummaries.map {
                DashboardDistributionRow(
                    id: $0.id.uuidString,
                    symbol: $0.symbol,
                    title: $0.name,
                    colorHex: $0.colorHex,
                    focusSeconds: $0.focusSeconds
                )
            }
        }
    }

    private func distributionSlices(snapshot: FlowDashboardSnapshot) -> [DashboardFlowTaskSlice] {
        guard snapshot.totalFocusSeconds > 0 else { return [] }

        var cursor = 0.0
        let rows = distributionRows(snapshot: snapshot)
        return rows.map { row in
            let fraction = Double(row.focusSeconds) / Double(snapshot.totalFocusSeconds)
            let gap = rows.count > 1 ? min(0.004, fraction * 0.18) : 0
            let slice = DashboardFlowTaskSlice(
                id: row.id,
                start: cursor + (gap / 2),
                end: cursor + fraction - (gap / 2),
                colorHex: row.colorHex
            )
            cursor += fraction
            return slice
        }
    }

    private func distributionRatio(
        _ row: DashboardDistributionRow,
        snapshot: FlowDashboardSnapshot
    ) -> Double {
        snapshot.focusShare(for: row.focusSeconds)
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

    private func growthText(_ growth: DashboardStatisticsDirectionGrowth?) -> String {
        guard let growth else { return String(localized: "変化なし") }
        return String(localized: "\(growth.symbol) \(growth.name) +\(max(1, growth.focusSecondsDelta / 60))分")
    }

    private var modeBackgroundTint: Color {
        switch activeFlowStore.selectedMode {
        case .sprint, .adaptive:
            Color.orange.opacity(0.025)
        case .twentyFiveFive:
            Color.blue.opacity(0.025)
        case .fiftyTen:
            Color.indigo.opacity(0.035)
        }
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

    private func progressText(_ todo: Todo) -> String {
        progressCalculator.summary(
            measurement: todo.measurement,
            plannedAmount: todo.plannedAmount,
            actualProgress: todo.actualProgress,
            focusDurationSeconds: todo.focusDurationSeconds
        )
    }

    private func toggleTodo(_ todo: Todo) {
        guard todo.setManuallyCompleted(!todo.isCompleted) else { return }
        _ = modelContext.saveReporting(.flowUpdate)
    }

    private func ensureTodayHabits(now: Date = .now) {
        let today = dayBoundary.day(containing: now, calendar: calendar)
        do {
            _ = try HabitTodoMaterializer(
                calendar: calendar,
                dayBoundary: dayBoundary
            ).materialize(
                directions: directions,
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

    private var timelineTrackColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.46 : 0.12)
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
        let name = flowBreak.isLongBreak ? String(localized: "長休憩") : String(localized: "休憩")
        let duration = TimelineSegmentFormat.duration(flowBreak.durationSeconds)
        return String(localized: "☕️ \(name)（\(duration)）")
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
        return date.formatted(.dateTime.locale(locale).hour().minute())
    }

    private func deleteTimelineSegment(_ segment: FlowDashboardSegment) {
        selectedTimelineItem = nil

        do {
            if let storedSegment = segment.storedSegment {
                try historyEditor.delete(
                    segment: storedSegment,
                    from: segment.session,
                    modelContext: modelContext
                )
            } else {
                try historyEditor.delete(session: segment.session, modelContext: modelContext)
            }
        } catch {
            modelContext.rollback()
            PersistenceIssueCenter.shared.report(error, operation: .historyUpdate)
            return
        }

        _ = modelContext.saveReporting(.flowUpdate)
    }

    private func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.locale(locale).month(.wide).day().weekday(.wide))
    }

    private func focusText(_ seconds: Int) -> String {
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        return hours > 0 ? String(localized: "\(hours)時間\(minutes)分") : String(localized: "\(minutes)分")
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

private struct TimelineSegmentHoverCard: View {
    @Environment(\.locale) private var locale

    let segment: FlowDashboardSegment

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(segment.symbol) \(segment.taskTitle)")
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            Text("\(TimelineSegmentFormat.interval(segment, locale: locale)) · \(TimelineSegmentFormat.duration(segment.focusSeconds))")
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
    @Environment(\.locale) private var locale

    let flowBreak: FlowDashboardBreak

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(flowBreak.isLongBreak ? String(localized: "長休憩") : String(localized: "休憩"), systemImage: "cup.and.saucer.fill")
                .font(.caption.weight(.semibold))

            Text("\(TimelineSegmentFormat.interval(from: flowBreak.startedAt, to: flowBreak.endedAt, locale: locale)) · \(TimelineSegmentFormat.duration(flowBreak.durationSeconds))")
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
    @Environment(\.locale) private var locale

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
                    Text(flowBreak.isLongBreak ? String(localized: "長休憩") : String(localized: "休憩"))
                        .font(.headline)
                    Text(String(localized: "開始時刻は固定されます"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Label(String(localized: "開始"), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(TimelineSegmentFormat.time(flowBreak.startedAt, locale: locale))
                    .monospacedDigit()
            }

            HStack {
                Label(String(localized: "終了"), systemImage: "clock.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(TimelineSegmentFormat.time(adjustedEndAt, locale: locale))
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                Text(String(localized: "休憩時間"))
                    .font(.callout.weight(.medium))
                Spacer()
                TextField(String(localized: "分"), value: $minutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 76)
                    .onSubmit(save)
                Text(String(localized: "分"))
                    .foregroundStyle(.secondary)
            }

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: save) {
                Text(String(localized: "保存"))
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
            errorText = String(localized: "実行中のFlowは移動できません。現在のFlowを終了してから編集してください。")
        } catch {
            errorText = String(localized: "休憩時間を保存できませんでした。")
        }
    }
}

private struct TimelineSegmentPopover: View {
    @Environment(\.locale) private var locale

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
                    Text(String(localized: "実行中"))
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
                    .help(String(localized: "この区間を削除"))
                    .accessibilityLabel(String(localized: "このFlow区間を削除"))
                }
            }

            Divider()

            segmentDetail(String(localized: "時間"), value: TimelineSegmentFormat.interval(segment, locale: locale), systemImage: "clock")
            segmentDetail(String(localized: "集中"), value: TimelineSegmentFormat.duration(segment.focusSeconds), systemImage: "timer")
            segmentDetail(String(localized: "集中モード"), value: segment.session.mode.displayName, systemImage: "waveform.path")

            if let onOpenHistory {
                Button(action: onOpenHistory) {
                    Label(String(localized: "Flow履歴を開く"), systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: segment.colorHex))
            }
        }
        .padding(16)
        .frame(width: 290)
        .confirmationDialog(
            String(localized: "このFlow区間を削除しますか？"),
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "削除"), role: .destructive) {
                onDelete?()
            }
            Button(String(localized: "キャンセル"), role: .cancel) {}
        } message: {
            Text(String(localized: "この区間の集中時間がタスクと方向の進捗から差し引かれます。"))
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
    static func interval(_ segment: FlowDashboardSegment, locale: Locale) -> String {
        interval(from: segment.startedAt, to: segment.endedAt, locale: locale)
    }

    static func interval(from start: Date, to end: Date, locale: Locale) -> String {
        "\(time(start, locale: locale))–\(time(end, locale: locale))"
    }

    static func time(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return formatter.string(from: date)
    }

    static func duration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return remainingSeconds == 0 ? String(localized: "\(minutes)分") : String(localized: "\(minutes)分\(remainingSeconds)秒")
    }
}

private enum DashboardStatisticsPage: Int, CaseIterable, Identifiable {
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

private enum DashboardDistributionMode: String, CaseIterable, Identifiable {
    case task
    case direction

    var id: String { rawValue }
    var title: String { self == .task ? String(localized: "タスク別") : String(localized: "方向別") }
}

private struct DashboardDistributionRow: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let colorHex: String
    let focusSeconds: Int
}

private struct DashboardStatisticsBars: View {
    let days: [DashboardStatisticsDay]

    var body: some View {
        GeometryReader { proxy in
            let maximum = max(days.map(\.focusSeconds).max() ?? 0, 1)

            HStack(alignment: .bottom, spacing: 7) {
                ForEach(days) { day in
                    let minimumHeight: CGFloat = day.focusSeconds > 0 ? 4 : 2
                    let availableHeight = max(proxy.size.height - 23, 0)
                    let proportionalHeight = availableHeight * CGFloat(day.focusSeconds) / CGFloat(maximum)
                    let barHeight = max(minimumHeight, proportionalHeight)

                    VStack(spacing: 5) {
                        Spacer(minLength: 0)
                        Capsule()
                            .fill(Color(hex: day.colorHex))
                            .frame(width: 7, height: barHeight)
                        Text(dayLabel(day.date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(dayAccessibilityLabel(day))
                }
            }
        }
    }

    private func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.day())
    }

    private func dayAccessibilityLabel(_ day: DashboardStatisticsDay) -> String {
        let minutes = day.focusSeconds / 60
        return String(localized: "\(day.date.formatted(date: .abbreviated, time: .omitted))、\(minutes)分")
    }
}

private struct DashboardFlowTaskSlice: Identifiable {
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
                Text(String(localized: "今日の項目はありません"))
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
        let tags = todo.hashtags.map { "#\($0)" }.joined(separator: " ")
        let detail = showsPriority
            ? String(localized: "\(priorityLabel(todo)) · \(progressText(todo))")
            : progressText(todo)
        return tags.isEmpty ? detail : String(localized: "\(detail) · \(tags)")
    }

    private func priorityLabel(_ todo: Todo) -> String {
        if todo.priority == .low, todo.isRoomIfPossible {
            return String(localized: "余裕があれば")
        }
        return todo.priority.displayName
    }
}

#Preview {
    FlowDashboardPreviewHost()
}

private struct FlowDashboardPreviewHost: View {
    @State private var snapshot: FlowDashboardSnapshot?
    @State private var todoGroups: FlowDashboardTodoGroups?

    var body: some View {
        FlowDashboardView(
            directions: [],
            cachedSnapshot: $snapshot,
            cachedTodoGroups: $todoGroups
        )
        .environmentObject(ActiveFlowStore())
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self], inMemory: true)
    }
}

private struct FlowDashboardRefreshID: Hashable {
    let isVisible: Bool
    let sessionCount: Int
    let latestSessionUpdate: Date?
    let breakCount: Int
    let latestBreakUpdate: Date?
    let directionCount: Int
    let latestDirectionUpdate: Date?
    let activeSessionID: UUID?
    let phase: String?
}

private struct FlowDashboardTodoRefreshID: Hashable {
    let isVisible: Bool
    let todoCount: Int
    let latestTodoUpdate: Date?
}

private struct FlowDashboardHabitPreparationID: Hashable {
    let isVisible: Bool
    let directionCount: Int
    let latestDirectionUpdate: Date?
    let todoCount: Int
    let latestTodoUpdate: Date?
    let revision: Int
}
