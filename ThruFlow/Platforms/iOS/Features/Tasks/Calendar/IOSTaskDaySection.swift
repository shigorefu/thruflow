#if os(iOS)
import SwiftUI

struct IOSTaskDaySection: View {
    let date: Date
    let todos: [Todo]
    var suppressesEmptyState = false
    var firstRowIndex = 0
    let revealsInitialRows: Bool
    let onEditTodo: (Todo) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            Text(date, format: .dateTime.month().day().weekday())
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            let grouped = IOSGroupedTodos(todos: todos)
            IOSTaskDayGroup(
                title: String(localized: "習慣一覧"),
                todos: grouped.habits,
                firstRowIndex: firstRowIndex,
                revealsInitialRows: revealsInitialRows,
                onEditTodo: onEditTodo
            )
            IOSTaskDayGroup(
                title: String(localized: "タスク"),
                todos: grouped.tasks,
                firstRowIndex: firstRowIndex + grouped.habits.count,
                revealsInitialRows: revealsInitialRows,
                onEditTodo: onEditTodo
            )
            if !grouped.nice.isEmpty {
                IOSTaskDayGroup(
                    title: String(localized: "ナイス"),
                    todos: grouped.nice,
                    firstRowIndex: firstRowIndex + grouped.habits.count + grouped.tasks.count,
                    revealsInitialRows: revealsInitialRows,
                    onEditTodo: onEditTodo
                )
            }

            if todos.isEmpty && !suppressesEmptyState {
                ContentUnavailableView(
                    String(localized: "今日の項目はありません"),
                    systemImage: "checkmark.circle"
                )
                .frame(maxWidth: .infinity, minHeight: 150)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct IOSTaskDayGroup: View {
    let title: String
    let todos: [Todo]
    let firstRowIndex: Int
    let revealsInitialRows: Bool
    let onEditTodo: (Todo) -> Void

    @ViewBuilder
    var body: some View {
        if !todos.isEmpty {
            LazyVStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                IOSTaskCalendarRows(
                    todos: todos,
                    firstRowIndex: firstRowIndex,
                    revealsInitialRows: revealsInitialRows,
                    onEditTodo: onEditTodo
                )
            }
        }
    }
}

struct IOSTaskCalendarRows: View {
    let todos: [Todo]
    let firstRowIndex: Int
    let revealsInitialRows: Bool
    let onEditTodo: (Todo) -> Void

    var body: some View {
        ForEach(Array(todos.enumerated()), id: \.element.id) { index, todo in
            IOSTaskRow(todo: todo) { onEditTodo(todo) }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .featureRowReveal(index: firstRowIndex + index, enabled: revealsInitialRows)
        }
    }
}

private struct IOSGroupedTodos {
    let habits: [Todo]
    let tasks: [Todo]
    let nice: [Todo]

    init(todos: [Todo]) {
        habits = todos.filter { $0.taskType == .habit }
        tasks = todos.filter { todo in
            guard let area = todo.area else { return true }
            return todo.taskType == .neutral || DefaultAreas.isTaskInbox(area)
        }
        nice = todos.filter { $0.taskType == .nice }
    }
}
#endif
