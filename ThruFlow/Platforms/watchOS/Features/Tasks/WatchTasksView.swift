#if os(watchOS)
import Foundation
import SwiftData
import SwiftUI

struct WatchTasksView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [Todo]
    @State private var showsTaskForm = false

    var body: some View {
        List {
            if todayTodos.isEmpty {
                ContentUnavailableView(
                    String(localized: "今日の項目はありません"),
                    systemImage: "checkmark.circle"
                )
            } else {
                ForEach(todayTodos) { todo in
                    HStack(spacing: 5) {
                        TodoProgressControl(todo: todo) {
                            guard todo.measurement == .checkbox else { return }
                            todo.setCompleted(!todo.isCompleted)
                            _ = modelContext.saveReporting(.flowUpdate)
                        }
                        Text(todo.area?.symbolName ?? "📝")
                            .accessibilityLabel(todo.area?.name ?? String(localized: "その他"))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(TodoDisplay.taskTitle(for: todo))
                                .lineLimit(2)
                                .strikethrough(todo.isCompleted)
                            if let minutes = todo.scheduledTimeMinutes {
                                TaskTimeLabel(minutes: minutes, reminderEnabled: todo.reminderEnabled)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if todo.measurement != .checkbox {
                                Text(progressText(todo))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "今日のタスク"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsTaskForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "タスクを追加"))
            }
        }
        .sheet(isPresented: $showsTaskForm) {
            WatchTaskCreationForm()
        }
    }

    private var todayTodos: [Todo] {
        FlowDashboardTodoSorter().sorted(
            todos.filter {
                TodayTodoFilter(
                    calendar: calendar,
                    dayBoundary: dayBoundary
                ).includes($0)
            }
        )
    }

    private func progressText(_ todo: Todo) -> String {
        TodoProgressCalculator().summary(
            measurement: todo.measurement,
            plannedAmount: todo.plannedAmount,
            actualProgress: todo.actualProgress,
            focusDurationSeconds: todo.recordedFocusSeconds
        )
    }
}
#endif
