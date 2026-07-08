//
//  TodayView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Direction.name, order: .forward) private var directions: [Direction]
    @Query(sort: \Todo.createdAt, order: .forward) private var todos: [Todo]

    @State private var isShowingTodoSheet = false
    @State private var editingTodo: Todo?
    @State private var newTodoTitle = ""
    @State private var newTodoDirectionID: UUID?
    @State private var newTodoMeasurement = TodoMeasurement.checkbox
    @State private var newTodoPlannedAmount = 1
    @State private var newTodoError: String?

    private let filter = TodayTodoFilter()
    private let progress = TodoProgressCalculator()
    private let validator = TodoValidator()

    private var activeDirections: [Direction] {
        directions.filter { !$0.isArchived }
    }

    private var mustDirections: [Direction] {
        activeDirections.filter { $0.type == .must }
    }

    private var bonusDirections: [Direction] {
        activeDirections.filter { $0.type == .bonus }
    }

    private var todayTodos: [Todo] {
        todos.filter { filter.includes($0) }
    }

    var body: some View {
        List {
            Section("必須") {
                if mustDirections.isEmpty {
                    EmptyRow(text: "必須の方向はまだありません。")
                } else {
                    ForEach(mustDirections) { direction in
                        DirectionRequirementRow(direction: direction)
                    }
                }
            }

            Section("タスク") {
                InlineTodoComposer(
                    title: $newTodoTitle,
                    selectedDirectionID: $newTodoDirectionID,
                    measurement: $newTodoMeasurement,
                    plannedAmount: $newTodoPlannedAmount,
                    directions: activeDirections,
                    validationMessage: newTodoError,
                    onSubmit: createInlineTodo
                )

                if todayTodos.isEmpty {
                    EmptyRow(text: "今日のタスクはまだありません。")
                } else {
                    ForEach(todayTodos) { todo in
                        TodoRow(
                            todo: todo,
                            summary: progress.summary(
                                measurement: todo.measurement,
                                plannedAmount: todo.plannedAmount,
                                actualProgress: todo.actualProgress
                            )
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingTodo = todo
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("アーカイブ", systemImage: "archivebox", role: .destructive) {
                                todo.archive()
                            }
                        }
                    }
                }
            }

            Section("ボーナス") {
                if bonusDirections.isEmpty {
                    EmptyRow(text: "ボーナスの方向はまだありません。")
                } else {
                    ForEach(bonusDirections) { direction in
                        DirectionRequirementRow(direction: direction)
                    }
                }
            }
        }
        .navigationTitle("今日")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newTodoError = nil
                    isShowingTodoSheet = true
                } label: {
                    Label("詳細入力", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingTodoSheet) {
            TodoFormView(mode: .create)
        }
        .sheet(item: $editingTodo) { todo in
            TodoFormView(mode: .edit(todo))
        }
    }

    private func createInlineTodo() {
        let plannedAmount = newTodoMeasurement == .checkbox ? nil : newTodoPlannedAmount
        let draft = TodoDraft(
            title: newTodoTitle,
            direction: direction(for: newTodoDirectionID),
            measurement: newTodoMeasurement,
            plannedAmount: plannedAmount,
            scheduledDate: .now
        )
        let errors = validator.validate(draft)

        guard errors.isEmpty else {
            newTodoError = errors.map(\.localizedDescription).joined(separator: "\n")
            return
        }

        let direction = resolvedDirection(for: newTodoDirectionID)
        let todo = Todo(
            title: draft.trimmedTitle,
            direction: direction,
            measurement: newTodoMeasurement,
            plannedAmount: plannedAmount,
            status: progress.status(
                measurement: newTodoMeasurement,
                plannedAmount: plannedAmount,
                actualProgress: 0
            ),
            scheduledDate: .now
        )
        modelContext.insert(todo)

        newTodoTitle = ""
        newTodoError = nil
        newTodoMeasurement = .checkbox
        newTodoPlannedAmount = 1
    }

    private func resolvedDirection(for id: UUID?) -> Direction {
        if let direction = direction(for: id) {
            return direction
        }

        if let taskInbox = DefaultDirections.existingTaskInbox(in: activeDirections) {
            return taskInbox
        }

        let taskInbox = DefaultDirections.makeTaskInbox()
        modelContext.insert(taskInbox)
        return taskInbox
    }

    private func direction(for id: UUID?) -> Direction? {
        guard let id else { return nil }
        return activeDirections.first { $0.id == id }
    }
}

private struct InlineTodoComposer: View {
    @Binding var title: String
    @Binding var selectedDirectionID: UUID?
    @Binding var measurement: TodoMeasurement
    @Binding var plannedAmount: Int

    let directions: [Direction]
    let validationMessage: String?
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    private var isExpanded: Bool {
        isFocused ||
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        selectedDirectionID != nil ||
        measurement != .checkbox
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("[]")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)
                    .accessibilityHidden(true)

                TextField("タスク", text: $title)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit(onSubmit)

                Button(action: onSubmit) {
                    Image(systemName: "return")
                }
                .buttonStyle(.borderless)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("タスクを追加")
            }

            if isExpanded {
                HStack(spacing: 12) {
                    Picker("方向", selection: $selectedDirectionID) {
                        Text("自動: タスク").tag(UUID?.none)

                        ForEach(directions) { direction in
                            Text("\(direction.symbolName) \(direction.name)")
                                .tag(Optional(direction.id))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 180)

                    Picker("測定", selection: $measurement) {
                        ForEach(TodoMeasurement.allCases) { measurement in
                            Text(measurement.displayName).tag(measurement)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 150)

                    if measurement != .checkbox {
                        Stepper("予定: \(plannedAmount)", value: $plannedAmount, in: 1...999)
                            .frame(maxWidth: 130)
                    }
                }
                .controlSize(.small)

                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DirectionRequirementRow: View {
    let direction: Direction

    var body: some View {
        HStack(spacing: 12) {
            Text(direction.symbolName)
                .font(.title3)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(direction.name)
                    .font(.headline)

                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    private var summary: String {
        guard let target = direction.goalTarget,
              let period = direction.goalPeriod,
              let unit = direction.goalUnit else {
            return direction.type.description
        }

        return "\(target) \(unit.displayName) / \(period.displayName)"
    }
}

private struct TodoRow: View {
    let todo: Todo
    let summary: String

    var body: some View {
        HStack(spacing: 12) {
            Button {
                todo.setCompleted(!todo.isCompleted)
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isCompleted ? "未完了に戻す" : "完了にする")

            VStack(alignment: .leading, spacing: 3) {
                Text(todo.title)
                    .font(.headline)
                    .strikethrough(todo.isCompleted)

                HStack(spacing: 8) {
                    if let direction = todo.direction {
                        Text(direction.name)
                    }

                    Text(summary)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if todo.measurement != .checkbox {
                Stepper("進捗", value: progressBinding, in: 0...999)
                    .labelsHidden()
            }
        }
        .padding(.vertical, 3)
    }

    private var progressBinding: Binding<Int> {
        Binding(
            get: { todo.actualProgress },
            set: { todo.setProgress($0) }
        )
    }
}

private struct EmptyRow: View {
    let text: String

    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [Direction.self, Todo.self], inMemory: true)
}
