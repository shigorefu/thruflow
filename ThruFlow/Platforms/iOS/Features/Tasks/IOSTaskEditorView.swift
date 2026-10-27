import SwiftData
import SwiftUI

struct IOSTaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Todo.updatedAt, order: .reverse) private var suggestionTodos: [Todo]

    let mode: IOSTaskEditorMode
    let areas: [Area]
    private let fixedArea: Area?
    private let onSave: ((Todo) -> Void)?

    @State private var draft: TodoDraft
    @State private var hashtagsText: String
    @State private var areaID: UUID?
    @State private var datePickerValue: Date
    @State private var saveErrorMessage: String?
    @FocusState private var isTitleFocused: Bool

    init(
        mode: IOSTaskEditorMode,
        areas: [Area],
        fixedArea: Area? = nil,
        project: Project? = nil,
        scheduledDate: Date? = nil,
        onSave: ((Todo) -> Void)? = nil
    ) {
        self.mode = mode
        self.areas = areas
        self.fixedArea = fixedArea
        self.onSave = onSave

        // The editor owns a one-time draft; cancelling never mutates the model.
        let draft: TodoDraft
        switch mode {
        case .create:
            draft = TodoDraft(area: fixedArea ?? project?.area, project: project, scheduledDate: scheduledDate ?? .now)
        case .edit(let todo):
            draft = TodoDraft(todo: todo)
        }
        _draft = State(initialValue: draft)
        _hashtagsText = State(initialValue: draft.hashtags.map { "#\($0)" }.joined(separator: " "))
        _areaID = State(initialValue: draft.area?.id)
        _datePickerValue = State(initialValue: draft.scheduledDate ?? .now)
        _saveErrorMessage = State(initialValue: nil)
    }

    var body: some View {
        Form {
            Section {
                TextField(String(localized: "タスク名"), text: $draft.title, axis: .vertical)
                    .lineLimit(1...3)
                    .focused($isTitleFocused)
                TextField(String(localized: "メモ"), text: $draft.notes, axis: .vertical)
                    .lineLimit(2...5)
                TextField("#tag", text: $hashtagsText)
                    .textInputAutocapitalization(.never)
            }

            if case .edit(let todo) = mode, todo.externalTaskLinkRawValue != nil {
                Section { ExternalTaskSourceLink(todo: todo) }
            }

            if isHabitTodoEdit {
                habitStructureSection
            } else {
                Section {
                    Picker(String(localized: "分野"), selection: selectedAreaBinding) {
                        Text(String(localized: "未選択")).tag(UUID?.none)
                        ForEach(selectableAreas) { area in
                            Text("\(area.symbolName) \(area.name)")
                                .tag(Optional(area.id))
                        }
                    }
                    .disabled(fixedArea != nil)

                    TaskProjectPicker(area: draft.area, selection: $draft.project, currentProject: editedTodo?.project)

                    Picker(String(localized: "種類"), selection: $draft.measurement) {
                        ForEach(TodoMeasurement.allCases) { measurement in
                            Text(measurement.displayName).tag(measurement)
                        }
                    }

                    if draft.measurement != .checkbox {
                        Stepper(value: plannedAmountBinding, in: 1...999) {
                            Text(targetText)
                        }
                    }

                    Picker(String(localized: "優先度"), selection: $draft.priority) {
                        ForEach(TodoPriority.allCases) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }

                    if draft.priority == .low {
                        Toggle(String(localized: "余裕があれば"), isOn: $draft.isRoomIfPossible)
                    }

                    Toggle(
                        String(localized: "日付なし"),
                        isOn: Binding(
                            get: { draft.scheduledDate == nil },
                            set: { hasNoDate in
                                draft.scheduledDate = hasNoDate ? nil : datePickerValue
                                if hasNoDate {
                                    draft.scheduledTimeMinutes = nil
                                    draft.reminderEnabled = false
                                }
                            }
                        )
                    )

                    if draft.scheduledDate != nil {
                        DatePicker(
                            String(localized: "日付"),
                            selection: $datePickerValue,
                            displayedComponents: .date
                        )
                        .onChange(of: datePickerValue) { _, newValue in
                            draft.scheduledDate = newValue
                        }
                    }
                }
            }

            Section {
                TaskTimingControls(
                    scheduledDate: draft.scheduledDate,
                    timeMinutes: $draft.scheduledTimeMinutes,
                    reminderEnabled: $draft.reminderEnabled
                )
            }

            if let saveErrorMessage {
                Section {
                    Label(saveErrorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .taskTimingDefaults(timeMinutes: $draft.scheduledTimeMinutes, reminderEnabled: $draft.reminderEnabled)
        .safeAreaInset(edge: .top, spacing: 0) {
            if !titleSuggestions.isEmpty {
                titleSuggestionPanel
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(
            reduceMotion ? nil : .snappy(duration: 0.22),
            value: titleSuggestions.map(\.id)
        )
        .iosCenteredNavigationTitle(
            isEditing ? String(localized: "タスクを編集") : String(localized: "タスクを追加")
        )
        .onChange(of: draft.measurement) { _, measurement in
            if measurement != .checkbox, draft.plannedAmount == nil {
                draft.plannedAmount = 1
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "キャンセル")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "保存"), action: save)
                    .disabled(!canSave)
            }
        }
    }

    private var titleSuggestions: [TaskTitleSuggestion] {
        guard isTitleFocused else { return [] }
        return TaskTitleSuggestionBuilder().suggestions(
            query: draft.title,
            todos: suggestionTodos,
            excludingTodoID: editedTodo?.id
        )
    }

    private var titleSuggestionPanel: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(titleSuggestions) { suggestion in
                    Button {
                        draft.title = suggestion.title
                        isTitleFocused = true
                    } label: {
                        Label(suggestion.title, systemImage: "clock.arrow.circlepath")
                            .font(.subheadline)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(.regularMaterial, in: Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var editedTodo: Todo? {
        if case .edit(let todo) = mode { return todo }
        return nil
    }

    private var isHabitTodoEdit: Bool {
        editedTodo?.taskType == .habit
    }

    private var selectableAreas: [Area] {
        if let existingArea = editedTodo?.area ?? draft.area,
           !areas.contains(where: { $0.id == existingArea.id }) {
            return areas + [existingArea]
        }
        return areas
    }

    private var canSave: Bool {
        TaskEditingService().validationErrors(for: submittedDraft, editing: editedTodo).isEmpty
    }

    private var selectedAreaBinding: Binding<UUID?> {
        Binding(
            get: { areaID },
            set: { id in
                if areaID != id { draft.project = nil }
                draft.area = selectableAreas.first { $0.id == id }
                areaID = id
            }
        )
    }

    private var submittedDraft: TodoDraft {
        var result = draft
        result.hashtags = TodoHashtagNormalizer.normalize(
            hashtagsText.split(whereSeparator: { $0.isWhitespace || $0 == "," }).map(String.init)
        )
        // These fields have no controls on iOS. Preserve changes made by an
        // active Flow or synchronization while this editor was open.
        if let editedTodo {
            result.actualProgress = editedTodo.actualProgress
            result.deadline = editedTodo.deadline
        }
        return result
    }

    private var plannedAmountBinding: Binding<Int> {
        Binding(
            get: { draft.plannedAmount ?? 1 },
            set: { draft.plannedAmount = $0 }
        )
    }

    private var targetText: String {
        switch draft.measurement {
        case .checkbox: ""
        case .focusBlocks: "\(draft.plannedAmount ?? 1) \(String(localized: "ブロック"))"
        case .minutes: "\(draft.plannedAmount ?? 1) \(String(localized: "分"))"
        }
    }

    @ViewBuilder
    private var habitStructureSection: some View {
        if let todo = editedTodo {
            Section {
                LabeledContent(String(localized: "分野")) {
                    Text("\(todo.area?.symbolName ?? "📝") \(TodoDisplay.flowContextName(for: todo))")
                }

                LabeledContent(String(localized: "種類"), value: todo.measurement.displayName)

                if todo.measurement != .checkbox {
                    LabeledContent(String(localized: "目標")) {
                        Text(habitTargetText(todo))
                            .monospacedDigit()
                    }
                }

                LabeledContent(String(localized: "優先度"), value: todo.priority.displayName)

                if todo.priority == .low, todo.isRoomIfPossible {
                    LabeledContent(String(localized: "余裕があれば")) {
                        Image(systemName: "checkmark")
                    }
                }

                LabeledContent(String(localized: "日付")) {
                    if let date = todo.scheduledDate {
                        Text(date, format: .dateTime.year().month().day())
                    } else {
                        Text(String(localized: "日付なし"))
                    }
                }

                if let deadline = todo.deadline {
                    LabeledContent(String(localized: "期限")) {
                        Text(deadline, format: .dateTime.year().month().day())
                    }
                }
            }
        }
    }

    private func habitTargetText(_ todo: Todo) -> String {
        let amount = todo.plannedAmount ?? 1
        switch todo.measurement {
        case .checkbox:
            return ""
        case .focusBlocks:
            return "\(amount) \(String(localized: "ブロック"))"
        case .minutes:
            return "\(amount) \(String(localized: "分"))"
        }
    }

    private func save() {
        saveErrorMessage = nil
        do {
            let todo = try TaskEditingService().save(
                draft: submittedDraft,
                editing: editedTodo,
                modelContext: modelContext
            )
            onSave?(todo)
            dismiss()
        } catch TaskEditingError.validation(let errors) {
            saveErrorMessage = errors.map(\.localizedDescription).joined(separator: "\n")
        } catch {
            saveErrorMessage = String(localized: "記録を保存できませんでした。")
        }
    }
}
