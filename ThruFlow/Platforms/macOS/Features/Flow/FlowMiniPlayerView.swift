//
//  FlowMiniPlayerView.swift
//  ThruFlow
//
//

import AppKit
import Combine
import SwiftData
import SwiftUI

struct FlowMiniPlayerView: View {
    enum Style {
        case header
        case dashboard
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Area.name, order: .forward) private var areas: [Area]
    @Query(sort: \Todo.createdAt, order: .forward) private var todos: [Todo]

    @State private var wallClockRevision = Date.now
    @State private var showsTaskPicker = false
    @State private var showsTaskComposer = false
    @State private var presentsTaskComposerAfterPicker = false
    @State private var taskComposerPresentationTask: Task<Void, Never>?
    @State private var resultText = ""
    @State private var resultTaskTitle = ""
    @State private var didEditResultTitle = false
    @State private var highlightedResultTitleSuggestionID: String?
    @State private var resultProject: Project?
    @State private var resultTaskSwitchID: UUID?
    @FocusState private var isResultTitleFocused: Bool
    @State private var editingTaskTitleID: UUID?
    @State private var taskTitleDraft = ""
    @State private var taskCardIsPressed = false
    @FocusState private var isTaskTitleFocused: Bool
    @FocusState private var isMemoFocused: Bool

    private let style: Style
    private let taskSuggestionsBelow: Bool
    private var todayFilter: TodayTodoFilter {
        TodayTodoFilter(calendar: calendar, dayBoundary: dayBoundary)
    }

    init(style: Style = .header, taskSuggestionsBelow: Bool = false) {
        self.style = style
        self.taskSuggestionsBelow = taskSuggestionsBelow
    }

    private var activeAreas: [Area] {
        areas.filter { !$0.isArchived }
    }

    private var visibleAreas: [Area] {
        activeAreas.filter { !DefaultAreas.isTaskInbox($0) }
    }

    private var activeTodos: [Todo] {
        todos.filter { !$0.isArchived && !$0.isDeleted }
    }

    private func todayTodos(at date: Date) -> [Todo] {
        activeTodos.filter { todayFilter.includes($0, now: date) }
    }

    private var selectedArea: Area? {
        guard let id = activeFlowStore.selectedAreaID else { return nil }
        return activeAreas.first { $0.id == id }
    }

    private var selectedTodo: Todo? {
        guard let id = activeFlowStore.selectedTodoID else { return nil }
        return activeTodos.first { $0.id == id }
    }

