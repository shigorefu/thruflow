import SwiftData
import SwiftUI

struct IOSTasksView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Todo.sortIndex) private var todos: [Todo]
    @Query(sort: \Direction.sortIndex) private var directions: [Direction]

    @State private var editorMode: IOSTaskEditorMode?

    private var todayTodos: [Todo] {
        todos
            .filter { TodayTodoFilter(calendar: calendar).includes($0) }
            .sorted(by: taskSort)
    }

    var body: some View {
        List {
            taskSection(
                title: String(localized: "習慣"),
                todos: todayTodos.filter { $0.direction?.type == .habit }
            )
            taskSection(
                title: String(localized: "タスク"),
                todos: todayTodos.filter { $0.direction?.type == .neutral }
            )

            let niceTodos = todayTodos.filter { $0.direction?.type == .nice }
            if !niceTodos.isEmpty {
                taskSection(title: String(localized: "ナイス"), todos: niceTodos)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "タスク"))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            IOSTaskComposer(directions: activeDirections)
        }
        .overlay {
            if todayTodos.isEmpty {
                ContentUnavailableView(
                    String(localized: "今日の項目はありません"),
                    systemImage: "checkmark.circle"
                )
            }
        }
        .sheet(item: $editorMode) { mode in
            NavigationStack {
                IOSTaskEditorView(mode: mode, directions: activeDirections)
            }
        }
        .task {
            prepareToday()
        }
    }

    @ViewBuilder
    private func taskSection(title: String, todos: [Todo]) -> some View {
        if !todos.isEmpty {
            Section(title) {
                ForEach(todos) { todo in
                    IOSTaskRow(todo: todo) {
                        editorMode = .edit(todo)
                    }
                }
            }
        }
    }

    private var activeDirections: [Direction] {
        directions.filter { !$0.isArchived }
    }

    private func prepareToday() {
        let inbox = DefaultDirections.existingTaskInbox(in: directions) ?? {
            let direction = DefaultDirections.makeTaskInbox()
            modelContext.insert(direction)
            return direction
        }()
        _ = inbox

        let planner = RequiredTodoPlanner(calendar: calendar)
        var existingTodos = todos
        var nextSortIndex = (todos.map(\.sortIndex).max() ?? -1) + 1

        for direction in directions where direction.type == .habit && !direction.isArchived {
            guard let todo = planner.makeRequiredTodo(
                for: direction,
                existingTodos: existingTodos,
                sortIndex: nextSortIndex
            ) else { continue }

            modelContext.insert(todo)
            existingTodos.append(todo)
            nextSortIndex += 1
        }

        try? modelContext.save()
    }

    private func taskSort(_ lhs: Todo, _ rhs: Todo) -> Bool {
        if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
        if lhs.priority != rhs.priority {
            return priorityRank(lhs.priority) < priorityRank(rhs.priority)
        }
        return lhs.sortIndex < rhs.sortIndex
    }

    private func priorityRank(_ priority: TodoPriority) -> Int {
        switch priority {
        case .high: 0
        case .medium: 1
        case .low: 2
        }
    }
}

struct IOSTaskRow: View {
    @Environment(\.modelContext) private var modelContext

    let todo: Todo
    let edit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TodoProgressControl(todo: todo) {
                if todo.setManuallyCompleted(!todo.isCompleted) {
                    try? modelContext.save()
                }
            }

            Text(todo.direction?.symbolName ?? DefaultDirections.taskInboxSymbol)
                .font(.title3)

            VStack(alignment: .leading, spacing: 3) {
                Text(TodoDisplay.title(for: todo))
                    .font(.body.weight(.medium))
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)

                HStack(spacing: 5) {
                    if let direction = todo.direction {
                        Text(direction.name)
                            .foregroundStyle(Color(hex: direction.colorHex))
                    }
                    Text("·")
                    Text(todo.priority.displayName)
                    Text("·")
                    Text(progressText)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: edit)
    }

    private var progressText: String {
        TodoProgressCalculator().summary(
            measurement: todo.measurement,
            plannedAmount: todo.plannedAmount,
            actualProgress: todo.actualProgress,
            focusDurationSeconds: todo.recordedFocusSeconds
        )
    }
}

enum IOSTaskEditorMode: Identifiable {
    case create
    case edit(Todo)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let todo): todo.id.uuidString
        }
    }
}
