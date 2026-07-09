//
//  FlowMiniPlayerView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import SwiftData
import SwiftUI

struct FlowMiniPlayerView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Direction.name, order: .forward) private var directions: [Direction]
    @Query(sort: \Todo.createdAt, order: .forward) private var todos: [Todo]

    @State private var showsTaskPicker = false
    @State private var resultText = ""

    private let todayFilter = TodayTodoFilter()

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
        .sheet(isPresented: $showsTaskPicker) {
            FlowTaskPickerView(
                directions: visibleDirections,
                todos: todayTodos,
                selectedDirectionID: $activeFlowStore.selectedDirectionID,
                selectedTodoID: $activeFlowStore.selectedTodoID
            )
#if os(macOS)
            .frame(minWidth: 520, minHeight: 440)
#endif
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
                HStack(spacing: 12) {
                    Button {
                        showsTaskPicker = true
                    } label: {
                        HStack(spacing: 10) {
                            playerArtwork
                            contextLabel
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.primary.opacity(0.08))
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 300, alignment: .leading)
                    .accessibilityLabel("Flowタスクを選択")

                    focusModeCards

                    Divider()
                        .frame(height: 54)

                    timerCluster(now: now)

                    transportControls
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.primary.opacity(0.08))
                }
                .shadow(color: .black.opacity(0.10), radius: 14, y: 5)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var focusModeCards: some View {
        HStack(spacing: 8) {
            ForEach(selectableModes) { mode in
                modeCard(mode)
            }
        }
    }

    private func modeCard(_ mode: FlowMode) -> some View {
        Button {
            activeFlowStore.selectedMode = mode
        } label: {
            HStack(spacing: 10) {
                Image(systemName: modeIconName(mode))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(modeIconColor(mode))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(modeSubtitle(mode))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 170, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(mode == activeFlowStore.selectedMode ? modeIconColor(mode).opacity(0.20) : Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(mode == activeFlowStore.selectedMode ? modeIconColor(mode).opacity(0.48) : Color.primary.opacity(0.08))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.displayName)を選択")
        .disabled(activeFlowStore.timerState != nil)
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

    private var contextLabel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(flowTaskTitle)
                .font(.headline)
                .lineLimit(1)

            Text(flowDirectionName)
                .font(.subheadline)
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
        HStack(spacing: 6) {
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
        .padding(3)
        .background(Color.primary.opacity(0.06))
        .clipShape(Capsule())
    }

    private var seekBackwardButton: some View {
        Button {
            activeFlowStore.seekBackward(modelContext: modelContext)
        } label: {
            Image(systemName: "gobackward.minus")
                .font(.callout.weight(.semibold))
                .frame(width: 34, height: 34)
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
                .frame(width: 34, height: 34)
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
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Flowを停止して保存")
    }

    private var breakButton: some View {
        Button {
            activeFlowStore.requestBreakMemo()
        } label: {
            Image(systemName: "cup.and.saucer.fill")
                .font(.callout.weight(.semibold))
                .frame(width: 34, height: 34)
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
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.red)
        .accessibilityLabel("Flowを破壊")
    }

    private var primaryButton: some View {
        Button {
            handlePrimaryAction()
        } label: {
            Label(primaryButtonTitle, systemImage: primaryButtonImage)
                .font(.headline.weight(.semibold))
                .frame(width: 142, height: 44)
                .background(primaryButtonColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
            activeFlowStore.isFocusOvertime(now: activeFlowStore.displayDate) ? .blue : .orange
        case .paused:
            .green
        case .breakTime:
            .blue
        default:
            .accentColor
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
                activeFlowStore.requestBreakMemo()
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
                activeFlowStore.requestBreakMemo()
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

    private var filteredTodos: [Todo] {
        guard let selectedDirectionID else { return todos }
        return todos.filter { $0.direction?.id == selectedDirectionID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Button {
                        selectedDirectionID = nil
                        selectedTodoID = nil
                        dismiss()
                    } label: {
                        pickerRow(
                            icon: "tray",
                            title: "具体的なタスクなし",
                            subtitle: "自動: その他",
                            color: .secondary,
                            isSelected: selectedTodoID == nil && selectedDirectionID == nil
                        )
                    }
                    .buttonStyle(.plain)

                    section("今日のタスク") {
                        if filteredTodos.isEmpty {
                            Text("今日のタスクはありません")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(filteredTodos) { todo in
                                    Button {
                                        selectedTodoID = todo.id
                                        selectedDirectionID = todo.direction?.id
                                        dismiss()
                                    } label: {
                                        pickerRow(
                                            iconText: todo.direction?.symbolName ?? "・",
                                            title: TodoDisplay.title(for: todo),
                                            subtitle: todo.direction?.name ?? "その他",
                                            color: directionColor(todo.direction),
                                            isSelected: selectedTodoID == todo.id
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    section("方向だけ選ぶ") {
                        VStack(spacing: 8) {
                            ForEach(directions) { direction in
                                Button {
                                    selectedDirectionID = direction.id
                                    selectedTodoID = nil
                                    dismiss()
                                } label: {
                                    pickerRow(
                                        iconText: direction.symbolName,
                                        title: "(\(direction.name))",
                                        subtitle: direction.name,
                                        color: Color(hex: direction.colorHex),
                                        isSelected: selectedTodoID == nil && selectedDirectionID == direction.id
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Flowタスク")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedDirectionID) { _, _ in
                if !filteredTodos.contains(where: { $0.id == selectedTodoID }) {
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
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pickerRow(
        icon: String? = nil,
        iconText: String? = nil,
        title: String,
        subtitle: String,
        color: Color,
        isSelected: Bool
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.16))

                if let iconText {
                    Text(iconText)
                        .font(.title3)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(color)
                }
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
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
}

#Preview {
    FlowMiniPlayerView()
        .environmentObject(ActiveFlowStore())
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self], inMemory: true)
}
