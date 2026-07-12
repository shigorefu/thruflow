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
        case compact
        case dashboard
    }

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Direction.name, order: .forward) private var directions: [Direction]
    @Query(sort: \Todo.createdAt, order: .forward) private var todos: [Todo]

    @State private var showsTaskPicker = false
    @State private var showsModePicker = false
    @State private var resultText = ""

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
                if style == .compact {
                    compactMenuBarPlayer(now: now)
                } else {
                    headerPlayer(now: now)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func headerPlayer(now: Date) -> some View {
        HStack(spacing: 12) {
            taskPickerButton
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

    private func compactMenuBarPlayer(now: Date) -> some View {
        HStack(spacing: 10) {
            taskPickerButton
                .frame(width: 168, alignment: .leading)

            modePickerButton

            timerCluster(now: now)

            transportControls
                .frame(width: 210, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.08))
        }
        .shadow(color: .black.opacity(0.10), radius: 14, y: 5)
    }

    private var taskPickerButton: some View {
        Button {
            showsTaskPicker = true
        } label: {
            HStack(spacing: 12) {
                playerArtwork
                contextLabel

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, style == .compact ? 10 : 14)
            .padding(.vertical, style == .compact ? 8 : 10)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.primary.opacity(0.08))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Flowタスクを選択")
        .popover(isPresented: $showsTaskPicker, arrowEdge: .bottom) {
            FlowTaskPickerView(
                directions: activeDirections,
                todos: todayTodos,
                selectedDirectionID: $activeFlowStore.selectedDirectionID,
                selectedTodoID: $activeFlowStore.selectedTodoID
            )
            .frame(width: style == .compact ? 430 : 520, height: 460)
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

                    Text(style == .compact ? activeFlowStore.selectedMode.shortDurationText : modeSubtitle(activeFlowStore.selectedMode))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: style == .compact ? 94 : 190, alignment: .leading)
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
                    .font(.system(style == .compact ? .body : .title2, design: .monospaced).weight(.bold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                if style != .compact && activeFlowStore.timerState != nil {
                    Text("/ \(activeFlowStore.selectedMode.initialFocusDurationSeconds / 60):00")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .frame(width: style == .compact ? 58 : 130, alignment: .leading)
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
        .frame(width: style == .compact ? 34 : 42, height: style == .compact ? 34 : 42)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(artworkColor.opacity(0.24))
        }
        .accessibilityHidden(true)
    }

    private var contextLabel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(flowTaskTitle)
                .font(contextTitleFont)
                .foregroundStyle(flowTaskTitleIsPlaceholder ? Color.secondary.opacity(0.7) : Color.primary)
                .lineLimit(1)

            Text(flowDirectionName)
                .font(style == .compact ? .caption2 : .subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
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
        let font: Font = style == .compact ? .caption.weight(.semibold) : .headline
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

    private var transportControls: some View {
        HStack(spacing: style == .compact ? 4 : 6) {
            if style == .compact {
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
        .padding(style == .compact ? 2 : 3)
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
        style == .compact ? 30 : 34
    }

    private var primaryControlButtonSize: CGFloat {
        style == .compact ? 36 : 42
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
            if style == .compact {
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

    @Binding var selectedDirectionID: UUID?
    @Binding var selectedTodoID: UUID?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: FlowTaskPickerTab = .tasks

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
        .onChange(of: selectedDirectionID) { _, _ in
            if !todos.contains(where: { $0.id == selectedTodoID }) {
                selectedTodoID = nil
            }
        }
        .onChange(of: selectedTodoID) { _, id in
            guard selectedDirectionID == nil,
                  let id,
                  let todo = todos.first(where: { $0.id == id }) else {
                return
            }

            selectedDirectionID = todo.direction?.id
        }
    }

    @ViewBuilder
    private var taskTab: some View {
        if taskGroups.isEmpty {
            emptyState("今日のタスクはありません")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(taskGroups) { group in
                    sectionHeader(title: group.title, count: group.todos.count, tint: group.tint)

                    VStack(spacing: 7) {
                        ForEach(group.todos) { todo in
                            taskRow(todo)
                        }
                    }
                }
            }
            .padding(.top, 2)
        }
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
                selectedTodoID = nil
                selectedDirectionID = otherDirection?.id
                dismiss()
            }

            ForEach(userDirections) { direction in
                directionGridItem(
                    iconText: direction.symbolName,
                    title: direction.name,
                    color: Color(hex: direction.colorHex),
                    isSelected: selectedTodoID == nil && selectedDirectionID == direction.id
                ) {
                    selectedTodoID = nil
                    selectedDirectionID = direction.id
                    dismiss()
                }
            }
        }
        .padding(.top, 2)
    }

    private func taskRow(_ todo: Todo) -> some View {
        Button {
            selectedTodoID = todo.id
            selectedDirectionID = todo.direction?.id
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
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self], inMemory: true)
}
