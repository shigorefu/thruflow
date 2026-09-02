//
//  DayHistoryBuilder.swift
//  ThruFlow
//
//

import Foundation

@MainActor
struct DayHistorySnapshot {
    let date: Date
    let interval: DateInterval
    let flows: [DayHistoryFlow]
    let completedTasks: [DayHistoryTask]
    let relevantTodos: [Todo]

    var totalFocusSeconds: Int {
        flows.reduce(0) { $0 + $1.focusSeconds }
    }

    var completedTaskCount: Int {
        completedTasks.count
    }

    var flowCount: Int {
        Set(flows.map(\.sessionID)).count
    }

    var areaSummaries: [DayHistoryAreaSummary] {
        let flowGroups = Dictionary(grouping: flows, by: \DayHistoryFlow.areaID)
        let todoGroups = Dictionary(grouping: relevantTodos) { todo in
            todo.area?.id
        }
        let workedTaskSummaries = taskSummaries.filter { $0.todo != nil }
        let areaIDs = Set(flowGroups.keys).union(todoGroups.keys.compactMap { $0 })

        return areaIDs.compactMap { areaID in
            let areaFlows = flowGroups[areaID] ?? []
            let areaTodos = todoGroups[areaID] ?? []
            guard let firstFlow = areaFlows.first else {
                guard let area = areaTodos.first?.area else { return nil }
                return DayHistoryAreaSummary(
                    areaID: area.id,
                    areaType: area.type,
                    symbol: area.symbolName,
                    name: area.name,
                    colorHex: area.colorHex,
                    focusSeconds: 0,
                    flowCount: 0,
                    taskCount: workedTaskSummaries.filter {
                        $0.areaID == areaID
                    }.count
                )
            }
            return DayHistoryAreaSummary(
                areaID: firstFlow.areaID,
                areaType: firstFlow.areaType,
                symbol: firstFlow.areaSymbol,
                name: firstFlow.areaName,
                colorHex: firstFlow.areaColorHex,
                focusSeconds: areaFlows.reduce(0) { $0 + $1.focusSeconds },
                flowCount: Set(areaFlows.map(\.sessionID)).count,
                taskCount: workedTaskSummaries.filter {
                    $0.areaID == areaID
                }.count
            )
        }
        .sorted {
            if $0.focusSeconds == $1.focusSeconds {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return $0.focusSeconds > $1.focusSeconds
        }
    }

    var taskSummaries: [DayHistoryTaskSummary] {
        let flowsByTodo = Dictionary(grouping: flows.compactMap { flow -> DayHistoryFlow? in
            flow.todoID == nil ? nil : flow
        }, by: { $0.todoID! })

        let groupedTodos = Dictionary(grouping: relevantTodos, by: DayHistoryTaskGroupKey.init)
        var summaries = groupedTodos.values.compactMap { groupedTodos -> DayHistoryTaskSummary? in
            let scheduledTodos = groupedTodos.filter { todo in
                guard let scheduledDate = todo.scheduledDate else { return false }
                return interval.contains(scheduledDate)
            }
            let displayedTodos = scheduledTodos.isEmpty ? groupedTodos : scheduledTodos
            guard let representative = displayedTodos.sorted(by: { left, right in
                if left.isCompleted != right.isCompleted {
                    return !left.isCompleted
                }
                return (left.scheduledDate ?? left.createdAt) > (right.scheduledDate ?? right.createdAt)
            }).first else { return nil }
            let todoIDs = Set(groupedTodos.map(\.id))
            let todoFlows = todoIDs.flatMap { flowsByTodo[$0] ?? [] }
            let area = representative.area
            return DayHistoryTaskSummary(
                todoID: representative.id,
                todos: [representative] + displayedTodos.filter { $0.id != representative.id },
                linkedTodoIDs: todoIDs,
                areaID: area?.id,
                areaType: area?.type ?? .neutral,
                title: TodoDisplay.title(for: representative),
                areaSymbol: area?.symbolName ?? "📥",
                areaName: area?.name ?? String(localized: "その他"),
                areaColorHex: area?.colorHex ?? "#8E8E93",
                focusSeconds: todoFlows.reduce(0) { $0 + $1.focusSeconds },
                flowCount: Set(todoFlows.map(\.sessionID)).count
            )
        }

        let areaOnlyGroups = Dictionary(grouping: flows.filter { $0.todoID == nil }) {
            $0.areaID
        }
        summaries.append(contentsOf: areaOnlyGroups.values.map { flows in
            let first = flows[0]
            return DayHistoryTaskSummary(
                todoID: first.todoID,
                todos: [],
                linkedTodoIDs: [],
                areaID: first.areaID,
                areaType: first.areaType,
                title: first.taskTitle,
                areaSymbol: first.areaSymbol,
                areaName: first.areaName,
                areaColorHex: first.areaColorHex,
                focusSeconds: flows.reduce(0) { $0 + $1.focusSeconds },
                flowCount: Set(flows.map(\.sessionID)).count
            )
        })

        return summaries
            .filter { $0.focusSeconds > 0 }
            .sorted {
                if $0.focusSeconds == $1.focusSeconds {
                    return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }
                return $0.focusSeconds > $1.focusSeconds
            }
    }
}

struct DayHistoryFlow: Identifiable {
    let id: UUID
    let sessionID: UUID
    let session: FlowSession
    let segment: FlowSegment?
    let startedAt: Date
    let endedAt: Date
    let focusSeconds: Int
    let breakSeconds: Int
    let todoID: UUID?
    let taskTitle: String
    let areaID: UUID
    let areaType: AreaType
    let areaSymbol: String
    let areaName: String
    let areaColorHex: String
    let memo: String?
}

struct DayHistoryTask: Identifiable {
    let id: UUID
    let todo: Todo
    let title: String
    let completedAt: Date?
    let areaSymbol: String
    let areaName: String
    let areaColorHex: String

