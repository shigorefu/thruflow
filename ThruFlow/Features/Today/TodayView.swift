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

    @State private var editingTodo: Todo?
    @State private var newTodoTitle = ""
    @State private var newTodoDirectionID: UUID?
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
        .safeAreaInset(edge: .bottom) {
            MessengerTodoComposer(
                title: $newTodoTitle,
                selectedDirectionID: $newTodoDirectionID,
                directions: activeDirections,
                validationMessage: newTodoError,
                onSubmit: createInlineTodo
            )
        }
        .sheet(item: $editingTodo) { todo in
            TodoFormView(mode: .edit(todo))
        }
    }

    private func createInlineTodo() {
        let draft = TodoDraft(
            title: newTodoTitle,
            direction: direction(for: newTodoDirectionID),
            measurement: .checkbox,
            plannedAmount: nil,
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
            measurement: .checkbox,
            plannedAmount: nil,
            status: progress.status(
                measurement: .checkbox,
                plannedAmount: nil,
                actualProgress: 0
            ),
            scheduledDate: .now
        )
        modelContext.insert(todo)

        newTodoTitle = ""
        newTodoError = nil
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

private struct MessengerTodoComposer: View {
    @Binding var title: String
    @Binding var selectedDirectionID: UUID?

    let directions: [Direction]
    let validationMessage: String?
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    private var isExpanded: Bool {
        isFocused ||
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        selectedDirectionID != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isExpanded {
                Picker("方向", selection: $selectedDirectionID) {
                    Text("自動: タスク").tag(UUID?.none)

                    ForEach(directions) { direction in
                        Text("\(direction.symbolName) \(direction.name)")
                            .tag(Optional(direction.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
                .controlSize(.small)
            }

            HStack(spacing: 10) {
                Image(systemName: "square")
                    .imageScale(.large)
                    .foregroundStyle(isExpanded ? Color.primary.opacity(0.8) : Color.secondary.opacity(0.35))
                    .frame(width: 26)
                    .accessibilityHidden(true)

                TextField("タスクを入力", text: $title)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit(onSubmit)

                if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: onSubmit) {
                        Image(systemName: "arrow.up.circle.fill")
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("タスクを追加")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
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
              let schedule = direction.goalSchedule,
              let unit = direction.goalUnit else {
            return direction.type.description
        }

        return "\(target) \(unit.displayName) / \(scheduleSummary(schedule))"
    }

    private func scheduleSummary(_ schedule: GoalScheduleKind) -> String {
        switch schedule {
        case .everyDay:
            return schedule.displayName
        case .weeklyCount:
            return "週 \(direction.weeklyTargetCount ?? 1) 回"
        case .weekdays:
            return selectedWeekdaysSummary
        }
    }

    private var selectedWeekdaysSummary: String {
        let names = GoalWeekday.allCases
            .filter { ((direction.weekdayMask ?? 0) & $0.rawValue) != 0 }
            .map(\.displayName)
            .joined(separator: "・")

        return names.isEmpty ? "曜日" : names
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
