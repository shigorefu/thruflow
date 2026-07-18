import SwiftData
import SwiftUI

struct IOSTaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let mode: IOSTaskEditorMode
    let directions: [Direction]

    @State private var title: String
    @State private var notes: String
    @State private var hashtags: String
    @State private var directionID: UUID?
    @State private var measurement: TodoMeasurement
    @State private var priority: TodoPriority
    @State private var plannedAmount: Int
    @State private var scheduledDate: Date

    init(mode: IOSTaskEditorMode, directions: [Direction]) {
        self.mode = mode
        self.directions = directions

        let todo: Todo?
        if case .edit(let value) = mode { todo = value } else { todo = nil }

        _title = State(initialValue: todo?.title ?? "")
        _notes = State(initialValue: todo?.notes ?? "")
        _hashtags = State(initialValue: todo?.hashtags.map { "#\($0)" }.joined(separator: " ") ?? "")
        _directionID = State(initialValue: todo?.direction?.id ?? directions.first?.id)
        _measurement = State(initialValue: todo?.measurement ?? .checkbox)
        _priority = State(initialValue: todo?.priority ?? .medium)
        _plannedAmount = State(initialValue: max(1, todo?.plannedAmount ?? 1))
        _scheduledDate = State(initialValue: todo?.scheduledDate ?? .now)
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

            Section {
                Picker(String(localized: "方向"), selection: $directionID) {
                    ForEach(directions) { direction in
                        Text("\(direction.symbolName) \(direction.name)")
                            .tag(Optional(direction.id))
                    }
                }

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

                DatePicker(
                    String(localized: "日付"),
                    selection: $scheduledDate,
                    displayedComponents: .date
                )
            }
        }
        .navigationTitle(isEditing ? String(localized: "タスクを編集") : String(localized: "タスクを追加"))
        .navigationBarTitleDisplayMode(.inline)
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

    private var selectedDirection: Direction? {
        directions.first { $0.id == directionID }
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

    private func save() {
        guard let direction = selectedDirection else { return }
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
                plannedAmount: measurement == .checkbox ? nil : plannedAmount,
                scheduledDate: scheduledDate
            )
            modelContext.insert(todo)
        case .edit(let todo):
            todo.update(
                title: normalizedTitle,
                notes: notes,
                hashtags: tags,
                direction: direction,
                measurement: measurement,
                priority: priority,
                isRoomIfPossible: todo.isRoomIfPossible,
                plannedAmount: measurement == .checkbox ? nil : plannedAmount,
                actualProgress: todo.actualProgress,
                scheduledDate: scheduledDate,
                deadline: todo.deadline
            )
        }

        try? modelContext.save()
        dismiss()
    }
}
