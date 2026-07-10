//
//  FlowHistoryInspectorView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/11.
//

import SwiftData
import SwiftUI

struct FlowHistoryInspectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Direction.sortIndex) private var directions: [Direction]
    @Query(sort: \Todo.updatedAt, order: .reverse) private var todos: [Todo]

    let session: FlowSession

    @State private var selectedTodoID: UUID?
    @State private var selectedDirectionID: UUID?
    @State private var focusMinutes: Int
    @State private var memo: String
    @State private var showsDeleteConfirmation = false

    private let editor = FlowHistoryEditor()

    init(session: FlowSession) {
        self.session = session
        _selectedTodoID = State(initialValue: session.todo?.id)
        _selectedDirectionID = State(initialValue: session.direction?.id)
        _focusMinutes = State(initialValue: max(1, Int((Double(session.resolvedActualFocusDurationSeconds) / 60).rounded())))
        _memo = State(initialValue: session.todo?.notes ?? "")
    }

    private var selectedTodo: Todo? {
        guard let selectedTodoID else { return nil }
        return todos.first { $0.id == selectedTodoID }
    }

    private var selectedDirection: Direction? {
        if let direction = selectedTodo?.direction {
            return direction
        }
        guard let selectedDirectionID else { return nil }
        return directions.first { $0.id == selectedDirectionID }
    }

    private var availableDirections: [Direction] {
        directions.filter { !$0.isArchived }
    }

    private var availableTodos: [Todo] {
        todos.filter { !$0.isDeleted && !$0.isArchived }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Flowを編集")
                        .font(.title3.weight(.semibold))
                    Text(dateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("閉じる")
            }
            .padding(18)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    field("タスク") {
                        Picker("タスク", selection: $selectedTodoID) {
                            Text("タスクなし").tag(UUID?.none)
                            ForEach(availableTodos) { todo in
                                Text("\(todo.direction?.symbolName ?? "📥") \(TodoDisplay.title(for: todo))")
                                    .tag(Optional(todo.id))
                            }
                        }
                        .labelsHidden()
                    }

                    field("方向") {
                        Picker("方向", selection: $selectedDirectionID) {
                            ForEach(availableDirections) { direction in
                                Text("\(direction.symbolName) \(direction.name)")
                                    .tag(Optional(direction.id))
                            }
                        }
                        .labelsHidden()
                        .disabled(selectedTodo != nil)
                    }

                    field("集中時間") {
                        Stepper(value: $focusMinutes, in: 1...720) {
                            Text("\(focusMinutes)分")
                                .monospacedDigit()
                        }
                    }

                    field("メモ") {
                        TextEditor(text: $memo)
                            .frame(minHeight: 92)
                            .padding(8)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .disabled(selectedTodo == nil)

                        if selectedTodo == nil {
                            Text("メモはタスクに保存されます。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button(role: .destructive) {
                        showsDeleteConfirmation = true
                    } label: {
                        Label("このFlowを削除", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(18)
            }

            Divider()

            HStack {
                Button("キャンセル") {
                    dismiss()
                }

                Spacer()

                Button("保存") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedDirection == nil)
            }
            .padding(18)
        }
        .frame(minWidth: 460, idealWidth: 520, minHeight: 500, idealHeight: 560)
        .onChange(of: selectedTodoID) { _, newValue in
            guard let newValue, let todo = todos.first(where: { $0.id == newValue }) else {
                memo = ""
                return
            }

            selectedDirectionID = todo.direction?.id
            memo = todo.notes ?? ""
        }
        .confirmationDialog(
            "このFlowを削除しますか？",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                editor.delete(session: session, modelContext: modelContext)
                try? modelContext.save()
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("方向とタスクの集中時間から、このFlowの分を差し引きます。")
        }
    }

    @ViewBuilder
    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: session.startedAt)
    }

    private func save() {
        guard let selectedDirection else { return }
        editor.update(
            session: session,
            todo: selectedTodo,
            direction: selectedDirection,
            focusSeconds: focusMinutes * 60,
            memo: memo
        )
        try? modelContext.save()
        dismiss()
    }
}