    var hasExactCompletionTime: Bool {
        completedAt != nil
    }
}

@MainActor
struct DayHistoryTaskSummary: Identifiable {
    let todoID: UUID?
    let todos: [Todo]
    let linkedTodoIDs: Set<UUID>
    let areaID: UUID?
    let areaType: AreaType
    let title: String
    let areaSymbol: String
    let areaName: String
    let areaColorHex: String
    let focusSeconds: Int
    let flowCount: Int

    var todo: Todo? { todos.first }

    var id: String {
        todoID?.uuidString ?? "area-only-\(areaName)"
    }
}

struct DayHistoryAreaSummary: Identifiable {
    let areaID: UUID
    let areaType: AreaType
    let symbol: String
    let name: String
    let colorHex: String
    let focusSeconds: Int
    let flowCount: Int
    let taskCount: Int

    var id: UUID { areaID }
}

@MainActor
private struct DayHistoryTaskGroupKey: Hashable {
    let value: String

    init(todo: Todo) {
        value = "todo-\(todo.id.uuidString)"
    }
}

@MainActor
struct DayHistoryBuilder {
    private let calendar: Calendar
    private let dayBoundary: AppDayBoundary

    init(
        calendar: Calendar = .current,
        dayBoundary: AppDayBoundary = .midnight
    ) {
        self.calendar = calendar
        self.dayBoundary = dayBoundary
    }

    func build(date: Date, sessions: [FlowSession], todos: [Todo]) -> DayHistorySnapshot {
        let day = calendar.startOfDay(for: date)
        return build(
            interval: dayBoundary.interval(for: day, calendar: calendar),
            sessions: sessions,
            todos: todos
        )
    }

