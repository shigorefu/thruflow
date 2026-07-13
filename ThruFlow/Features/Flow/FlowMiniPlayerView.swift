//
//  FlowMiniPlayerView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import SwiftData
import SwiftUI

struct FlowMiniPlayerView: View {
    enum Style {
        case header
        case dashboard
    }

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Direction.name, order: .forward) private var directions: [Direction]
    @Query(sort: \Todo.createdAt, order: .forward) private var todos: [Todo]

    @State private var showsTaskPicker = false
    @State private var showsModePicker = false
    @State private var resultText = ""
    @State private var editingTaskTitleID: UUID?
    @State private var taskTitleDraft = ""
    @FocusState private var isTaskTitleFocused: Bool

    private let style: Style
    private let todayFilter = TodayTodoFilter()

    init(style: Style = .header) {
        self.style = style
    }

    private var activeDirections: [Direction] {
        directions.filter { !$0.isArchived }
    }

    private var visibleDirections: [Direction] {
        activeDirections.filter { !DefaultDirections.isTaskInbox($0) }
    }

    private var activeTodos: [Todo] {
        todos.filter { !$0.isArchived && !$0.isDeleted }
    }

    private var todayTodos: [Todo] {
        activeTodos.filter { todayFilter.includes($0) }
    }

    private var selectedDirection: Direction? {
        guard let id = activeFlowStore.selectedDirectionID else { return nil }
        return activeDirections.first { $0.id == id }
    }

    private var selectedTodo: Todo? {
        guard let id = activeFlowStore.selectedTodoID else { return nil }
        return activeTodos.first { $0.id == id }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(now: context.date)
                .onChange(of: context.date) { _, date in
                    activeFlowStore.refresh(modelContext: modelContext, now: date)
                }
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        VStack(spacing: 8) {
            if activeFlowStore.phase == .awaitingExtensionDecision {
                adaptiveDecisionBar
            } else if activeFlowStore.phase == .awaitingResult || activeFlowStore.isAwaitingBreakMemo {
                resultBar
            } else {
                if style == .dashboard {
                    dashboardPlayer(now: now)
                } else {
                    headerPlayer(now: now)
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
    }

    private func headerPlayer(now: Date) -> some View {
        HStack(spacing: 12) {
            taskPickerButton(now: now)
                .frame(minWidth: style == .dashboard ? 360 : 280, maxWidth: .infinity, alignment: .leading)

            modePickerButton
            timerCluster(now: now)
            transportControls
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

    private func dashboardPlayer(now: Date) -> some View {
        VStack(spacing: 18) {
            taskPickerButton(now: now)

            modePickerButton

            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: dashboardTimerProgress(now: now))
                    .stroke(
                        primaryButtonColor,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 5) {
                    Text(timerEyebrow)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(dashboardTimerText(now: now))
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .monospacedDigit()

                    Text(activeFlowStore.selectedMode.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 158, height: 158)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Flowタイマー")

            transportControls
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }

    private func dashboardTimerProgress(now: Date) -> Double {
        guard activeFlowStore.timerState != nil else { return 0 }
        return activeFlowStore.phaseProgress(now: now)
    }

    private func dashboardTimerText(now: Date) -> String {
        activeFlowStore.timerState == nil
            ? String(format: "%02d:00", activeFlowStore.selectedMode.initialFocusDurationSeconds / 60)
            : activeFlowStore.remainingText(now: now)
    }

    private func taskPickerButton(now: Date) -> some View {
        HStack(spacing: 8) {
            if let selectedTodo {
                TodoProgressControl(
                    todo: selectedTodo,
                    additionalFocusSeconds: liveSelectedTaskFocusSeconds(now: now)
                ) {
                    selectedTodo.setCompleted(!selectedTodo.isCompleted)
                    try? modelContext.save()
                }
            }

            HStack(spacing: 12) {
                playerArtwork

                contextLabel(now: now)

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .modifier(FlowTaskCardPressEffect())
            .onTapGesture {
                openTaskPicker()
            }
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: "Flowタスクを選択") {
                openTaskPicker()
            }
        }
        .padding(.leading, selectedTodo == nil ? 0 : 6)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.08))
        }
        .popover(isPresented: $showsTaskPicker, arrowEdge: .bottom) {
            FlowTaskPickerView(
                directions: activeDirections,
                todos: todayTodos,
                selectedDirectionID: activeFlowStore.selectedDirectionID,
                selectedTodoID: activeFlowStore.selectedTodoID
            ) { direction, todo in
                activeFlowStore.selectContext(
                    direction: direction,
                    todo: todo,
                    modelContext: modelContext
                )
            }
            .frame(width: 520, height: 460)
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

    private var modePickerButton: some View {
        Button {
            showsModePicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: modeIconName(activeFlowStore.selectedMode))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(modeIconColor(activeFlowStore.selectedMode))
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 1) {
                    Text(activeFlowStore.selectedMode.displayName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    Text(modeSubtitle(activeFlowStore.selectedMode))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: style == .dashboard ? 220 : 190, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.primary.opacity(0.08))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Focusを選択")
        .disabled(activeFlowStore.timerState != nil)
        .popover(isPresented: $showsModePicker, arrowEdge: .bottom) {
            FlowModePickerView(
                selectedMode: $activeFlowStore.selectedMode,
                modes: selectableModes
            )
            .frame(width: 320)
        }
    }

    private func timerCluster(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(timerEyebrow)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(activeFlowStore.timerState == nil ? activeFlowStore.selectedMode.shortDurationText : activeFlowStore.remainingText(now: now))
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
        .accessibilityLabel(activeFlowStore.timerState == nil ? "Flow未開始" : "残り時間 \(activeFlowStore.remainingText(now: now))")
    }

    private var timerEyebrow: String {
        switch activeFlowStore.phase {
        case .focusing:
            "集中"
        case .paused:
            "一時停止"
        case .breakTime:
            "休憩"
        default:
            "待機中"
        }
    }

    private var playerArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(artworkColor.opacity(0.18))

            Text(flowDirection?.symbolName ?? "▶")
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

            Text(flowDirectionName)
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
            TextField(TodoDisplay.placeholder(for: selectedTodo), text: $taskTitleDraft)
                .textFieldStyle(.plain)
                .font(.headline)
                .focused($isTaskTitleFocused)
                .onSubmit(commitTaskTitle)
                .onExitCommand(perform: cancelTaskTitleEdit)
                .accessibilityLabel("タスク名")
        } else {
            Text(flowTaskTitle)
                .font(contextTitleFont)
                .foregroundStyle(flowTaskTitleIsPlaceholder ? Color.secondary.opacity(0.7) : Color.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                .accessibilityAction(named: "タスク名を編集") {
                    beginTaskTitleEdit()
                }
                .accessibilityLabel("タスク名")
        }
    }

    private func dismissTaskTitleEditor() {
        guard editingTaskTitleID != nil else { return }

        isTaskTitleFocused = false
#if os(macOS)
        NSApp.keyWindow?.makeFirstResponder(nil)
#endif
    }

    private func openTaskPicker() {
        if editingTaskTitleID != nil {
            commitTaskTitle()
        }
        showsTaskPicker = true
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

    private func commitTaskTitle() {
        guard let selectedTodo, editingTaskTitleID == selectedTodo.id else {
            cancelTaskTitleEdit()
            return
        }

        let normalizedTitle = taskTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedTodo.title != normalizedTitle {
            selectedTodo.title = normalizedTitle
            selectedTodo.updatedAt = .now
            try? modelContext.save()
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
        activeFlowStore.phase == .focusing || activeFlowStore.phase == .paused
    }

    private var flowDirection: Direction? {
        if let direction = selectedTodo?.direction {
            return direction
        }

        return selectedDirection
    }

    private var flowTaskTitle: String {
        if let selectedTodo {
            return TodoDisplay.title(for: selectedTodo)
        }

        if let selectedDirection {
            return "(\(selectedDirection.name))"
        }

        return "具体的なタスクなし"
    }

    private var flowTaskTitleIsPlaceholder: Bool {
        if let selectedTodo {
            return selectedTodo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return selectedDirection != nil
    }

    private var contextTitleFont: Font {
        let font: Font = .headline
        return flowTaskTitleIsPlaceholder ? font.italic() : font
    }

    private var flowDirectionName: String {
        flowDirection?.name ?? "その他"
    }

    private var artworkColor: Color {
        if let direction = flowDirection, !DefaultDirections.isTaskInbox(direction) {
            return Color(hex: direction.colorHex)
        }

        return .accentColor
    }

    private func todoRemainingText(_ todo: Todo, additionalFocusSeconds: Int) -> String {
        let displayedFocusSeconds = todo.recordedFocusSeconds + max(0, additionalFocusSeconds)

        switch todo.measurement {
        case .checkbox:
            return todo.isCompleted ? "完了" : "未完了"
        case .focusBlocks:
            let planned = Double(todo.plannedAmount ?? 0)
            let remaining = max(0, planned - BlockUnit.blocks(forFocusedSeconds: displayedFocusSeconds))
            let value = remaining == remaining.rounded() ? String(Int(remaining)) : String(format: "%.1f", remaining)
            return "残り \(value) Block"
        case .minutes:
            let remainingSeconds = max(0, (todo.plannedAmount ?? 0) * 60 - displayedFocusSeconds)
            return "残り \(Int(ceil(Double(remainingSeconds) / 60)))分"
        }
    }

    private func liveSelectedTaskFocusSeconds(now: Date) -> Int {
        guard activeFlowStore.phase == .focusing || activeFlowStore.phase == .paused,
              let selectedTodo,
              let segment = activeFlowStore.activeSession?.segments.last(where: { $0.endedAt == nil }),
              segment.todo?.id == selectedTodo.id else {
            return 0
        }

        return max(0, activeFlowStore.actualFocusSeconds(now: now) - segment.startFocusSeconds)
    }

    private var transportControls: some View {
        HStack(spacing: 6) {
            if style == .dashboard {
                compactControlSlot(isEnabled: activeFlowStore.timerState != nil) {
                    destroyButton
                }

                compactControlSlot(isEnabled: activeFlowStore.timerState != nil) {
                    stopButton
                }

                compactControlSlot(isEnabled: activeFlowStore.phase == .focusing) {
                    breakButton
                }

                compactControlSlot(isEnabled: canSeek) {
                    seekBackwardButton
                }

                primaryButton

                compactControlSlot(isEnabled: canSeek) {
                    seekForwardButton
                }
            } else {
                if activeFlowStore.timerState != nil {
                    destroyButton
                    stopButton
                }

                if activeFlowStore.phase == .focusing {
                    breakButton
                }

                if canSeek {
                    seekBackwardButton
                }

                primaryButton

                if canSeek {
                    seekForwardButton
                }
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.06))
        .clipShape(Capsule())
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
            Image(systemName: "gobackward.minus")
                .font(.callout.weight(.semibold))
                .frame(width: controlButtonSize, height: controlButtonSize)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel("ブロックを短縮")
    }

    private var seekForwardButton: some View {
        Button {
            activeFlowStore.seekForward(modelContext: modelContext)
        } label: {
            Image(systemName: "goforward.plus")
                .font(.callout.weight(.semibold))
                .frame(width: controlButtonSize, height: controlButtonSize)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel("ブロックを延長")
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
        .accessibilityLabel("Flowを停止して保存")
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
        .accessibilityLabel("休憩を開始")
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
        .accessibilityLabel("Flowを破壊")
    }

    private var primaryButton: some View {
        Button {
            handlePrimaryAction()
        } label: {
            if style == .dashboard {
                Image(systemName: primaryButtonImage)
                    .font(.title3.weight(.semibold))
                    .frame(width: primaryControlButtonSize, height: primaryControlButtonSize)
                    .background(primaryButtonColor)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            } else {
                Label(primaryButtonTitle, systemImage: primaryButtonImage)
                    .font(.headline.weight(.semibold))
                    .frame(width: 142, height: 44)
                    .background(primaryButtonColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(primaryButtonTitle)
    }

    private var primaryButtonTitle: String {
        switch activeFlowStore.phase {
        case .idle, .configured:
            "Flowを開始"
        case .focusing:
            activeFlowStore.isFocusOvertime(now: activeFlowStore.displayDate) ? "休憩" : "一時停止"
        case .paused:
            "再開"
        case .breakTime:
            "スキップ"
        case .awaitingExtensionDecision:
            "完了"
        case .awaitingResult:
            "保存"
        case .completed:
            "Flowを開始"
        }
    }

    private var primaryButtonImage: String {
        switch activeFlowStore.phase {
        case .focusing:
            activeFlowStore.isFocusOvertime(now: activeFlowStore.displayDate) ? "cup.and.saucer.fill" : "pause.fill"
        case .breakTime:
            "forward.fill"
        case .awaitingResult:
            "checkmark"
        default:
            "play.fill"
        }
    }

    private var primaryButtonColor: Color {
        switch activeFlowStore.phase {
        case .focusing:
            activeFlowStore.isFocusOvertime(now: activeFlowStore.displayDate) ? .blue : artworkColor
        case .paused:
            .green
        case .breakTime:
            .blue
        default:
            artworkColor
        }
    }

    private var adaptiveDecisionBar: some View {
        HStack(spacing: 10) {
            Text("次を選択")
                .font(.headline)

            Spacer()

            if activeFlowStore.timerState?.nextAdaptiveFocusDurationSeconds != nil {
                Button("+\(adaptiveExtensionMinutes)分") {
                    activeFlowStore.extendAdaptive(modelContext: modelContext)
                }
            }

            Button("休憩") {
                activeFlowStore.requestBreakMemo(modelContext: modelContext)
            }

            Button("終了") {
                activeFlowStore.finish(modelContext: modelContext)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var resultBar: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("何をしましたか", text: $resultText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(2...5)

            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "note.text")
                        .imageScale(.small)
                    Text("メモ")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Text(activeFlowStore.remainingText(now: activeFlowStore.displayDate))
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                if activeFlowStore.isAwaitingBreakMemo {
                    Button("キャンセル") {
                        cancelBreakMemo()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("メモ入力をキャンセル")
                }

                Button("メモなし") {
                    submitWithoutResult()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("メモなしで続ける")

                Button {
                    submitResult()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline.weight(.semibold))
                        .frame(width: 38, height: 38)
                        .background(resultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary.opacity(0.35) : Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("メモを保存")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.primary.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.primary.opacity(0.12))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
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
            let direction = resolvedStartDirection()
            let todo = selectedTodo

            activeFlowStore.configure(direction: direction, todo: todo)
            activeFlowStore.start(
                direction: direction,
                todo: todo,
                modelContext: modelContext
            )
        case .focusing:
            if activeFlowStore.isFocusOvertime(now: activeFlowStore.displayDate) {
                activeFlowStore.requestBreakMemo(modelContext: modelContext)
            } else {
                activeFlowStore.pause(modelContext: modelContext)
            }
        case .paused:
            activeFlowStore.resume(modelContext: modelContext)
        case .breakTime:
            activeFlowStore.skipBreak(modelContext: modelContext)
        case .awaitingExtensionDecision:
            activeFlowStore.finish(modelContext: modelContext)
        case .awaitingResult:
            submitResult()
        }
    }

    private func submitResult() {
        if activeFlowStore.isAwaitingBreakMemo {
            activeFlowStore.completeBreakMemo(resultText, modelContext: modelContext)
        } else {
            activeFlowStore.completeResult(resultText, modelContext: modelContext)
        }
        resultText = ""
    }

    private func submitWithoutResult() {
        resultText = ""
        if activeFlowStore.isAwaitingBreakMemo {
            activeFlowStore.completeBreakMemo(nil, modelContext: modelContext)
        } else {
            activeFlowStore.completeResult(nil, modelContext: modelContext)
        }
    }

    private func cancelBreakMemo() {
        resultText = ""
        activeFlowStore.cancelBreakMemo()
    }

    private func resolvedStartDirection() -> Direction {
        if let selectedDirection {
            return selectedDirection
        }

        if let direction = selectedTodo?.direction, !direction.isArchived {
            return direction
        }

        if let taskInbox = DefaultDirections.existingTaskInbox(in: activeDirections) {
            return taskInbox
        }

        let taskInbox = DefaultDirections.makeTaskInbox()
        modelContext.insert(taskInbox)
        return taskInbox
    }

    private var selectableModes: [FlowMode] {
        [.twelveThree, .twentyFiveFive, .fiftyTen]
    }

    private func modeIconName(_ mode: FlowMode) -> String {
        switch mode {
        case .twelveThree:
            "flame.fill"
        case .twentyFiveFive:
            "target"
        case .fiftyTen:
            "mountain.2.fill"
        case .adaptive:
            "sparkles"
        }
    }

    private func modeIconColor(_ mode: FlowMode) -> Color {
        switch mode {
        case .twelveThree:
            .orange
        case .twentyFiveFive:
            .blue
        case .fiftyTen:
            .purple
        case .adaptive:
            .teal
        }
    }

    private func modeSubtitle(_ mode: FlowMode) -> String {
        switch mode {
        case .twelveThree:
            "12分作業 / 3分休憩"
        case .twentyFiveFive:
            "25分作業 / 5分休憩"
        case .fiftyTen:
            "50分作業 / 10分休憩"
        case .adaptive:
            "12分から開始"
        }
    }

    private func todoMenuTitle(_ todo: Todo) -> String {
        if todo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return TodoDisplay.title(for: todo)
        }

        let taskText = TodoDisplay.title(for: todo)

        guard let direction = todo.direction else {
            return taskText
        }

        guard !DefaultDirections.isTaskInbox(direction) else {
            return taskText
        }

        return "\(taskText)（\(direction.name)）"
    }
}

private struct FlowTaskPickerView: View {
    let directions: [Direction]
    let todos: [Todo]
    let selectedDirectionID: UUID?
    let selectedTodoID: UUID?
    let onSelect: (Direction?, Todo?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: FlowTaskPickerTab = .tasks
    @State private var showsTaskComposer = false

    private var taskGroups: [FlowTaskPickerGroup] {
        FlowTaskPickerGroup.groups(for: todos.filter { $0.direction?.type != .habit })
    }

    private var habitTodos: [Todo] {
        todos
            .filter { $0.direction?.type == .habit }
            .sorted(by: FlowTaskPickerGroup.sortTodos)
    }

    private var otherDirection: Direction? {
        DefaultDirections.existingTaskInbox(in: directions)
    }

    private var userDirections: [Direction] {
        directions
            .filter { !DefaultDirections.isTaskInbox($0) }
            .sorted {
                if $0.type != $1.type {
                    return FlowTaskPickerGroup.order.firstIndex(of: $0.type) ?? 0 <
                        FlowTaskPickerGroup.order.firstIndex(of: $1.type) ?? 0
                }

                if $0.sortIndex != $1.sortIndex {
                    return $0.sortIndex < $1.sortIndex
                }

                return $0.name < $1.name
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Flowタスク")
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

            Picker("表示", selection: $selectedTab) {
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
                case .directions:
                    directionTab
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
                showsTaskComposer = true
            } label: {
                Label("タスクを追加", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                    .padding(.horizontal, 12)
                    .background(Color.accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showsTaskComposer, arrowEdge: .trailing) {
                QuickTodoCreationPopover(directions: directions) { todo in
                    onSelect(todo.direction, todo)
                }
            }

            if taskGroups.isEmpty {
                emptyState("今日のタスクはありません")
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
            emptyState("今日の習慣はありません")
        } else {
            VStack(spacing: 7) {
                ForEach(habitTodos) { todo in
                    taskRow(todo)
                }
            }
            .padding(.top, 2)
        }
    }

    private var directionTab: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 120, maximum: 170), spacing: 10)],
            alignment: .leading,
            spacing: 10
        ) {
            directionGridItem(
                iconText: otherDirection?.symbolName ?? DefaultDirections.taskInboxSymbol,
                title: otherDirection?.name ?? "その他",
                color: .secondary,
                isSelected: selectedTodoID == nil && (selectedDirectionID == otherDirection?.id || selectedDirectionID == nil)
            ) {
                onSelect(otherDirection, nil)
                dismiss()
            }

            ForEach(userDirections) { direction in
                directionGridItem(
                    iconText: direction.symbolName,
                    title: direction.name,
                    color: Color(hex: direction.colorHex),
                    isSelected: selectedTodoID == nil && selectedDirectionID == direction.id
                ) {
                    onSelect(direction, nil)
                    dismiss()
                }
            }
        }
        .padding(.top, 2)
    }

    private func taskRow(_ todo: Todo) -> some View {
        Button {
            onSelect(todo.direction, todo)
            dismiss()
        } label: {
            pickerRow(
                iconText: todo.direction?.symbolName ?? DefaultDirections.taskInboxSymbol,
                title: TodoDisplay.title(for: todo),
                subtitle: taskSubtitle(todo),
                color: directionColor(todo.direction),
                isSelected: selectedTodoID == todo.id,
                isPlaceholder: todo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        .buttonStyle(.plain)
    }

    private func directionGridItem(
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

    private func directionColor(_ direction: Direction?) -> Color {
        guard let direction, !DefaultDirections.isTaskInbox(direction) else {
            return .secondary
        }

        return Color(hex: direction.colorHex)
    }

    private func taskSubtitle(_ todo: Todo) -> String {
        let directionName = todo.direction?.name ?? "その他"
        let priority = todo.priority == .low && todo.isRoomIfPossible ? "余裕があれば" : todo.priority.displayName
        return "\(directionName) ・ \(priority)"
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
    case directions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tasks:
            "タスク"
        case .habits:
            "習慣"
        case .directions:
            "方向"
        }
    }
}

private struct FlowTaskPickerGroup: Identifiable {
    static let order: [DirectionType] = [.habit, .neutral, .nice]

    let type: DirectionType
    let todos: [Todo]

    var id: String { type.rawValue }

    var title: String {
        switch type {
        case .habit:
            "習慣"
        case .neutral:
            "通常"
        case .nice:
            "ナイス"
        }
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

    static func groups(for todos: [Todo]) -> [FlowTaskPickerGroup] {
        order.compactMap { type in
            let items = todos
                .filter { ($0.direction?.type ?? .neutral) == type }
                .sorted(by: sortTodos)

            guard !items.isEmpty else { return nil }
            return FlowTaskPickerGroup(type: type, todos: items)
        }
    }

    nonisolated static func sortTodos(_ lhs: Todo, _ rhs: Todo) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted
        }

        if lhs.sortIndex != rhs.sortIndex {
            return lhs.sortIndex < rhs.sortIndex
        }

        return lhs.createdAt < rhs.createdAt
    }
}

private struct FlowTaskCardPressEffect: ViewModifier {
    @GestureState private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.985 : 1)
            .opacity(isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.12), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in
                        state = true
                    }
            )
    }
}

private struct FlowModePickerView: View {
    @Binding var selectedMode: FlowMode
    let modes: [FlowMode]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Focus")
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

            ForEach(modes) { mode in
                Button {
                    selectedMode = mode
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: iconName(mode))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(iconColor(mode))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(mode.displayName)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text(subtitle(mode))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)

                        if selectedMode == mode {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                    .padding(10)
                    .background(selectedMode == mode ? iconColor(mode).opacity(0.14) : Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(selectedMode == mode ? iconColor(mode).opacity(0.42) : Color.primary.opacity(0.08))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(.bar)
    }

    private func iconName(_ mode: FlowMode) -> String {
        switch mode {
        case .twelveThree:
            "flame.fill"
        case .twentyFiveFive:
            "target"
        case .fiftyTen:
            "mountain.2.fill"
        case .adaptive:
            "sparkles"
        }
    }

    private func iconColor(_ mode: FlowMode) -> Color {
        switch mode {
        case .twelveThree:
            .orange
        case .twentyFiveFive:
            .blue
        case .fiftyTen:
            .purple
        case .adaptive:
            .teal
        }
    }

    private func subtitle(_ mode: FlowMode) -> String {
        switch mode {
        case .twelveThree:
            "12分作業 / 3分休憩"
        case .twentyFiveFive:
            "25分作業 / 5分休憩"
        case .fiftyTen:
            "50分作業 / 10分休憩"
        case .adaptive:
            "12分から開始"
        }
    }
}

#Preview {
    FlowMiniPlayerView()
        .environmentObject(ActiveFlowStore())
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self, FlowSegment.self], inMemory: true)
}
