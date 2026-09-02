import Foundation

@MainActor
struct ProductWidgetSnapshotBuilder {
    private let calendar: Calendar
    private let dayBoundary: AppDayBoundary
    private let todoSorter = FlowDashboardTodoSorter()

    init(
        calendar: Calendar = .current,
        dayBoundary: AppDayBoundary = .midnight
    ) {
        self.calendar = calendar
        self.dayBoundary = dayBoundary
    }

    func tasksSnapshot(
        todos: [Todo],
        now: Date = .now
    ) -> TasksWidgetSnapshot {
        let items = todoSorter.sorted(
            todos.filter {
                TodayTodoFilter(
                    calendar: calendar,
                    dayBoundary: dayBoundary
                ).includes($0, now: now)
            }
        )
        .map(makeTaskItem)

        return TasksWidgetSnapshot(
            generatedAt: now,
            date: dayBoundary.day(containing: now, calendar: calendar),
            items: items
        )
    }

    func dotsSnapshot(
        sessions: [FlowSession],
        now: Date = .now
    ) -> DotsWidgetSnapshot {
        let result = StatisticsHeatmapBuilder(
            calendar: calendar,
            dayBoundary: dayBoundary
        ).build(
            sessions: sessions,
            filter: StatisticsFilter(range: .days180),
            now: now
        )

        return DotsWidgetSnapshot(
            generatedAt: now,
            days: result.days.map {
                DotsWidgetDaySnapshot(
                    date: $0.date,
                    focusedSeconds: $0.totalFocusSeconds,
                    mixedColorHex: $0.mixedColorHex
                )
            }
        )
    }

    private func makeTaskItem(_ todo: Todo) -> TaskWidgetItemSnapshot {
        TaskWidgetItemSnapshot(
            id: todo.id,
            title: TodoDisplay.title(for: todo),
            areaSymbol: todo.area?.symbolName ?? "📝",
            areaName: todo.area?.name ?? String(localized: "その他"),
            areaColorHex: todo.area?.colorHex ?? "#8E8E93",
            measurement: TaskWidgetMeasurement(rawValue: todo.measurement.rawValue) ?? .checkbox,
            plannedAmount: max(0, todo.plannedAmount ?? 0),
            actualProgress: max(0, todo.actualProgress),
            focusedSeconds: todo.recordedFocusSeconds,
            isCompleted: todo.isCompleted
        )
    }
}