    var body: some View {
        content
        .background {
            TimelineView(FlowPlayerSchedule.seconds(active: activeFlowStore.timerState != nil)) { tick in
                Color.clear
                    .onChange(of: tick.date) { _, date in
                        activeFlowStore.refresh(modelContext: modelContext, now: date)
                    }
            }
            TimelineView(FlowPlayerSchedule.appDay(dayBoundary, calendar, revision: wallClockRevision)) { tick in
                Color.clear
                    .onChange(of: dayBoundary.day(containing: tick.date, calendar: calendar)) { _, _ in
                        reconcileSelectedTodo(now: tick.date)
                    }
            }
        }
        .background {
            MacWindowPresentationAnchor(onHidden: dismissTaskPopovers)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            wallClockRevision = .now
            reconcileSelectedTodo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemClockDidChange)
            .merge(with: NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange))) { _ in
            wallClockRevision = .now
            reconcileSelectedTodo()
        }
        .onDisappear(perform: dismissTaskPopovers)
        .onAppear {
            reconcileSelectedTodo()
        }
        .onChange(of: activeFlowStore.pendingTaskSwitch?.id) { _, requestID in
            guard requestID != nil else {
                resultText = ""
                resultProject = nil
                return
            }
            dismissTaskPopovers()
            resultText = ""
            resultTaskTitle = activeFlowStore.memoTodo?.title ?? ""
            resultProject = nil
        }
        .onChange(of: activeFlowStore.timerState == nil) { _, isIdle in
            guard isIdle else { return }
            reconcileSelectedTodo()
        }
    }

    private func reconcileSelectedTodo(now: Date = .now) {
        activeFlowStore.reconcileSelectedTodoForCurrentDay(
            todos: activeTodos,
            areas: activeAreas,
            now: now,
            calendar: calendar,
            dayBoundary: dayBoundary
        )
    }

    @ViewBuilder
    private var content: some View {
        let memoTransition: AnyTransition = reduceMotion
            ? .identity
            : .opacity.animation(.smooth(duration: 0.22))

        ZStack(alignment: .top) {
            if activeFlowStore.pendingTaskSwitch != nil {
                resultBar
                    .transition(memoTransition)
                    .zIndex(1)
            } else if activeFlowStore.phase == .awaitingExtensionDecision {
                adaptiveDecisionBar
            } else if activeFlowStore.phase == .awaitingResult || activeFlowStore.isAwaitingBreakMemo {
                resultBar
                    .transition(memoTransition)
                    .zIndex(1)
            } else {
                if style == .dashboard {
                    dashboardPlayer
                } else {
                    headerPlayer
                }
            }
        }
        .padding(.horizontal, style == .dashboard ? 0 : 12)
        .padding(.vertical, style == .dashboard ? 0 : 8)
        .background {
            if style != .dashboard {
                Rectangle().fill(.bar)
            }
        }
        .onTapGesture {
            dismissTaskTitleEditor()
        }
        .overlayPreferenceValue(TaskTitleEditorBoundsPreferenceKey.self) { anchor in
            GeometryReader { proxy in
                let suggestions = taskTitleSuggestions
                if let anchor, !suggestions.isEmpty {
                    let fieldBounds = proxy[anchor]
                    let panelWidth = max(fieldBounds.width, 180)

                    Color.clear
                        .frame(
                            width: panelWidth,
                            height: 0
                        )
                        .overlay(alignment: .topLeading) {
                            taskTitleSuggestionPanel(suggestions) { suggestion in
                                taskTitleDraft = suggestion.title
                                commitTaskTitle()
                            }
                            .frame(width: panelWidth)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .offset(
                            x: fieldBounds.minX,
                            y: fieldBounds.maxY + 6
                        )
                }
            }
        }
    }

    private var headerPlayer: some View {
        HStack(spacing: 12) {
            taskPickerButton
                .frame(minWidth: style == .dashboard ? 360 : 280, maxWidth: .infinity, alignment: .leading)

            modePickerButton
            TimelineView(displaySchedule) { tick in
                timerCluster(now: tick.date)
            }
            TimelineView(overtimeSchedule) { tick in
                transportControls(now: tick.date)
            }
        }
        .padding(.horizontal, style == .dashboard ? 18 : 14)
        .padding(.vertical, style == .dashboard ? 14 : 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.08))
        }
        .shadow(color: .black.opacity(0.10), radius: 14, y: 5)
    }

    private var dashboardPlayer: some View {
        FlowTimerPanelShell(
            style: .dashboard,
            timerAccessibilityLabel: String(localized: "Flowタイマー")
        ) {
            TimelineView(displaySchedule) { tick in
                FlowTimerPresentation(
                    progress: activeFlowStore.phaseProgress(now: tick.date),
                    tint: timerRingColor,
                    eyebrow: timerEyebrow,
                    timeText: dashboardTimerText(now: tick.date),
                    footer: timerPhaseName,
                    slices: activeFlowStore.timerRingSlices(now: tick.date)
                )
                .dial(style: .dashboard)
            }
        } context: {
            taskPickerButton
        } mode: {
            modePickerButton
        } controls: {
            TimelineView(overtimeSchedule) { tick in
                dashboardTransportControls(now: tick.date)
            }
        }
    }

    private var displaySchedule: FlowPlayerSchedule {
        .display(for: activeFlowStore.timerState)
    }

    private var overtimeSchedule: FlowPlayerSchedule {
        .overtime(for: activeFlowStore.timerState, revision: wallClockRevision)
    }

    private func dashboardTimerText(now: Date) -> String {
        activeFlowStore.timerState == nil
            ? String(format: "%02d:00", activeFlowStore.selectedMode.initialFocusDurationSeconds / 60)
            : activeFlowStore.remainingText(now: now)
    }

    private var taskPickerButton: some View {
        FlowTimerContextButton(
            style: .dashboard,
            presentation: FlowTimerContextPresentation(
                symbol: flowArea?.symbolName ?? "▶",
                areaTitle: flowAreaName,
                tint: artworkColor,
                isPlaceholder: flowTaskTitleIsPlaceholder,
                showsProgress: selectedTodo != nil
            ),
            isVisuallyPressed: !reduceMotion && taskCardIsPressed,
            animatesVisualPress: true,
            accessibilityLabel: String(localized: "Flowタスクを選択"),
            action: openTaskPicker
        ) {
            taskTitleEditor
        } progress: {
            if let todo = selectedTodo {
                TimelineView(taskProgressSchedule(for: todo)) { tick in
                    TodoProgressControl(
                        todo: todo,
                        additionalFocusSeconds: liveSelectedTaskFocusSeconds(now: tick.date)
                    ) {
                        if todo.setManuallyCompleted(!todo.isCompleted) {
                            _ = modelContext.saveReporting(.flowUpdate)
                        }
                    }
                }
            }
        } detail: {
            if let todo = selectedTodo, todo.measurement != .checkbox {
                TimelineView(taskProgressSchedule(for: todo)) { tick in
                    Text(todoRemainingText(todo, additionalFocusSeconds: liveSelectedTaskFocusSeconds(now: tick.date)))
                }
            }
        }
        .popover(isPresented: $showsTaskPicker, arrowEdge: .bottom) {
            TimelineView(FlowPlayerSchedule.appDay(dayBoundary, calendar, revision: wallClockRevision)) { tick in
                FlowTaskPickerView(
                    areas: activeAreas,
                    todos: todayTodos(at: tick.date),
                    selectedAreaID: activeFlowStore.selectedAreaID,
                    selectedTodoID: activeFlowStore.selectedTodoID,
                    onCreateTask: presentTaskComposer
                ) { area, todo in
                    activeFlowStore.selectPickerContext(
                        area: area,
                        todo: todo,
                        modelContext: modelContext,
                        calendar: calendar,
                        dayBoundary: dayBoundary
                    )
                }
                .frame(width: 520, height: 460)
            }
        }
        .popover(isPresented: $showsTaskComposer, arrowEdge: .trailing) {
            QuickTodoCreationPopover(
                areas: activeAreas,
                showsQuickInputLegend: false,
                suggestionsBelow: taskSuggestionsBelow,
                isPresented: $showsTaskComposer
            ) { todo in
                activeFlowStore.selectPickerContext(
                    area: todo.area,
                    todo: todo,
                    modelContext: modelContext,
                    calendar: calendar,
                    dayBoundary: dayBoundary
                )
            }
        }
        .onChange(of: showsTaskPicker) { _, isPresented in
            guard !isPresented, presentsTaskComposerAfterPicker else { return }
            presentsTaskComposerAfterPicker = false

            taskComposerPresentationTask?.cancel()
            taskComposerPresentationTask = Task { @MainActor in
                await Task.yield()
                guard !Task.isCancelled else { return }
                showsTaskComposer = true
                taskComposerPresentationTask = nil
            }
        }
        .onChange(of: selectedTodo?.id) { _, newID in
            if editingTaskTitleID != newID {
                cancelTaskTitleEdit()
            }
        }
        .onChange(of: isTaskTitleFocused) { _, isFocused in
            if !isFocused, editingTaskTitleID != nil {
                commitTaskTitle()
            }
        }
    }

    private func dismissTaskPopovers() {
        taskComposerPresentationTask?.cancel()
        taskComposerPresentationTask = nil
        presentsTaskComposerAfterPicker = false
        showsTaskPicker = false
        showsTaskComposer = false
    }

    private func presentTaskComposer() {
        presentsTaskComposerAfterPicker = true
        showsTaskPicker = false
    }

    private var modePickerButton: some View {
        FlowModeSelector(
            selection: Binding(
                get: { activeFlowStore.selectedMode },
                set: { activeFlowStore.selectMode($0, modelContext: modelContext) }
            ),
            isSelectionEnabled: activeFlowStore.canChangeMode
        )
        .frame(width: style == .dashboard ? 280 : 240)
    }

    private func timerCluster(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(timerEyebrow)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(activeFlowStore.timerState == nil ? activeFlowStore.selectedMode.compactDurationText : activeFlowStore.remainingText(now: now))
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                if activeFlowStore.timerState != nil {
                    Text("/ \(activeFlowStore.selectedMode.initialFocusDurationSeconds / 60):00")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .frame(width: 130, alignment: .leading)
        .accessibilityLabel(activeFlowStore.timerState == nil ? String(localized: "Flow未開始") : String(localized: "残り時間 \(activeFlowStore.remainingText(now: now))"))
    }

    private var timerEyebrow: String {
        switch activeFlowStore.phase {
        case .focusing:
            String(localized: "集中")
        case .paused:
            String(localized: "一時停止中のFlow")
        case .breakTime:
            activeFlowStore.timerState?.isLongBreak == true ? String(localized: "長休憩") : String(localized: "休憩")
        default:
            String(localized: "待機中")
        }
    }

    private var timerPhaseName: String {
        activeFlowStore.isBreakPhase && activeFlowStore.timerState?.isLongBreak == true
            ? String(localized: "長休憩")
            : activeFlowStore.selectedMode.displayName
    }

    private var playerArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(artworkColor.opacity(0.18))

            Text(flowArea?.symbolName ?? "▶")
                .font(.system(size: 22))
        }
        .frame(width: 42, height: 42)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(artworkColor.opacity(0.24))
        }
        .accessibilityHidden(true)
    }

    private func contextLabel(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            taskTitleEditor

            Text(flowAreaName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let selectedTodo, selectedTodo.measurement != .checkbox {
                Text(todoRemainingText(
                    selectedTodo,
                    additionalFocusSeconds: liveSelectedTaskFocusSeconds(now: now)
                ))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(artworkColor)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var taskTitleEditor: some View {
        if let selectedTodo, editingTaskTitleID == selectedTodo.id {
            TextField(TodoDisplay.flowPlaceholder(for: selectedTodo), text: $taskTitleDraft)
                .textFieldStyle(.plain)
                .font(.headline)
                .focused($isTaskTitleFocused)
                .onSubmit(commitTaskTitle)
                .onExitCommand(perform: cancelTaskTitleEdit)
                .accessibilityLabel(String(localized: "タスク名"))
                .anchorPreference(
                    key: TaskTitleEditorBoundsPreferenceKey.self,
                    value: .bounds,
                    transform: { $0 }
                )
        } else {
            Text(flowTaskTitle)
                .font(contextTitleFont)
                .foregroundStyle(flowTaskTitleIsPlaceholder ? Color.secondary.opacity(0.7) : Color.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    TapGesture(count: 2)
                        .exclusively(before: TapGesture(count: 1))
                        .onEnded { gesture in
                            switch gesture {
                            case .first:
                                beginTaskTitleEdit()
                            case .second:
                                openTaskPicker()
                            }
                        }
                )
                .accessibilityAction(named: String(localized: "タスク名を編集")) {
                    beginTaskTitleEdit()
                }
                .accessibilityLabel(String(localized: "タスク名"))
        }
    }

    private func dismissTaskTitleEditor() {
        guard editingTaskTitleID != nil else { return }

        isTaskTitleFocused = false
#if os(macOS)
        MacOSFocusController.dismissCurrentEditor()
#endif
    }

    private func openTaskPicker() {
        if editingTaskTitleID != nil {
            commitTaskTitle()
        }

        if !reduceMotion { taskCardIsPressed = true }
        showsTaskPicker = true

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            taskCardIsPressed = false
        }
    }

    private func beginTaskTitleEdit() {
        guard let selectedTodo else {
            showsTaskPicker = true
            return
        }

        taskTitleDraft = selectedTodo.title
        editingTaskTitleID = selectedTodo.id
        Task { @MainActor in
            isTaskTitleFocused = true
        }
    }

    private var taskTitleSuggestions: [TaskTitleSuggestion] {
        guard isTaskTitleFocused, let selectedTodo else { return [] }
        return TaskTitleSuggestionBuilder().suggestions(
            query: taskTitleDraft,
            todos: todos,
            excludingTodoID: selectedTodo.id,
            limit: 3
        )
    }

    private func taskTitleSuggestionPanel(
        _ suggestions: [TaskTitleSuggestion],
        highlightedID: String? = nil,
        onSelect: @escaping (TaskTitleSuggestion) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(suggestions) { suggestion in
                Button {
                    onSelect(suggestion)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(.tint)
                            .frame(width: 16)
                        Text(suggestion.title)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                    .background(
                        suggestion.id == highlightedID ? Color.accentColor.opacity(0.18) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.12))
        }
    }

    private func commitTaskTitle() {
        guard let selectedTodo, editingTaskTitleID == selectedTodo.id else {
            cancelTaskTitleEdit()
            return
        }

        let normalizedTitle = taskTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedTodo.title != normalizedTitle {
            selectedTodo.title = normalizedTitle
            selectedTodo.updatedAt = .now
            _ = modelContext.saveReporting(.flowUpdate)
        }

        editingTaskTitleID = nil
        isTaskTitleFocused = false
    }

    private func cancelTaskTitleEdit() {
        taskTitleDraft = selectedTodo?.title ?? ""
        editingTaskTitleID = nil
        isTaskTitleFocused = false
    }

    private var canSeek: Bool {
        activeFlowStore.timerState?.canAdjustRemainingTime == true
    }

    private var flowArea: Area? {
        if let area = selectedTodo?.area {
            return area
        }

        return selectedArea
    }

    private var flowTaskTitle: String {
        if let selectedTodo {
            return TodoDisplay.flowTitle(for: selectedTodo)
        }

        if let selectedArea {
            return "(\(selectedArea.name))"
        }

        return String(localized: "具体的なタスクなし")
    }

    private var flowTaskTitleIsPlaceholder: Bool {
        if let selectedTodo {
            return selectedTodo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return selectedArea != nil
    }

    private var contextTitleFont: Font {
        let font: Font = .headline
        return flowTaskTitleIsPlaceholder ? font.italic() : font
    }

    private var flowAreaName: String {
        TodoDisplay.flowContextName(for: selectedTodo, area: flowArea)
    }

    private var artworkColor: Color {
        if let area = flowArea, !DefaultAreas.isTaskInbox(area) {
            return Color(hex: area.colorHex)
        }

        return .accentColor
    }

    private func todoRemainingText(_ todo: Todo, additionalFocusSeconds: Int) -> String {
        let displayedFocusSeconds = todo.recordedFocusSeconds + max(0, additionalFocusSeconds)

        switch todo.measurement {
        case .checkbox:
            return todo.isCompleted ? String(localized: "完了済み") : String(localized: "未完了")
        case .focusBlocks:
            let planned = Double(todo.plannedAmount ?? 0)
            let remaining = max(0, planned - BlockUnit.blocks(forFocusedSeconds: displayedFocusSeconds))
            let value = remaining.formatted(
                .number
                    .precision(.fractionLength(0...1))
                    .locale(locale)
            )
            return String(localized: "残り \(value) Block")
        case .minutes:
            let remainingSeconds = max(0, (todo.plannedAmount ?? 0) * 60 - displayedFocusSeconds)
            return String(localized: "残り \(Int(ceil(Double(remainingSeconds) / 60)))分")
        }
    }

    private func taskProgressSchedule(for todo: Todo) -> FlowPlayerSchedule {
        guard todo.measurement != .checkbox,
              let state = activeFlowStore.timerState, state.actualFocusDurationSeconds == nil,
              currentSegment(for: todo) != nil else { return .seconds(active: false) }
        return displaySchedule
    }

    private func currentSegment(for todo: Todo) -> FlowSegment? {
        guard activeFlowStore.phase == .focusing || activeFlowStore.phase == .paused,
              let segment = activeFlowStore.activeSession?.resolvedSegments.last(where: { $0.endedAt == nil }),
              segment.todo?.id == todo.id else { return nil }
        return segment
    }

    private func liveSelectedTaskFocusSeconds(now: Date) -> Int {
        guard let selectedTodo, let segment = currentSegment(for: selectedTodo) else { return 0 }
        return max(0, activeFlowStore.actualFocusSeconds(now: now) - segment.startFocusSeconds)
    }

    private func transportControls(now: Date) -> some View {
        HStack(spacing: 6) {
            if style == .dashboard {
                compactControlSlot(isEnabled: activeFlowStore.timerState != nil) {
                    destroyButton
                }

                compactControlSlot(isEnabled: activeFlowStore.timerState != nil) {
                    stopButton
                }

                compactControlSlot(isEnabled: activeFlowStore.canRequestBreak) {
                    breakButton
                }

                compactControlSlot(isEnabled: canSeek) {
                    seekBackwardButton
                }

                primaryButton(now: now)

                compactControlSlot(isEnabled: canSeek) {
                    seekForwardButton
                }
            } else {
                if activeFlowStore.timerState != nil {
                    destroyButton
                    stopButton
                }

                if activeFlowStore.canRequestBreak {
                    breakButton
                }

                if canSeek {
                    seekBackwardButton
                }

                primaryButton(now: now)

                if canSeek {
                    seekForwardButton
                }
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.06))
        .clipShape(Capsule())
    }

    private func dashboardTransportControls(now: Date) -> some View {
        FlowTimerTransportControls(
            style: .dashboard,
            presentation: FlowTimerTransportPresentation(
                primarySymbol: primaryButtonImage(now: now),
                primaryLabel: primaryButtonTitle(now: now),
                primaryTint: primaryButtonColor(now: now),
                isPrimaryEnabled: true,
                canSeek: canSeek,
                canDestroy: activeFlowStore.timerState != nil,
                canStop: activeFlowStore.timerState != nil,
                canStartBreak: activeFlowStore.canRequestBreak,
                destroyLabel: activeFlowStore.isBreakPhase
                    ? String(localized: "休憩を削除")
                    : String(localized: "Flowを破壊"),
                visuallyPressedAction: nil
            ),
            animatesPrimarySymbol: true
        ) { action in
            switch action {
            case .seekBackward:
                activeFlowStore.seekBackward(modelContext: modelContext)
            case .primary:
                handlePrimaryAction()
            case .seekForward:
                activeFlowStore.seekForward(modelContext: modelContext)
            case .destroy:
                activeFlowStore.destroy(modelContext: modelContext)
            case .stop:
                activeFlowStore.stop(modelContext: modelContext)
            case .startBreak:
                activeFlowStore.requestBreakMemo(modelContext: modelContext)
            }
        }
    }

    private func compactControlSlot<Content: View>(
        isEnabled: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.34)
    }

    private var controlButtonSize: CGFloat {
        34
    }

    private var primaryControlButtonSize: CGFloat {
        42
    }

    private var seekBackwardButton: some View {
        Button {
            activeFlowStore.seekBackward(modelContext: modelContext)
        } label: {
            Image(systemName: "gobackward.5")
                .font(.callout.weight(.semibold))
                .frame(width: controlButtonSize, height: controlButtonSize)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(String(localized: "残り時間を5分短縮"))
    }

    private var seekForwardButton: some View {
        Button {
            activeFlowStore.seekForward(modelContext: modelContext)
        } label: {
            Image(systemName: "goforward.5")
                .font(.callout.weight(.semibold))
                .frame(width: controlButtonSize, height: controlButtonSize)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(String(localized: "残り時間を5分延長"))
    }

    private var stopButton: some View {
        Button {
            activeFlowStore.stop(modelContext: modelContext)
        } label: {
            Image(systemName: "stop.fill")
                .font(.callout.weight(.semibold))
                .frame(width: controlButtonSize, height: controlButtonSize)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(String(localized: "Flowを停止して保存"))
    }

    private var breakButton: some View {
        Button {
            activeFlowStore.requestBreakMemo(modelContext: modelContext)
        } label: {
            Image(systemName: "cup.and.saucer.fill")
                .font(.callout.weight(.semibold))
                .frame(width: controlButtonSize, height: controlButtonSize)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(String(localized: "休憩を開始"))
    }

    private var destroyButton: some View {
        Button(role: .destructive) {
            activeFlowStore.destroy(modelContext: modelContext)
        } label: {
            Image(systemName: "trash.fill")
                .font(.callout.weight(.semibold))
                .frame(width: controlButtonSize, height: controlButtonSize)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.red)
        .accessibilityLabel(activeFlowStore.isBreakPhase ? String(localized: "休憩を削除") : String(localized: "Flowを破壊"))
    }

    private func primaryButton(now: Date) -> some View {
        Button {
            handlePrimaryAction()
        } label: {
            if style == .dashboard {
                Image(systemName: primaryButtonImage(now: now))
                    .font(.title3.weight(.semibold))
                    .frame(width: primaryControlButtonSize, height: primaryControlButtonSize)
                    .background(primaryButtonColor(now: now))
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            } else {
                Label(primaryButtonTitle(now: now), systemImage: primaryButtonImage(now: now))
                    .font(.headline.weight(.semibold))
                    .frame(width: 142, height: 44)
                    .background(primaryButtonColor(now: now))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(primaryButtonTitle(now: now))
    }

    private func primaryButtonTitle(now: Date) -> String {
        switch activeFlowStore.phase {
        case .idle, .configured:
            String(localized: "Flowを開始")
        case .focusing:
            activeFlowStore.isFocusOvertime(now: now) ? String(localized: "休憩") : String(localized: "一時停止")
        case .paused:
            String(localized: "再開")
        case .breakTime:
            String(localized: "Flowを開始")
        case .awaitingExtensionDecision:
            String(localized: "Flowを終了")
        case .awaitingResult:
            String(localized: "保存")
        case .completed:
            String(localized: "Flowを開始")
        }
    }

    private func primaryButtonImage(now: Date) -> String {
        switch activeFlowStore.phase {
        case .focusing:
            activeFlowStore.isFocusOvertime(now: now) ? "cup.and.saucer.fill" : "pause.fill"
        case .awaitingResult:
            "checkmark"
        default:
            "play.fill"
        }
    }

    private func primaryButtonColor(now: Date) -> Color {
        switch FlowTimerPrimaryTintRole(
            phase: activeFlowStore.phase,
            isFocusOvertime: activeFlowStore.isFocusOvertime(now: now)
        ) {
        case .area:
            artworkColor
        case .paused, .breakTime:
            .blue
        }
    }

    private var timerRingColor: Color {
        if activeFlowStore.phase == .paused { return .blue }
        if activeFlowStore.isBreakPhase { return Color.secondary.opacity(0.72) }
        return artworkColor
    }

    private var adaptiveDecisionBar: some View {
        HStack(spacing: 10) {
            Text(String(localized: "次を選択"))
                .font(.headline)

            Spacer()

            if activeFlowStore.timerState?.nextAdaptiveFocusDurationSeconds != nil {
                Button(String(localized: "+\(adaptiveExtensionMinutes)分")) {
                    activeFlowStore.extendAdaptive(modelContext: modelContext)
                }
            }

            Button(String(localized: "休憩")) {
                activeFlowStore.requestBreakMemo(modelContext: modelContext)
            }

            Button(String(localized: "Flowを終了")) {
                activeFlowStore.finish(modelContext: modelContext)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var resultBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                activeFlowStore.pendingTaskSwitch != nil
                    ? String(localized: "メモ")
                    : String(localized: "お疲れ様です。メモを追加しますか？"),
                systemImage: "note.text"
            )
            .font(.headline)

            if activeFlowStore.pendingTaskSwitch != nil {
                Text(String(localized: "タスクを切り替える前にメモを残せます。入力中も現在のタスクの時間を記録します。"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let todo = activeFlowStore.memoTodo {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "タスク名"))
                        .font(.subheadline.weight(.medium))
                    resultTitleField(for: todo.id)
                }
            }
            FlowMemoProjectPicker(todo: activeFlowStore.memoTodo, selection: $resultProject)
                .pickerStyle(.menu)

            Text(String(localized: "取り組んだこと"))
                .font(.subheadline.weight(.medium))

            ZStack(alignment: .topLeading) {
                if resultText.isEmpty {
                    Text(String(localized: "何をしましたか？"))
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $resultText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .focused($isMemoFocused)
                    .accessibilityLabel(String(localized: "Flowメモ"))
            }
            .frame(maxWidth: .infinity, minHeight: 110, maxHeight: .infinity)
            .background(Color.primary.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(0.10))
            }

            HStack(spacing: 10) {
                memoActionButton(String(localized: "キャンセル"), systemImage: "xmark") {
                    cancelMemo()
                }
                .accessibilityLabel(String(localized: "メモ入力をキャンセル"))

                Spacer(minLength: 0)

                Button {
                    submitMemo()
                } label: {
                    Label(memoSubmitTitle, systemImage: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 132, minHeight: 38)
                        .padding(.horizontal, 10)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(memoSubmitTitle)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08))
        }
        .onAppear {
            resultTaskSwitchID = activeFlowStore.pendingTaskSwitch?.id
            resultTaskTitle = activeFlowStore.memoTodo?.title ?? ""
            didEditResultTitle = false
            highlightedResultTitleSuggestionID = nil
            resultProject = nil
            Task { @MainActor in
                if activeFlowStore.memoTodo != nil && resultTaskTitle.isEmpty {
                    isResultTitleFocused = true
                } else {
                    isMemoFocused = true
                }
            }
        }
        .id(activeFlowStore.pendingTaskSwitch?.id)
    }

    private func resultTitleField(for todoID: UUID) -> some View {
        let sessionID = activeFlowStore.activeSession?.id
        let taskSwitchID = activeFlowStore.pendingTaskSwitch?.id
        let query = resultTaskTitle
        let suggestions = isResultTitleFocused && didEditResultTitle
            ? TaskTitleSuggestionBuilder().suggestions(query: query, todos: todos, excludingTodoID: todoID, limit: 3)
            : []

        let selectSuggestion: (TaskTitleSuggestion) -> Void = { suggestion in
            guard isResultTitleFocused, didEditResultTitle, resultTaskTitle == query,
                  activeFlowStore.activeSession?.id == sessionID,
                  activeFlowStore.pendingTaskSwitch?.id == taskSwitchID,
                  activeFlowStore.memoTodo?.id == todoID,
                  taskSwitchID != nil || activeFlowStore.isAwaitingBreakMemo || activeFlowStore.phase == .awaitingResult
            else { return }

            resultTaskTitle = suggestion.title
            didEditResultTitle = false
            highlightedResultTitleSuggestionID = nil
        }

        return TextField(String(localized: "タスク名"), text: Binding(
            get: { resultTaskTitle },
            set: { title in
                guard title != resultTaskTitle else { return }
                resultTaskTitle = title
                didEditResultTitle = true
                highlightedResultTitleSuggestionID = nil
            }
        ))
        .textFieldStyle(.roundedBorder)
        .focused($isResultTitleFocused)
        .onSubmit {
            if let suggestion = suggestions.first(where: { $0.id == highlightedResultTitleSuggestionID }) {
                selectSuggestion(suggestion)
            } else {
                isMemoFocused = true
            }
        }
        .onKeyPress(.upArrow) { moveResultTitleSuggestionHighlight(in: suggestions, by: -1) }
        .onKeyPress(.downArrow) { moveResultTitleSuggestionHighlight(in: suggestions, by: 1) }
        .onChange(of: isResultTitleFocused) { _, isFocused in
            if !isFocused {
                didEditResultTitle = false
                highlightedResultTitleSuggestionID = nil
            }
        }
        .background {
            TaskComposerSuggestionPanel(isPresented: !suggestions.isEmpty, showsBelow: taskSuggestionsBelow) {
                taskTitleSuggestionPanel(
                    suggestions,
                    highlightedID: highlightedResultTitleSuggestionID,
                    onSelect: selectSuggestion
                )
                .frame(width: taskSuggestionsBelow ? 270 : 320)
            }
        }
    }

    private func moveResultTitleSuggestionHighlight(
        in suggestions: [TaskTitleSuggestion],
        by offset: Int
    ) -> KeyPress.Result {
        guard !suggestions.isEmpty else { return .ignored }

        if let index = suggestions.firstIndex(where: { $0.id == highlightedResultTitleSuggestionID }) {
            let nextIndex = min(max(index + offset, 0), suggestions.count - 1)
            highlightedResultTitleSuggestionID = suggestions[nextIndex].id
        } else {
            highlightedResultTitleSuggestionID = offset < 0 ? suggestions.last?.id : suggestions.first?.id
        }
        return .handled
    }

    private func memoActionButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 38)
                .padding(.horizontal, 12)
                .background(Color.primary.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var hasMemoText: Bool {
        !resultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var memoSubmitTitle: String {
        hasMemoText
            ? String(localized: "メモを保存して続ける")
            : String(localized: "メモなしで送信")
    }

    private var adaptiveExtensionMinutes: Int {
        guard let state = activeFlowStore.timerState,
              let next = state.nextAdaptiveFocusDurationSeconds else {
            return 0
        }

        return (next - state.plannedFocusDurationSeconds) / 60
    }

    private func handlePrimaryAction() {
        switch activeFlowStore.phase {
        case .idle, .configured, .completed:
            let area = resolvedStartArea()
            let todo = selectedTodo

            activeFlowStore.configure(area: area, todo: todo)
            activeFlowStore.start(
                area: area,
                todo: todo,
                modelContext: modelContext
            )
        case .focusing:
            if activeFlowStore.isFocusOvertime(now: .now) {
                activeFlowStore.requestBreakMemo(modelContext: modelContext)
            } else {
                activeFlowStore.pause(modelContext: modelContext)
            }
        case .paused:
            activeFlowStore.resume(modelContext: modelContext)
        case .breakTime:
            activeFlowStore.startNextFlow(
                area: resolvedStartArea(),
                todo: selectedTodo,
                modelContext: modelContext
            )
        case .awaitingExtensionDecision:
            activeFlowStore.finish(modelContext: modelContext)
        case .awaitingResult:
            submitResult()
        }
    }

    private func submitResult() {
        let didSave: Bool
        if let requestID = resultTaskSwitchID {
            guard activeFlowStore.pendingTaskSwitch?.id == requestID else { return }
            didSave = activeFlowStore.completeTaskSwitchMemo(
                resultText, taskTitle: resultTaskTitle, taskProject: resultProject, modelContext: modelContext
            )
        } else if activeFlowStore.pendingTaskSwitch != nil {
            return
        } else if activeFlowStore.isAwaitingBreakMemo {
            didSave = activeFlowStore.completeBreakMemo(
                resultText, taskTitle: resultTaskTitle, taskProject: resultProject, modelContext: modelContext
            )
        } else {
            didSave = activeFlowStore.completeResult(
                resultText, taskTitle: resultTaskTitle, taskProject: resultProject, modelContext: modelContext
            )
        }
        if didSave {
            resultText = ""
            resultProject = nil
        }
    }

    private func submitMemo() {
        submitResult()
    }

    private func cancelMemo() {
        resultText = ""
        resultProject = nil
        if let requestID = resultTaskSwitchID {
            guard activeFlowStore.pendingTaskSwitch?.id == requestID else { return }
            activeFlowStore.cancelTaskSwitchMemo()
        } else if activeFlowStore.pendingTaskSwitch != nil {
            return
        } else if activeFlowStore.isAwaitingBreakMemo {
            activeFlowStore.cancelBreakMemo()
        } else {
            activeFlowStore.cancelResultMemo(modelContext: modelContext)
        }
    }

    private func resolvedStartArea() -> Area {
        if let selectedArea {
            return selectedArea
        }

        if let area = selectedTodo?.area, !area.isArchived {
            return area
        }

        if let taskInbox = DefaultAreas.existingTaskInbox(in: activeAreas) {
            return taskInbox
        }

        let taskInbox = DefaultAreas.makeTaskInbox()
        modelContext.insert(taskInbox)
        return taskInbox
    }


    private func todoMenuTitle(_ todo: Todo) -> String {
        if todo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return TodoDisplay.title(for: todo)
        }

        let taskText = TodoDisplay.title(for: todo)

        guard let area = todo.area else {
            return taskText
        }

        guard !DefaultAreas.isTaskInbox(area) else {
            return taskText
        }

        return "\(taskText)（\(area.name)）"
    }
}

private struct TaskTitleEditorBoundsPreferenceKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

struct FlowTaskPickerView: View {
    let areas: [Area]
    let todos: [Todo]
    let selectedAreaID: UUID?
    let selectedTodoID: UUID?
    let onCreateTask: () -> Void
    let onSelect: (Area?, Todo?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: FlowTaskPickerTab = .tasks

    private var projection: FlowContextPickerProjection {
        FlowContextPickerProjection(areas: areas, todos: todos)
    }

    private var taskGroups: [FlowContextPickerTaskGroup] {
        projection.taskGroups
    }

    private var habitTodos: [Todo] {
        projection.habitTodos
    }

    private var otherArea: Area? {
        projection.otherArea
    }

    private var userAreas: [Area] {
        projection.userAreas
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "Flowタスク"))
                    .font(.headline.weight(.semibold))

                Spacer(minLength: 0)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Picker(String(localized: "表示"), selection: $selectedTab) {
                ForEach(FlowTaskPickerTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            ScrollView {
                switch selectedTab {
                case .tasks:
                    taskTab
                case .habits:
                    habitTab
                case .areas:
                    areaTab
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(14)
        .background(.bar)
    }

    @ViewBuilder
    private var taskTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                onCreateTask()
            } label: {
                Label(String(localized: "タスクを追加"), systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                    .padding(.horizontal, 12)
                    .background(Color.accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            if taskGroups.isEmpty {
                emptyState(String(localized: "今日のタスクはありません"))
            } else {
                ForEach(taskGroups) { group in
                    sectionHeader(title: group.title, count: group.todos.count, tint: group.tint)

                    VStack(spacing: 7) {
                        ForEach(group.todos) { todo in
                            taskRow(todo)
                        }
                    }
                }
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var habitTab: some View {
        if habitTodos.isEmpty {
            emptyState(String(localized: "今日の習慣はありません"))
        } else {
            VStack(spacing: 7) {
                ForEach(habitTodos) { todo in
                    taskRow(todo)
                }
            }
            .padding(.top, 2)
        }
    }

    private var areaTab: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 120, maximum: 170), spacing: 10)],
            alignment: .leading,
            spacing: 10
        ) {
            areaGridItem(
                iconText: otherArea?.symbolName ?? DefaultAreas.taskInboxSymbol,
                title: otherArea?.name ?? String(localized: "その他"),
                color: .secondary,
                isSelected: selectedTodoID == nil && (selectedAreaID == otherArea?.id || selectedAreaID == nil)
            ) {
                onSelect(otherArea, nil)
                dismiss()
            }

            ForEach(userAreas) { area in
                areaGridItem(
                    iconText: area.symbolName,
                    title: area.name,
                    color: Color(hex: area.colorHex),
                    isSelected: selectedTodoID == nil && selectedAreaID == area.id
                ) {
                    onSelect(area, nil)
                    dismiss()
                }
            }
        }
        .padding(.top, 2)
    }

    private func taskRow(_ todo: Todo) -> some View {
        Button {
            onSelect(todo.area, todo)
            dismiss()
        } label: {
            pickerRow(
                iconText: todo.area?.symbolName ?? DefaultAreas.taskInboxSymbol,
                title: TodoDisplay.flowTitle(for: todo),
                subtitle: taskSubtitle(todo),
                color: areaColor(todo.area),
                isSelected: selectedTodoID == todo.id,
                isPlaceholder: todo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        .buttonStyle(.plain)
    }

    private func areaGridItem(
        iconText: String,
        title: String,
        color: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(iconText)
                    .font(.system(size: 28))
                    .frame(width: 46, height: 46)
                    .background(color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 32, alignment: .top)
            }
            .frame(maxWidth: .infinity, minHeight: 92)
            .padding(8)
            .background(isSelected ? color.opacity(0.14) : Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(color)
                        .padding(7)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? color.opacity(0.65) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func pickerRow(
        iconText: String,
        title: String,
        subtitle: String,
        color: Color,
        isSelected: Bool,
        isPlaceholder: Bool
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.16))

                Text(iconText)
                    .font(.title3)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(isPlaceholder ? .body.weight(.semibold).italic() : .body.weight(.semibold))
                    .foregroundStyle(isPlaceholder ? Color.secondary.opacity(0.7) : Color.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func areaColor(_ area: Area?) -> Color {
        guard let area, !DefaultAreas.isTaskInbox(area) else {
            return .secondary
        }

        return Color(hex: area.colorHex)
    }

    private func taskSubtitle(_ todo: Todo) -> String {
        let areaName = TodoDisplay.flowContextName(for: todo)
        let priority = todo.priority == .low && todo.isRoomIfPossible ? String(localized: "余裕があれば") : todo.priority.displayName
        return String(localized: "\(areaName) · \(priority)")
    }

    private func sectionHeader(title: String, count: Int, tint: Color) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)

            Text(title)
                .font(.caption.weight(.semibold))

            Text("\(count)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 240, alignment: .center)
    }
}

private enum FlowTaskPickerTab: String, CaseIterable, Identifiable {
    case tasks
    case habits
    case areas

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tasks:
            String(localized: "タスク")
        case .habits:
            String(localized: "習慣一覧")
        case .areas:
            String(localized: "方向")
        }
    }
}

private extension FlowContextPickerTaskGroup {
    var title: String {
        type.displayName
    }

    var tint: Color {
        switch type {
        case .habit:
            .red
        case .neutral:
            .blue
        case .nice:
            .green
        }
    }
}

#Preview {
    FlowMiniPlayerView()
        .environmentObject(ActiveFlowStore())
        .modelContainer(for: [Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self], inMemory: true)
}
