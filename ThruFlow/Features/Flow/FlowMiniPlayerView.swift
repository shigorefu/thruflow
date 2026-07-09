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

    @State private var showsConfiguration = false
    @State private var resultText = ""

    private let todayFilter = TodayTodoFilter()

    private var activeDirections: [Direction] {
        directions.filter { !$0.isArchived }
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
        .sheet(isPresented: $showsConfiguration) {
            FlowConfigurationView(
                directions: activeDirections,
                todos: todayTodos,
                selectedDirectionID: $activeFlowStore.selectedDirectionID,
                selectedTodoID: $activeFlowStore.selectedTodoID,
                selectedMode: $activeFlowStore.selectedMode,
                intent: $activeFlowStore.intent
            )
#if os(macOS)
            .frame(minWidth: 560, minHeight: 460)
#endif
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        VStack(spacing: 8) {
            if activeFlowStore.phase == .awaitingExtensionDecision {
                adaptiveDecisionBar
            } else if activeFlowStore.phase == .awaitingResult {
                resultBar
            } else {
                HStack(spacing: 12) {
                    Button {
                        showsConfiguration = true
                    } label: {
                        playerArtwork
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Flow設定を開く")

                    Button {
                        showsConfiguration = true
                    } label: {
                        contextLabel
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    modeMenu

                    if activeFlowStore.timerState != nil {
                        Text(activeFlowStore.remainingText(now: now))
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(minWidth: 54, alignment: .trailing)
                            .accessibilityLabel("残り時間 \(activeFlowStore.remainingText(now: now))")
                    }

                    todayTaskMenu

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

    private var modeMenu: some View {
        Menu {
            ForEach(FlowMode.allCases) { mode in
                Button {
                    activeFlowStore.selectedMode = mode
                } label: {
                    VStack(alignment: .leading) {
                        Text("\(mode.displayName) \(mode.shortDurationText)")
                        Text(mode.blockSummary)
                    }
                }
            }
        } label: {
            Text("\(activeFlowStore.selectedMode.displayName) \(activeFlowStore.selectedMode.shortDurationText)")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.08))
                .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Flowモード")
        .disabled(activeFlowStore.timerState != nil)
    }

    private var todayTaskMenu: some View {
        Menu {
            Button {
                activeFlowStore.selectedTodoID = nil
            } label: {
                menuRow(text: "タスクなし", isSelected: activeFlowStore.selectedTodoID == nil)
            }

            if !todayTodos.isEmpty {
                Divider()

                ForEach(todayTodos) { todo in
                    Button {
                        activeFlowStore.configure(direction: todo.direction, todo: todo)
                    } label: {
                        menuRow(text: todoMenuTitle(todo), isSelected: activeFlowStore.selectedTodoID == todo.id)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "checklist")
                    .imageScale(.small)
                Text(selectedTodo.map(todoMenuTitle) ?? "今日タスク")
                    .lineLimit(1)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.08))
            .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("今日のタスクを選択")
    }

    private var playerArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(artworkColor.opacity(0.18))

            Text(selectedDirection?.symbolName ?? selectedTodo?.direction?.symbolName ?? "▶")
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
            if let selectedDirection {
                Text("\(selectedDirection.symbolName) \(selectedDirection.name)")
                    .font(.headline)
                    .lineLimit(1)

                Text(selectedTodo?.title ?? "具体的なタスクなし")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if let selectedTodo {
                Text(selectedTodo.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(selectedTodo.direction?.name ?? "タスク")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("すぐ開始")
                    .font(.headline)

                Text("自動: タスク")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var canSeek: Bool {
        activeFlowStore.phase == .focusing || activeFlowStore.phase == .paused
    }

    private var artworkColor: Color {
        if let selectedDirection {
            return Color(hex: selectedDirection.colorHex)
        }

        if let direction = selectedTodo?.direction, !DefaultDirections.isTaskInbox(direction) {
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
                .labelStyle(.iconOnly)
                .font(.title3.weight(.semibold))
                .frame(width: 42, height: 42)
                .background(primaryButtonColor)
                .foregroundStyle(.white)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(primaryButtonTitle)
    }

    private var primaryButtonTitle: String {
        switch activeFlowStore.phase {
        case .idle, .configured:
            "開始"
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
            "開始"
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
                activeFlowStore.startBreak(modelContext: modelContext)
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
                Button {
                    showsConfiguration = true
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.medium))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Flow設定を開く")

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
                activeFlowStore.startBreak(modelContext: modelContext)
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
        activeFlowStore.completeResult(resultText, modelContext: modelContext)
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

    @ViewBuilder
    private func menuRow(text: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(text, systemImage: "checkmark")
        } else {
            Text(text)
        }
    }

    private func todoMenuTitle(_ todo: Todo) -> String {
        let title = todo.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let taskText = title.isEmpty ? "タスク" : title

        guard let direction = todo.direction else {
            return taskText
        }

        return "\(taskText)（\(direction.name)）"
    }
}

private struct FlowConfigurationView: View {
    let directions: [Direction]
    let todos: [Todo]

    @Binding var selectedDirectionID: UUID?
    @Binding var selectedTodoID: UUID?
    @Binding var selectedMode: FlowMode
    @Binding var intent: String

    @Environment(\.dismiss) private var dismiss

    private var filteredTodos: [Todo] {
        guard let selectedDirectionID else { return todos }
        return todos.filter { $0.direction?.id == selectedDirectionID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("方向") {
                        Picker("方向", selection: $selectedDirectionID) {
                            Text("未選択").tag(UUID?.none)

                            ForEach(directions) { direction in
                                Text("\(direction.symbolName) \(direction.name)")
                                    .tag(Optional(direction.id))
                            }
                        }
                        .pickerStyle(.inline)
                    }

                    section("記録するタスク（任意）") {
                        Picker("タスク", selection: $selectedTodoID) {
                            Text("具体的なタスクなし").tag(UUID?.none)

                            ForEach(filteredTodos) { todo in
                                Text(todo.title).tag(Optional(todo.id))
                            }
                        }
                        .pickerStyle(.inline)
                    }

                    section("モード") {
                        Picker("モード", selection: $selectedMode) {
                            ForEach(FlowMode.allCases) { mode in
                                Text("\(mode.displayName) ・ \(mode.blockSummary)")
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.inline)
                    }

                    section("意図") {
                        TextField("このFlowで進めること", text: $intent, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Flow")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
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
}

#Preview {
    FlowMiniPlayerView()
        .environmentObject(ActiveFlowStore())
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self], inMemory: true)
}
