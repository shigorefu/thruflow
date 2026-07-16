//
//  InboxView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/09.
//

import SwiftData
import SwiftUI

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Todo.createdAt, order: .forward) private var todos: [Todo]

    @State private var editingTodo: Todo?

    private let filter = InboxTodoFilter()

    private var inboxTodos: [Todo] {
        todos.filter { filter.includes($0) }
    }

    var body: some View {
        List {
            if inboxTodos.isEmpty {
                ContentUnavailableView(
                    "Inboxは空です",
                    systemImage: "tray",
                    description: Text("日付なしのタスクがここに表示されます。")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(inboxTodos) { todo in
                    InboxTodoRow(todo: todo)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            editingTodo = todo
                        }
                        .contextMenu {
                            Button("今日へ", systemImage: "sun.max") {
                                schedule(todo, to: .now)
                            }

                            Button("明日へ", systemImage: "calendar.badge.clock") {
                                schedule(
                                    todo,
                                    to: Calendar.current.date(byAdding: .day, value: 1, to: .now)
                                )
                            }

                            Button("編集", systemImage: "pencil") {
                                editingTodo = todo
                            }

                            Divider()

                            Button("削除", systemImage: "trash", role: .destructive) {
                                todo.softDelete()
                                try? modelContext.save()
                            }
                        }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle("Inbox")
        .sheet(item: $editingTodo) { todo in
            TodoFormView(mode: .edit(todo))
        }
    }

    private func schedule(_ todo: Todo, to date: Date?) {
        todo.reschedule(to: date)
        try? modelContext.save()
    }
}

private struct InboxTodoRow: View {
    let todo: Todo

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(tint, lineWidth: 1.5)
                .frame(width: 20, height: 20)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(TodoDisplay.title(for: todo))
                    .font(.body.weight(.medium))

                HStack(spacing: 6) {
                    if let direction = todo.direction, !DefaultDirections.isTaskInbox(direction) {
                        Text("\(direction.symbolName) \(direction.name)")
                        Text("·")
                    }

                    Text(todo.priority.displayName)
                    Text("·")
                    Text(TodoProgressCalculator().summary(
                        measurement: todo.measurement,
                        plannedAmount: todo.plannedAmount,
                        actualProgress: todo.actualProgress,
                        focusDurationSeconds: todo.focusDurationSeconds
                    ))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .listRowInsets(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10))
        .listRowSeparator(.hidden)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 10)
                .fill(tint.opacity(0.08))
                .padding(.vertical, 2)
        )
    }

    private var tint: Color {
        guard let direction = todo.direction, !DefaultDirections.isTaskInbox(direction) else {
            return Color.secondary.opacity(0.6)
        }

        return Color(hex: direction.colorHex)
    }
}

#Preview {
    InboxView()
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self], inMemory: true)
}
