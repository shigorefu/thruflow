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
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Direction.sortIndex) private var directions: [Direction]
    @Query(sort: \Todo.updatedAt, order: .reverse) private var todos: [Todo]

    let session: FlowSession
    let onClose: (() -> Void)?

    @State private var selectedTodoID: UUID?
    @State private var selectedDirectionID: UUID?
    @State private var timeDraft: FlowHistoryTimeDraft
    @State private var memo: String
    @State private var isCreatingTask = false
    @State private var createdTodo: Todo?
    @State private var showsDeleteConfirmation = false

    private let editor = FlowHistoryEditor()

    init(session: FlowSession, onClose: (() -> Void)? = nil) {
        self.session = session
        self.onClose = onClose
        _selectedTodoID = State(initialValue: session.todo?.id)
        _selectedDirectionID = State(initialValue: session.direction?.id)
        _timeDraft = State(initialValue: FlowHistoryTimeDraft(
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            focusSeconds: session.resolvedActualFocusDurationSeconds
        ))
        _memo = State(initialValue: session.result ?? session.todo?.notes ?? "")
    }

    private var selectedTodo: Todo? {
        guard let selectedTodoID else { return nil }
        return todos.first { $0.id == selectedTodoID }
            ?? (createdTodo?.id == selectedTodoID ? createdTodo : nil)
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
        var candidates = todos
        if let createdTodo, !candidates.contains(where: { $0.id == createdTodo.id }) {
            candidates.append(createdTodo)
        }

        return candidates
            .filter { todo in
                if todo.id == session.todo?.id { return true }
                guard !todo.isDeleted, !todo.isArchived else { return false }
                return TodayTodoFilter().includes(todo, on: session.startedAt)
            }
            .sorted {
                if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
                if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
                return $0.createdAt < $1.createdAt
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Flowを編集"))
                        .font(.title3.weight(.semibold))
                    Text(dateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    close()
                } label: {
                    Image(systemName: onClose == nil ? "xmark" : "chevron.left")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: onClose == nil ? "閉じる" : "戻る"))
            }
            .padding(18)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    field(String(localized: "タスク")) {
                        HStack(spacing: 10) {
                            Picker(String(localized: "タスク"), selection: $selectedTodoID) {
                                Text(String(localized: "タスクなし")).tag(UUID?.none)
                                ForEach(availableTodos) { todo in
                                    Text("\(todo.direction?.symbolName ?? "📥") \(TodoDisplay.title(for: todo))")
                                        .tag(Optional(todo.id))
                                }
                            }
                            .labelsHidden()

                            Button {
                                isCreatingTask = true
                            } label: {
                                Label(String(localized: "タスクを追加"), systemImage: "plus")
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedDirection == nil)
                        }
                    }

                    field(String(localized: "方向")) {
                        Picker(String(localized: "方向"), selection: $selectedDirectionID) {
                            ForEach(availableDirections) { direction in
                                Text("\(direction.symbolName) \(direction.name)")
                                    .tag(Optional(direction.id))
                            }
                        }
                        .labelsHidden()
                        .disabled(selectedTodo != nil)
                    }

                    field(String(localized: "時間")) {
                        HStack(alignment: .bottom, spacing: 12) {
                            timeField(String(localized: "開始")) {
                                DatePicker(
                                    String(localized: "開始"),
                                    selection: Binding(
                                        get: { timeDraft.startedAt },
                                        set: { timeDraft.setStartedAt($0) }
                                    ),
                                    displayedComponents: [.hourAndMinute]
                                )
                                .labelsHidden()
                            }

                            Text("–")
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 5)

                            timeField(String(localized: "終了")) {
                                DatePicker(
                                    String(localized: "終了"),
                                    selection: Binding(
                                        get: { timeDraft.endedAt },
                                        set: { timeDraft.setEndedAt($0) }
                                    ),
                                    displayedComponents: [.hourAndMinute]
                                )
                                .labelsHidden()
                            }

                            Spacer(minLength: 8)

                            timeField(String(localized: "集中")) {
                                HStack(spacing: 5) {
                                    TextField(
                                        String(localized: "分"),
                                        value: Binding(
                                            get: { timeDraft.focusMinutes },
                                            set: { timeDraft.setFocusMinutes($0) }
                                        ),
                                        format: .number
                                    )
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 68)
                                    .multilineTextAlignment(.trailing)

                                    Text(String(localized: "分"))
                                        .foregroundStyle(.secondary)
                                }
                                .monospacedDigit()
                            }
                        }
                    }

                    field(String(localized: "メモ")) {
                        TextEditor(text: $memo)
                            .frame(minHeight: 92)
                            .padding(8)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button(role: .destructive) {
                        showsDeleteConfirmation = true
                    } label: {
                        Label(String(localized: "このFlowを削除"), systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(18)
            }

            Divider()

            HStack {
                Button(String(localized: "キャンセル")) {
                    close()
                }

                Spacer()

                Button(String(localized: "保存")) {
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
                return
            }

            selectedDirectionID = todo.direction?.id
            if memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                memo = todo.notes ?? ""
            }
        }
        .confirmationDialog(
            String(localized: "このFlowを削除しますか？"),
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "削除"), role: .destructive) {
                editor.delete(session: session, modelContext: modelContext)
                try? modelContext.save()
                close()
            }
            Button(String(localized: "キャンセル"), role: .cancel) {}
        } message: {
            Text(String(localized: "方向とタスクの集中時間から、このFlowの分を差し引きます。"))
        }
        .sheet(isPresented: $isCreatingTask) {
            if let selectedDirection {
                TodoFormView(
                    mode: .create,
                    fixedDirection: selectedDirection,
                    scheduledDate: session.startedAt
                ) { todo in
                    createdTodo = todo
                    selectedTodoID = todo.id
                    selectedDirectionID = todo.direction?.id
                }
                .frame(minWidth: 480, idealWidth: 540, minHeight: 620, idealHeight: 700)
            }
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

    @ViewBuilder
    private func timeField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("yMdHm")
        return formatter.string(from: session.startedAt)
    }

    private func save() {
        guard let selectedDirection else { return }
        editor.update(
            session: session,
            todo: selectedTodo,
            direction: selectedDirection,
            startedAt: timeDraft.startedAt,
            focusSeconds: timeDraft.focusSeconds,
            memo: memo,
            modelContext: modelContext
        )
        try? modelContext.save()
        close()
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}