    func build(interval: DateInterval, sessions: [FlowSession], todos: [Todo]) -> DayHistorySnapshot {
        let start = calendar.startOfDay(for: interval.start)
        let flows = sessions
            .filter { session in
                interval.contains(session.startedAt)
                    && session.resolvedActualFocusDurationSeconds > 0
                    && session.status != .interrupted
            }
            .flatMap(makeFlows)
            .sorted { $0.startedAt < $1.startedAt }

        let completedTasks = todos
            .filter { todo in
                guard todo.status == .completed, !todo.isDeleted else { return false }
                return interval.contains(todo.completedAt ?? todo.updatedAt)
            }
            .map(makeTask)
            .sorted { left, right in
                switch (left.completedAt, right.completedAt) {
                case let (leftDate?, rightDate?):
                    leftDate < rightDate
                case (.some, .none):
                    true
                case (.none, .some):
                    false
                case (.none, .none):
                    left.title.localizedStandardCompare(right.title) == .orderedAscending
                }
            }

        let flowedTodoIDs = Set(flows.compactMap(\.todoID))
        let relevantTodos = todos.filter { todo in
            guard !todo.isDeleted, !todo.isArchived else { return false }
            if flowedTodoIDs.contains(todo.id) { return true }
            if let scheduledDate = todo.scheduledDate, interval.contains(scheduledDate) { return true }
            if let completedAt = todo.completedAt, interval.contains(completedAt) { return true }
            return false
        }

        return DayHistorySnapshot(
            date: start,
            interval: interval,
            flows: flows,
            completedTasks: completedTasks,
            relevantTodos: relevantTodos
        )
    }

    private func makeFlows(_ session: FlowSession) -> [DayHistoryFlow] {
        if !session.resolvedSegments.isEmpty {
            return session.resolvedSegments.compactMap { segment in
                let focusSeconds = segment.resolvedFocusSeconds
                guard focusSeconds > 0 else { return nil }
                return makeFlow(
                    id: segment.id,
                    session: session,
                    segment: segment,
                    area: segment.area,
                    todo: segment.todo,
                    startedAt: segment.startedAt,
                    endedAt: segment.endedAt ?? segment.startedAt.addingTimeInterval(TimeInterval(focusSeconds)),
                    focusSeconds: focusSeconds,
                    breakSeconds: 0
                )
            }
        }

        return [makeFlow(
            id: session.id,
            session: session,
            segment: nil,
            area: session.area,
            todo: session.todo,
            startedAt: session.startedAt,
            endedAt: session.endedAt ?? session.startedAt.addingTimeInterval(TimeInterval(session.resolvedActualFocusDurationSeconds)),
            focusSeconds: session.resolvedActualFocusDurationSeconds,
            breakSeconds: session.plannedBreakDurationSeconds
        )]
    }

    private func makeFlow(
        id: UUID,
        session: FlowSession,
        segment: FlowSegment?,
        area: Area?,
        todo: Todo?,
        startedAt: Date,
        endedAt: Date,
        focusSeconds: Int,
        breakSeconds: Int
    ) -> DayHistoryFlow {
        let fallbackName = String(localized: "その他")
        let taskTitle = todo.map(TodoDisplay.title(for:)) ?? "(\(area?.name ?? fallbackName))"

        return DayHistoryFlow(
            id: id,
            sessionID: session.id,
            session: session,
            segment: segment,
            startedAt: startedAt,
            endedAt: endedAt,
            focusSeconds: focusSeconds,
            breakSeconds: breakSeconds,
            todoID: todo?.id,
            taskTitle: taskTitle,
            areaID: area?.id ?? session.id,
            areaType: area?.type ?? .neutral,
            areaSymbol: area?.symbolName ?? "📥",
            areaName: area?.name ?? fallbackName,
            areaColorHex: area?.colorHex ?? "#8E8E93",
            memo: session.result ?? todo?.notes
        )
    }

    private func makeTask(_ todo: Todo) -> DayHistoryTask {
        let area = todo.area
        let areaName = area?.name ?? String(localized: "その他")
        return DayHistoryTask(
            id: todo.id,
            todo: todo,
            title: TodoDisplay.title(for: todo),
            completedAt: todo.completedAt,
            areaSymbol: area?.symbolName ?? "📥",
            areaName: areaName,
            areaColorHex: area?.colorHex ?? "#8E8E93"
        )
    }
}
