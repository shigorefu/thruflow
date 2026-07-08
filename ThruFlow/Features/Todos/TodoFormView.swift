//
//  TodoFormView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import SwiftData
import SwiftUI

struct TodoFormView: View {
    enum Mode {
        case create
        case edit(Todo)

        var title: String {
            switch self {
            case .create:
                "新しいタスク"
            case .edit:
                "タスクを編集"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Direction.name, order: .forward) private var directions: [Direction]

    let mode: Mode

    @State private var draft: TodoDraft
    @State private var selectedDirectionID: UUID?
    @State private var usesScheduledDate: Bool
    @State private var usesDeadline: Bool
    @State private var validationErrors: [TodoValidationError] = []

    private let validator = TodoValidator()

    private var activeDirections: [Direction] {
        directions.filter { !$0.isArchived }
    }

    init(mode: Mode) {
        self.mode = mode

        switch mode {
        case .create:
            let draft = TodoDraft()
            _draft = State(initialValue: draft)
            _selectedDirectionID = State(initialValue: nil)
            _usesScheduledDate = State(initialValue: true)
            _usesDeadline = State(initialValue: false)
        case .edit(let todo):
            let draft = TodoDraft(todo: todo)
            _draft = State(initialValue: draft)
            _selectedDirectionID = State(initialValue: todo.direction?.id)
            _usesScheduledDate = State(initialValue: todo.scheduledDate != nil)
            _usesDeadline = State(initialValue: todo.deadline != nil)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本") {
                    TextField("タイトル", text: $draft.title)

                    TextField("メモ", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...5)

                    Picker("方向", selection: selectedDirectionBinding) {
                        Text("未選択").tag(UUID?.none)

                        ForEach(activeDirections) { direction in
                            Label(direction.name, systemImage: direction.symbolName)
                                .tag(Optional(direction.id))
                        }
                    }
                }

                Section("進捗") {
                    Picker("測定", selection: $draft.measurement) {
                        ForEach(TodoMeasurement.allCases) { measurement in
                            Text(measurement.displayName).tag(measurement)
                        }
                    }

                    if draft.measurement != .checkbox {
                        Stepper(value: plannedAmountBinding, in: 1...999) {
                            Text("予定量: \(draft.plannedAmount ?? 1)")
                        }

                        Stepper(value: actualProgressBinding, in: 0...999) {
                            Text("進捗: \(draft.actualProgress)")
                        }
                    }
                }

                Section("日付") {
                    Toggle("今日に入れる", isOn: $usesScheduledDate)

                    if usesScheduledDate {
                        DatePicker("予定日", selection: scheduledDateBinding, displayedComponents: .date)
                    }

                    Toggle("期限を使う", isOn: $usesDeadline)

                    if usesDeadline {
                        DatePicker("期限", selection: deadlineBinding, displayedComponents: .date)
                    }
                }

                if !validationErrors.isEmpty {
                    Section {
                        ForEach(validationErrors, id: \.self) { error in
                            Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(mode.title)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                }
            }
        }
        .onAppear(perform: selectInitialDirectionIfNeeded)
    }

    private var selectedDirectionBinding: Binding<UUID?> {
        Binding(
            get: { selectedDirectionID },
            set: {
                selectedDirectionID = $0
                draft.direction = direction(for: $0)
            }
        )
    }

    private var plannedAmountBinding: Binding<Int> {
        Binding(
            get: { draft.plannedAmount ?? 1 },
            set: { draft.plannedAmount = $0 }
        )
    }

    private var actualProgressBinding: Binding<Int> {
        Binding(
            get: { draft.actualProgress },
            set: { draft.actualProgress = $0 }
        )
    }

    private var scheduledDateBinding: Binding<Date> {
        Binding(
            get: { draft.scheduledDate ?? .now },
            set: { draft.scheduledDate = $0 }
        )
    }

    private var deadlineBinding: Binding<Date> {
        Binding(
            get: { draft.deadline ?? .now },
            set: { draft.deadline = $0 }
        )
    }

    private func selectInitialDirectionIfNeeded() {
        if draft.direction == nil,
           selectedDirectionID == nil,
           let firstDirection = activeDirections.first {
            selectedDirectionID = firstDirection.id
            draft.direction = firstDirection
        } else if draft.direction == nil {
            draft.direction = direction(for: selectedDirectionID)
        }
    }

    private func direction(for id: UUID?) -> Direction? {
        guard let id else { return nil }
        return activeDirections.first { $0.id == id }
    }

    private func save() {
        draft.direction = direction(for: selectedDirectionID)
        draft.scheduledDate = usesScheduledDate ? draft.scheduledDate ?? .now : nil
        draft.deadline = usesDeadline ? draft.deadline ?? .now : nil

        validationErrors = validator.validate(draft)
        guard validationErrors.isEmpty, let direction = draft.direction else { return }

        let plannedAmount = draft.measurement == .checkbox ? nil : draft.plannedAmount
        let actualProgress = draft.measurement == .checkbox ? min(max(draft.actualProgress, 0), 1) : max(0, draft.actualProgress)

        switch mode {
        case .create:
            let todo = Todo(
                title: draft.trimmedTitle,
                notes: draft.trimmedNotes,
                direction: direction,
                measurement: draft.measurement,
                plannedAmount: plannedAmount,
                actualProgress: actualProgress,
                status: TodoProgressCalculator().status(
                    measurement: draft.measurement,
                    plannedAmount: plannedAmount,
                    actualProgress: actualProgress
                ),
                scheduledDate: draft.scheduledDate,
                deadline: draft.deadline
            )
            modelContext.insert(todo)
        case .edit(let todo):
            todo.update(
                title: draft.trimmedTitle,
                notes: draft.trimmedNotes,
                direction: direction,
                measurement: draft.measurement,
                plannedAmount: plannedAmount,
                actualProgress: actualProgress,
                scheduledDate: draft.scheduledDate,
                deadline: draft.deadline
            )
        }

        dismiss()
    }
}

#Preview("タスクを作成") {
    TodoFormView(mode: .create)
        .modelContainer(for: [Direction.self, Todo.self], inMemory: true)
}
