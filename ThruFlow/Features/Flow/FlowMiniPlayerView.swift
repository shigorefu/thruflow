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

    private var activeDirections: [Direction] {
        directions.filter { !$0.isArchived }
    }

    private var activeTodos: [Todo] {
        todos.filter { !$0.isArchived && !$0.isDeleted }
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
                todos: activeTodos,
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
            }

            if activeFlowStore.phase == .awaitingResult {
                resultBar
            } else {
                HStack(spacing: 12) {
                    modeMenu

                    Button {
                        showsConfiguration = true
                    } label: {
                        contextLabel(now: now)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if activeFlowStore.timerState != nil {
                        Text(activeFlowStore.remainingText(now: now))
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .accessibilityLabel("残り時間 \(activeFlowStore.remainingText(now: now))")
                    }

                    primaryButton
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var modeMenu: some View {
        Menu {
            ForEach(FlowMode.allCases) { mode in
                Button {
                    activeFlowStore.selectedMode = mode
                } label: {
                    VStack(alignment: .leading) {
                        Text(mode.displayName)
                        Text(mode.blockSummary)
                    }
                }
            }
        } label: {
            Text(activeFlowStore.selectedMode.displayName)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.quaternary)
                .clipShape(Capsule())
        }
        .menuStyle(.button)
        .accessibilityLabel("Flowモード")
        .disabled(activeFlowStore.timerState != nil)
    }

    private func contextLabel(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let selectedDirection {
                Text("\(selectedDirection.symbolName) \(selectedDirection.name)")
                    .font(.headline)
                    .lineLimit(1)

                Text(selectedTodo?.title ?? "具体的なタスクなし")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("タスクを選択")
                    .font(.headline)

                Text("方向・タスク・意図")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var primaryButton: some View {
        Button {
            handlePrimaryAction()
        } label: {
            Label(primaryButtonTitle, systemImage: primaryButtonImage)
                .labelStyle(.iconOnly)
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
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
            "一時停止"
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
            "pause.fill"
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
            .orange
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
        HStack(spacing: 10) {
            TextField("結果を入力", text: $resultText)
                .textFieldStyle(.roundedBorder)

            Button("保存") {
                activeFlowStore.completeResult(resultText, modelContext: modelContext)
                resultText = ""
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
            guard let selectedDirection else {
                showsConfiguration = true
                return
            }

            activeFlowStore.start(
                direction: selectedDirection,
                todo: selectedTodo,
                modelContext: modelContext
            )
        case .focusing:
            activeFlowStore.pause(modelContext: modelContext)
        case .paused:
            activeFlowStore.resume(modelContext: modelContext)
        case .breakTime:
            activeFlowStore.skipBreak(modelContext: modelContext)
        case .awaitingExtensionDecision:
            activeFlowStore.finish(modelContext: modelContext)
        case .awaitingResult:
            activeFlowStore.completeResult(resultText, modelContext: modelContext)
            resultText = ""
        }
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
        guard let selectedDirectionID else { return [] }
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

                    section("タスク") {
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
