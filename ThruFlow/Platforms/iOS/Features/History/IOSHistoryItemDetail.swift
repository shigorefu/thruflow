#if os(iOS)
import SwiftData
import SwiftUI
import UIKit

struct IOSHistoryItemDetail: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Area.sortIndex) private var areas: [Area]
    @Query(sort: \Todo.updatedAt, order: .reverse) private var todos: [Todo]

    let item: HistoryCalendarItem

    @State private var selectedTodoID: UUID?
    @State private var selectedAreaID: UUID?
    @State private var taskTitleDraft: String
    @State private var timeDraft: FlowHistoryTimeDraft
    @State private var memo: String
    @State private var createdTodo: Todo?
    @State private var isCreatingTask = false
    @State private var showsDeleteConfirmation = false
    @State private var showsBreakDeleteConfirmation = false
    @State private var breakStartAt: Date
    @State private var breakDurationMinutes: Int
    @State private var breakEndAt: Date
    @State private var breakEditError: String?

    private let editor = FlowHistoryEditor()
    private let breakEditor = FlowBreakEditor()

    init(item: HistoryCalendarItem) {
        self.item = item
        let session = item.session
        let selectedTodo = item.todo ?? session?.todo
        let selectedArea = item.flowSegment?.area ?? selectedTodo?.area ?? session?.area
        _selectedTodoID = State(initialValue: selectedTodo?.id)
        _selectedAreaID = State(initialValue: selectedArea?.id)
        _taskTitleDraft = State(initialValue: selectedTodo?.title ?? "")
        _timeDraft = State(initialValue: FlowHistoryTimeDraft(
            startedAt: item.startedAt,
            endedAt: item.endedAt,
            focusSeconds: item.durationSeconds
        ))
        _memo = State(initialValue: session?.result ?? selectedTodo?.notes ?? "")
        _breakStartAt = State(initialValue: item.startedAt)
        _breakDurationMinutes = State(
            initialValue: max(
                FlowBreakEditor.minimumDurationMinutes,
                item.durationSeconds / 60
            )
        )
        _breakEndAt = State(initialValue: item.endedAt)
        _breakEditError = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch item.kind {
                case .flow:
                    if let session = item.session {
                        flowEditor(session: session)
                    }
                case .rest:
                    if let flowBreak = item.flowBreak {
                        breakEditorView(flowBreak: flowBreak)
                    }
                }
            }
            .iosCenteredNavigationTitle(
                item.kind == .rest ? String(localized: "休憩") : String(localized: "集中記録")
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "閉じる")) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    switch item.kind {
                    case .flow:
                        if let session = item.session {
                            Button(String(localized: "保存")) {
                                save(session: session)
                            }
                            .disabled(selectedArea == nil)
                        }
                    case .rest:
                        if let flowBreak = item.flowBreak {
                            Button(String(localized: "保存")) {
                                save(flowBreak: flowBreak)
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: selectedTodoID) { _, newValue in
            guard let newValue, let todo = todo(withID: newValue) else {
                taskTitleDraft = ""
                return
            }
            selectedAreaID = todo.area?.id
            taskTitleDraft = todo.title
            if memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                memo = todo.notes ?? ""
            }
        }
        .sheet(isPresented: $isCreatingTask) {
            if let selectedArea {
                NavigationStack {
                    IOSTaskEditorView(
                        mode: .create,
                        areas: availableAreas,
                        fixedArea: selectedArea,
                        scheduledDate: item.startedAt
                    ) { todo in
                        attachCreatedTodo(todo)
                    }
                }
            }
        }
        .confirmationDialog(
            String(localized: "この集中記録を削除しますか？"),
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "削除"), role: .destructive) {
                guard let session = item.session else { return }
                guard performHistoryMutation({
                    if let segment = item.flowSegment {
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
                dismiss()
            }
            Button(String(localized: "キャンセル"), role: .cancel) {}
        } message: {
            Text(String(localized: "この記録分の集中時間を、タスクと分野の合計から差し引きます。"))
        }
        .confirmationDialog(
            String(localized: "休憩を削除"),
            isPresented: $showsBreakDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "削除"), role: .destructive) {
                guard let flowBreak = item.flowBreak, !isActiveBreak(flowBreak) else { return }
                do {
                    try breakEditor.delete(flowBreak, modelContext: modelContext)
                    dismiss()
                } catch {
                    modelContext.rollback()
                    PersistenceIssueCenter.shared.report(error, operation: .historyUpdate)
                }
            }
            Button(String(localized: "キャンセル"), role: .cancel) {}
        }
        .alert(
            String(localized: "移動できません"),
            isPresented: Binding(
                get: { breakEditError != nil },
                set: { if !$0 { breakEditError = nil } }
            )
        ) {
            Button(String(localized: "OK")) {
                breakEditError = nil
            }
        } message: {
            Text(breakEditError ?? "")
        }
    }

    private func attachCreatedTodo(_ todo: Todo) {
        guard let session = item.session else { return }
        createdTodo = todo
        selectedTodoID = todo.id
        selectedAreaID = todo.area?.id
        taskTitleDraft = todo.title

        _ = performHistoryMutation {
            if let segment = item.flowSegment {
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

    private var selectedTodo: Todo? {
        guard let selectedTodoID else { return nil }
        return todo(withID: selectedTodoID)
    }

    private var selectedArea: Area? {
        selectedTodo?.area
            ?? selectedAreaID.flatMap { id in
                availableAreas.first { $0.id == id }
            }
    }

    private var availableAreas: [Area] {
        areas.filter { !$0.isArchived }
    }

    private var availableTodos: [Todo] {
        var candidates = todos
        if let createdTodo, !candidates.contains(where: { $0.id == createdTodo.id }) {
            candidates.append(createdTodo)
        }

        return candidates
            .filter { todo in
                if todo.id == item.todo?.id || todo.id == item.session?.todo?.id {
                    return true
                }
                guard !todo.isDeleted, !todo.isArchived else { return false }
                return TodayTodoFilter().includes(todo, on: item.startedAt)
            }
            .sorted {
                if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
                if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
                return $0.createdAt < $1.createdAt
            }
    }

    private func todo(withID id: UUID) -> Todo? {
        todos.first { $0.id == id }
            ?? (createdTodo?.id == id ? createdTodo : nil)
    }

    @ViewBuilder
    private func flowEditor(session: FlowSession) -> some View {
        Form {
            Section(String(localized: "対象タスク")) {
                Picker(String(localized: "対象タスク"), selection: $selectedTodoID) {
                    Text(String(localized: "タスクなし")).tag(UUID?.none)
                    ForEach(availableTodos) { todo in
                        Text("\(todo.area?.symbolName ?? "📥") \(TodoDisplay.title(for: todo))")
                            .tag(Optional(todo.id))
                    }
                }

                if selectedTodo != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "タスク名"))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField(
                            String(localized: "何をしましたか？"),
                            text: $taskTitleDraft,
                            axis: .vertical
                        )
                    }
                }

                Button {
                    isCreatingTask = true
                } label: {
                    Label(String(localized: "タスクを追加"), systemImage: "plus")
                }
                .disabled(selectedArea == nil)
            }

            Section(String(localized: "分野")) {
                Picker(String(localized: "分野"), selection: $selectedAreaID) {
                    ForEach(availableAreas) { area in
                        Text("\(area.symbolName) \(area.name)")
                            .tag(Optional(area.id))
                    }
                }
                .disabled(selectedTodo != nil)
            }

            Section(String(localized: "時間")) {
                DatePicker(
                    String(localized: "開始"),
                    selection: Binding(
                        get: { timeDraft.startedAt },
                        set: { timeDraft.setStartedAt($0) }
                    )
                )

                DatePicker(
                    String(localized: "終了"),
                    selection: Binding(
                        get: { timeDraft.endedAt },
                        set: { timeDraft.setEndedAt($0) }
                    )
                )

                Stepper(
                    String(localized: "\(timeDraft.focusMinutes)分"),
                    value: Binding(
                        get: { timeDraft.focusMinutes },
                        set: { timeDraft.setFocusMinutes($0) }
                    ),
                    in: 1...720
                )
            }

            Section(String(localized: "メモ")) {
                TextEditor(text: $memo)
                    .frame(minHeight: 110)
            }

            Section {
                Button(String(localized: "この集中記録を削除"), role: .destructive) {
                    showsDeleteConfirmation = true
                }
            }
        }
    }

    private func breakEditorView(flowBreak: FlowBreak) -> some View {
        Form {
            Section(String(localized: "時間")) {
                DatePicker(
                    String(localized: "開始"),
                    selection: Binding(
                        get: { breakStartAt },
                        set: { updateBreakStart($0) }
                    )
                )

                DatePicker(
                    String(localized: "終了"),
                    selection: Binding(
                        get: { breakEndAt },
                        set: { updateBreakEnd($0) }
                    )
                )

                Stepper(
                    String(localized: "\(breakDurationMinutes)分"),
                    value: Binding(
                        get: { breakDurationMinutes },
                        set: { minutes in
                            breakDurationMinutes = minutes
                            breakEndAt = breakStartAt.addingTimeInterval(
                                TimeInterval(minutes * 60)
                            )
                        }
                    ),
                    in: FlowBreakEditor.minimumDurationMinutes
                        ... FlowBreakEditor.maximumDurationMinutes
                )
            }

            Section {
                Button(String(localized: "休憩を削除"), role: .destructive) {
                    showsBreakDeleteConfirmation = true
                }
                .disabled(isActiveBreak(flowBreak))
            }
        }
    }

    private func updateBreakStart(_ startedAt: Date) {
        let previousMinutes = breakDurationMinutes
        breakStartAt = startedAt

        if breakEndAt > startedAt {
            breakDurationMinutes = breakEditor.durationMinutes(
                from: startedAt,
                to: breakEndAt
            )
        } else {
            breakDurationMinutes = previousMinutes
        }
        breakEndAt = startedAt.addingTimeInterval(TimeInterval(breakDurationMinutes * 60))
    }

    private func updateBreakEnd(_ endedAt: Date) {
        breakDurationMinutes = breakEditor.durationMinutes(
            from: breakStartAt,
            to: endedAt
        )
        breakEndAt = breakStartAt.addingTimeInterval(TimeInterval(breakDurationMinutes * 60))
    }

    private func save(session: FlowSession) {
        guard let selectedArea else { return }
        let now = Date.now
        selectedTodo?.rename(to: taskTitleDraft, now: now)
        guard performHistoryMutation({
            if let segment = item.flowSegment {
                try editor.update(
                    segment: segment,
                    in: session,
                    todo: selectedTodo,
                    area: selectedArea,
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
                    area: selectedArea,
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
        dismiss()
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

    private func save(flowBreak: FlowBreak) {
        do {
            _ = try breakEditor.updateInterval(
                of: flowBreak,
                startedAt: breakStartAt,
                minutes: breakDurationMinutes,
                modelContext: modelContext,
                protectedSessionID: activeFlowStore.activeSession?.id
            )
            dismiss()
        } catch FlowBreakEditorError.activeFlowWouldMove {
            breakEditError = String(localized: "進行中の集中は移動できません。")
        } catch {
            breakEditError = error.localizedDescription
        }
    }

    private func isActiveBreak(_ flowBreak: FlowBreak) -> Bool {
        flowBreak.timerStoppedAt == nil &&
            activeFlowStore.isBreakPhase &&
            activeFlowStore.activeSession?.id == flowBreak.previousSessionID
    }

    private var timeRange: String {
        "\(item.startedAt.formatted(date: .omitted, time: .shortened))–\(item.endedAt.formatted(date: .omitted, time: .shortened))"
    }

    private var durationText: String {
        let minutes = item.durationSeconds / 60
        return minutes >= 60
            ? String(localized: "\(minutes / 60)時間\(minutes % 60)分")
            : String(localized: "\(minutes)分")
    }
}
#endif
