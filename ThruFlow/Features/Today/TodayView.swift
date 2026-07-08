//
//  TodayView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import SwiftData
import SwiftUI

struct TodayView: View {
    @Query(sort: \Direction.name, order: .forward) private var directions: [Direction]
    @Query(sort: \Todo.createdAt, order: .forward) private var todos: [Todo]

    @State private var isShowingTodoSheet = false
    @State private var editingTodo: Todo?

    private let filter = TodayTodoFilter()
    private let progress = TodoProgressCalculator()

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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingTodoSheet = true
                } label: {
                    Label("タスクを追加", systemImage: "plus")
                }
                .disabled(activeDirections.isEmpty)
            }
        }
        .overlay {
            if activeDirections.isEmpty {
                ContentUnavailableView(
                    "方向が必要です",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("タスクを作る前に、方向を作成してください。")
                )
            }
        }
        .sheet(isPresented: $isShowingTodoSheet) {
            TodoFormView(mode: .create)
        }
        .sheet(item: $editingTodo) { todo in
            TodoFormView(mode: .edit(todo))
        }
    }
}

private struct DirectionRequirementRow: View {
    let direction: Direction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: direction.symbolName)
                .foregroundStyle(Color(hex: direction.colorHex))
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
