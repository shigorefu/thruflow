#if os(watchOS)
import Foundation
import SwiftData
import SwiftUI

struct WatchFlowContextPicker: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Area.sortIndex) private var areas: [Area]
    @Query private var todos: [Todo]

    var body: some View {
        List {
            if !todayTodos.isEmpty {
                Section(String(localized: "今日のタスク")) {
                    ForEach(todayTodos) { todo in
                        Button {
                            select(area: todo.area, todo: todo)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(TodoDisplay.flowTitle(for: todo))
                                        .lineLimit(1)
                                    if let minutes = todo.scheduledTimeMinutes {
                                        TaskTimeLabel(minutes: minutes, reminderEnabled: todo.reminderEnabled)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if TodoDisplay.flowProjectName(for: todo) != nil {
                                        Text(TodoDisplay.flowContextName(for: todo))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            } icon: {
                                Text(todo.area?.symbolName ?? "📝")
                            }
                        }
                    }
                }
            }

            Section(String(localized: "分野")) {
                ForEach(activeAreas) { area in
                    Button {
                        select(area: area, todo: nil)
                    } label: {
                        Label {
                            Text(area.name)
                                .lineLimit(1)
                        } icon: {
                            Text(area.symbolName)
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "タスクを選択"))
    }

    private var activeAreas: [Area] {
        areas.filter { $0.archivedAt == nil }
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

    private func select(area: Area?, todo: Todo?) {
        guard activeFlowStore.selectPickerContext(
            area: area, todo: todo, modelContext: modelContext,
            calendar: calendar, dayBoundary: dayBoundary
        ) else { return }
        dismiss()
    }

}
#endif
