//
//  FlowHistoryInspectorView.swift
//  ThruFlow
//
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
    let segment: FlowSegment?
    let onClose: (() -> Void)?

    @State private var selectedTodoID: UUID?
    @State private var selectedDirectionID: UUID?
    @State private var taskTitleDraft: String
    @State private var timeDraft: FlowHistoryTimeDraft
    @State private var memo: String
    @State private var showsTaskPicker = false
    @State private var showsTaskComposer = false
    @State private var presentsTaskComposerAfterPicker = false
    @State private var createdTodo: Todo?
    @State private var showsDeleteConfirmation = false

    private let editor = FlowHistoryEditor()

    init(
        session: FlowSession,
        segment: FlowSegment? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.session = session
        self.segment = segment
        self.onClose = onClose
        let selectedTodo = segment?.todo ?? session.todo
        let selectedDirection = segment?.direction ?? selectedTodo?.direction ?? session.direction
        _selectedTodoID = State(initialValue: selectedTodo?.id)
        _selectedDirectionID = State(initialValue: selectedDirection?.id)
        _taskTitleDraft = State(initialValue: selectedTodo?.title ?? "")
        _timeDraft = State(initialValue: FlowHistoryTimeDraft(
            startedAt: segment?.startedAt ?? session.startedAt,
            endedAt: segment?.endedAt ?? session.endedAt,
            focusSeconds: segment?.resolvedFocusSeconds ?? session.resolvedActualFocusDurationSeconds
        ))
        _memo = State(initialValue: session.result ?? selectedTodo?.notes ?? "")
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
                if todo.id == segment?.todo?.id || todo.id == session.todo?.id {
                    return true
                }
                guard !todo.isDeleted, !todo.isArchived else { return false }
                return TodayTodoFilter().includes(todo, on: segment?.startedAt ?? session.startedAt)
            }
            .sorted {
                if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
                if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
                return $0.createdAt < $1.createdAt
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    taskSelectionButton

                    if selectedTodo != nil {
                        field(String(localized: "タスク名")) {
                            TextField(
                                String(localized: "何をしましたか？"),
                                text: $taskTitleDraft
                            )
                            .textFieldStyle(.roundedBorder)
                        }
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
                        Label(String(localized: "この集中記録を削除"), systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(20)
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
            .padding(20)
        }
        .frame(width: 540, height: 580)
        .onChange(of: selectedTodoID) { _, newValue in
            guard let newValue, let todo = todo(withID: newValue) else {
                taskTitleDraft = ""
                return
            }

            selectedDirectionID = todo.direction?.id
            taskTitleDraft = todo.title
            if memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                memo = todo.notes ?? ""
            }
        }
        .confirmationDialog(
            String(localized: "この集中記録を削除しますか？"),
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "削除"), role: .destructive) {
                guard performHistoryMutation({
                    if let segment {
                        try editor.delete(
                            segment: segment,
                            from: session,
                            modelContext: modelContext
                        )
                    } else {
                        try editor.delete(session: session, modelContext: modelContext)
                    }
                }) else {
                    return
                }
                close()
            }
            Button(String(localized: "キャンセル"), role: .cancel) {}
        } message: {
            Text(String(localized: "この記録分の集中時間を、タスクと分野の合計から差し引きます。"))
        }
        .popover(isPresented: $showsTaskPicker, arrowEdge: .bottom) {
            FlowTaskPickerView(
                directions: availableDirections,
                todos: availableTodos,
                selectedDirectionID: selectedDirectionID,
                selectedTodoID: selectedTodoID,
                onCreateTask: presentTaskComposer
            ) { direction, todo in
                selectedTodoID = todo?.id
                selectedDirectionID = todo?.direction?.id ?? direction?.id
            }
            .frame(width: 520, height: 460)
        }
        .popover(isPresented: $showsTaskComposer, arrowEdge: .trailing) {
            QuickTodoCreationPopover(
                directions: availableDirections,
                scheduledDate: segment?.startedAt ?? session.startedAt,
                showsQuickInputLegend: false
            ) { todo in
                attachCreatedTodo(todo)
            }
        }
        .onChange(of: showsTaskPicker) { _, isPresented in
            guard !isPresented, presentsTaskComposerAfterPicker else { return }
            presentsTaskComposerAfterPicker = false

            Task { @MainActor in
                await Task.yield()
                showsTaskComposer = true
            }
        }
    }

    private func attachCreatedTodo(_ todo: Todo) {
        createdTodo = todo
        selectedTodoID = todo.id
        selectedDirectionID = todo.direction?.id
        taskTitleDraft = todo.title

        _ = performHistoryMutation {
            if let segment {
                try editor.attach(
                    todo: todo,
                    to: segment,
                    in: session,
                    modelContext: modelContext
                )
            } else {
                try editor.attach(
                    todo: todo,
                    to: session,
                    modelContext: modelContext
                )
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            if onClose != nil {
                Button(action: close) {
                    Image(systemName: "chevron.left")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "戻る"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "集中記録を編集"))
                    .font(.title3.weight(.semibold))
                Text(dateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if onClose == nil {
                Button(action: close) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "閉じる"))
            }
        }
        .padding(20)
    }

    private var taskSelectionButton: some View {
        Button {
            showsTaskPicker = true
        } label: {
            HStack(spacing: 12) {
                Text(selectedDirection?.symbolName ?? DefaultDirections.taskInboxSymbol)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(selectionTint.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(selectionTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(selectionSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.primary.opacity(0.08))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "集中記録に紐づけるタスクを選択"))
    }

    private var selectionTitle: String {
        if let selectedTodo {
            return TodoDisplay.title(for: selectedTodo)
        }
        return selectedDirection?.name ?? String(localized: "タスクなし")
    }

    private var selectionSubtitle: String {
        if let selectedTodo {
            return selectedTodo.direction?.name ?? String(localized: "その他")
        }
        return String(localized: "タスクなし")
    }

    private var selectionTint: Color {
        guard let selectedDirection, !DefaultDirections.isTaskInbox(selectedDirection) else {
            return .secondary
        }
        return Color(hex: selectedDirection.colorHex)
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
        return formatter.string(from: segment?.startedAt ?? session.startedAt)
    }

    private func save() {
        guard let selectedDirection else { return }
        let now = Date.now
        selectedTodo?.rename(to: taskTitleDraft, now: now)
        guard performHistoryMutation({
            if let segment {
                try editor.update(
                    segment: segment,
                    in: session,
                    todo: selectedTodo,
                    direction: selectedDirection,
                    startedAt: timeDraft.startedAt,
                    focusSeconds: timeDraft.focusSeconds,
                    memo: memo,
                    modelContext: modelContext,
                    now: now
                )
            } else {
                try editor.update(
                    session: session,
                    todo: selectedTodo,
                    direction: selectedDirection,
                    startedAt: timeDraft.startedAt,
                    focusSeconds: timeDraft.focusSeconds,
                    memo: memo,
                    modelContext: modelContext,
                    now: now
                )
            }
        }) else {
            return
        }
        close()
    }

    private func performHistoryMutation(_ mutation: () throws -> Void) -> Bool {
        do {
            try mutation()
            return modelContext.saveReporting(.historyUpdate)
        } catch {
            modelContext.rollback()
            PersistenceIssueCenter.shared.report(error, operation: .historyUpdate)
            return false
        }
    }

    private func todo(withID id: UUID) -> Todo? {
        todos.first { $0.id == id }
            ?? (createdTodo?.id == id ? createdTodo : nil)
    }

    private func presentTaskComposer() {
        presentsTaskComposerAfterPicker = true
        showsTaskPicker = false
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}
