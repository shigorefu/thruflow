import SwiftData
import SwiftUI

struct IOSTaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let mode: IOSTaskEditorMode
    let directions: [Direction]
    private let fixedDirection: Direction?
    private let onSave: ((Todo) -> Void)?

    @State private var title: String
    @State private var notes: String
    @State private var hashtags: String
    @State private var directionID: UUID?
    @State private var measurement: TodoMeasurement
    @State private var priority: TodoPriority
    @State private var isRoomIfPossible: Bool
    @State private var plannedAmount: Int
    @State private var scheduledDate: Date?
    @State private var datePickerValue: Date

    init(
        mode: IOSTaskEditorMode,
        directions: [Direction],
        fixedDirection: Direction? = nil,
        scheduledDate: Date? = nil,
        onSave: ((Todo) -> Void)? = nil
    ) {
        self.mode = mode
        self.directions = directions
        self.fixedDirection = fixedDirection
        self.onSave = onSave

        let todo: Todo?
        if case .edit(let value) = mode { todo = value } else { todo = nil }

        _title = State(initialValue: todo?.title ?? "")
        _notes = State(initialValue: todo?.notes ?? "")
        _hashtags = State(initialValue: todo?.hashtags.map { "#\($0)" }.joined(separator: " ") ?? "")
        _directionID = State(initialValue: todo?.direction?.id ?? fixedDirection?.id ?? directions.first?.id)
        _measurement = State(initialValue: todo?.measurement ?? .checkbox)
        _priority = State(initialValue: todo?.priority ?? .medium)
        _isRoomIfPossible = State(initialValue: todo?.isRoomIfPossible ?? false)
        _plannedAmount = State(initialValue: max(1, todo?.plannedAmount ?? 1))
        _scheduledDate = State(initialValue: todo?.scheduledDate ?? scheduledDate ?? .now)
        _datePickerValue = State(initialValue: todo?.scheduledDate ?? scheduledDate ?? .now)
    }

    var body: some View {
        Form {
            Section {
                TextField(String(localized: "タスク名"), text: $title, axis: .vertical)
                    .lineLimit(1...3)
                TextField(String(localized: "メモ"), text: $notes, axis: .vertical)
                    .lineLimit(2...5)
                TextField("#tag", text: $hashtags)
                    .textInputAutocapitalization(.never)
            }

            if isHabitTodoEdit {
                habitStructureSection
            } else {
                Section {
                    Picker(String(localized: "分野"), selection: $directionID) {
                        ForEach(directions) { direction in
                            Text("\(direction.symbolName) \(direction.name)")
                                .tag(Optional(direction.id))
                        }
                    }
                    .disabled(fixedDirection != nil)

                    Picker(String(localized: "種類"), selection: $measurement) {
                        ForEach(TodoMeasurement.allCases) { measurement in
                            Text(measurement.displayName).tag(measurement)
                        }
                    }

                    if measurement != .checkbox {
                        Stepper(value: $plannedAmount, in: 1...999) {
                            Text(targetText)
                        }
                    }

                    Picker(String(localized: "優先度"), selection: $priority) {
                        ForEach(TodoPriority.allCases) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }

                    if priority == .low {
                        Toggle(String(localized: "余裕があれば"), isOn: $isRoomIfPossible)
                    }

                    Toggle(
                        String(localized: "日付なし"),
                        isOn: Binding(
                            get: { scheduledDate == nil },
                            set: { hasNoDate in
                                scheduledDate = hasNoDate ? nil : datePickerValue
                            }
                        )
                    )

                    if scheduledDate != nil {
                        DatePicker(
                            String(localized: "日付"),
                            selection: $datePickerValue,
                            displayedComponents: .date
                        )
                        .onChange(of: datePickerValue) { _, newValue in
                            scheduledDate = newValue
                        }
                    }
                }
            }
        }
        .iosCenteredNavigationTitle(
            isEditing ? String(localized: "タスクを編集") : String(localized: "タスクを追加")
        )
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

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var editedTodo: Todo? {
        if case .edit(let todo) = mode { return todo }
        return nil
    }

    private var isHabitTodoEdit: Bool {
        editedTodo?.direction?.type == .habit
    }

    private var selectedDirection: Direction? {
        directions.first { $0.id == directionID }
            ?? (isHabitTodoEdit ? editedTodo?.direction : nil)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedDirection != nil
    }

    private var targetText: String {
        switch measurement {
        case .checkbox: ""
        case .focusBlocks: "\(plannedAmount) \(String(localized: "ブロック"))"
        case .minutes: "\(plannedAmount) \(String(localized: "分"))"
        }
    }

    @ViewBuilder
    private var habitStructureSection: some View {
        if let todo = editedTodo {
            Section {
                LabeledContent(String(localized: "分野")) {
                    Text("\(todo.direction?.symbolName ?? "📝") \(todo.direction?.name ?? String(localized: "分野"))")
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
        guard let direction = isHabitTodoEdit ? editedTodo?.direction : selectedDirection else { return }
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = hashtags
            .split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: "#")) }

        switch mode {
        case .create:
            let todo = Todo(
                title: normalizedTitle,
                notes: notes,
                hashtags: tags,
                direction: direction,
                measurement: measurement,
                priority: priority,
                isRoomIfPossible: priority == .low && isRoomIfPossible,
                plannedAmount: measurement == .checkbox ? nil : plannedAmount,
                scheduledDate: scheduledDate
            )
            modelContext.insert(todo)
            onSave?(todo)
        case .edit(let todo):
            let savedMeasurement = isHabitTodoEdit ? todo.measurement : measurement
            let savedPriority = isHabitTodoEdit ? todo.priority : priority
            let savedRoomIfPossible = isHabitTodoEdit
                ? todo.isRoomIfPossible
                : priority == .low && isRoomIfPossible
            let savedPlannedAmount = isHabitTodoEdit
                ? todo.plannedAmount
                : measurement == .checkbox ? nil : plannedAmount
            let savedDate = isHabitTodoEdit ? todo.scheduledDate : scheduledDate

            todo.update(
                title: normalizedTitle,
                notes: notes,
                hashtags: tags,
                direction: direction,
                measurement: savedMeasurement,
                priority: savedPriority,
                isRoomIfPossible: savedRoomIfPossible,
                plannedAmount: savedPlannedAmount,
                actualProgress: todo.actualProgress,
                scheduledDate: savedDate,
                deadline: todo.deadline
            )
            onSave?(todo)
        }

        try? modelContext.save()
        dismiss()
    }
}
