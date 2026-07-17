//
//  DayHistoryBuilder.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/11.
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

    var directionSummaries: [DayHistoryDirectionSummary] {
        let flowGroups = Dictionary(grouping: flows, by: \DayHistoryFlow.directionID)
        let todoGroups = Dictionary(grouping: relevantTodos) { todo in
            todo.direction?.id
        }
        let directionIDs = Set(flowGroups.keys).union(todoGroups.keys.compactMap { $0 })

        return directionIDs.compactMap { directionID in
            let directionFlows = flowGroups[directionID] ?? []
            let directionTodos = todoGroups[directionID] ?? []
            guard let firstFlow = directionFlows.first else {
                guard let direction = directionTodos.first?.direction else { return nil }
                return DayHistoryDirectionSummary(
                    directionID: direction.id,
                    symbol: direction.symbolName,
                    name: direction.name,
                    colorHex: direction.colorHex,
                    focusSeconds: 0,
                    flowCount: 0,
                    taskCount: Set(directionTodos.map(DayHistoryTaskGroupKey.init)).count
                )
            }
            return DayHistoryDirectionSummary(
                directionID: firstFlow.directionID,
                symbol: firstFlow.directionSymbol,
                name: firstFlow.directionName,
                colorHex: firstFlow.directionColorHex,
                focusSeconds: directionFlows.reduce(0) { $0 + $1.focusSeconds },
                flowCount: Set(directionFlows.map(\.sessionID)).count,
                taskCount: Set(directionTodos.map(DayHistoryTaskGroupKey.init)).count
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
            let direction = representative.direction
            return DayHistoryTaskSummary(
                todoID: representative.id,
                todos: [representative] + displayedTodos.filter { $0.id != representative.id },
                linkedTodoIDs: todoIDs,
                directionID: direction?.id,
                title: TodoDisplay.title(for: representative),
                directionSymbol: direction?.symbolName ?? "📥",
                directionName: direction?.name ?? String(localized: "その他"),
                directionColorHex: direction?.colorHex ?? "#8E8E93",
                focusSeconds: todoFlows.reduce(0) { $0 + $1.focusSeconds },
                flowCount: Set(todoFlows.map(\.sessionID)).count
            )
        }

        let directionOnlyGroups = Dictionary(grouping: flows.filter { $0.todoID == nil }) {
            $0.directionID
        }
        summaries.append(contentsOf: directionOnlyGroups.values.map { flows in
            let first = flows[0]
            return DayHistoryTaskSummary(
                todoID: first.todoID,
                todos: [],
                linkedTodoIDs: [],
                directionID: first.directionID,
                title: first.taskTitle,
                directionSymbol: first.directionSymbol,
                directionName: first.directionName,
                directionColorHex: first.directionColorHex,
                focusSeconds: flows.reduce(0) { $0 + $1.focusSeconds },
                flowCount: Set(flows.map(\.sessionID)).count
            )
        })

        return summaries.sorted {
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
    let startedAt: Date
    let endedAt: Date
    let focusSeconds: Int
    let breakSeconds: Int
    let todoID: UUID?
    let taskTitle: String
    let directionID: UUID
    let directionSymbol: String
    let directionName: String
    let directionColorHex: String
    let memo: String?
}

struct DayHistoryTask: Identifiable {
    let id: UUID
    let todo: Todo
    let title: String
    let completedAt: Date?
    let directionSymbol: String
    let directionName: String
    let directionColorHex: String

    var hasExactCompletionTime: Bool {
        completedAt != nil
    }
}

@MainActor
struct DayHistoryTaskSummary: Identifiable {
    let todoID: UUID?
    let todos: [Todo]
    let linkedTodoIDs: Set<UUID>
    let directionID: UUID?
    let title: String
    let directionSymbol: String
    let directionName: String
    let directionColorHex: String
    let focusSeconds: Int
    let flowCount: Int

    var todo: Todo? { todos.first }

    var isHabit: Bool {
        todo?.direction?.type == .habit
    }

    var id: String {
        if isHabit, let directionID {
            return "habit-\(directionID.uuidString)"
        }
        return todoID?.uuidString ?? "direction-only-\(directionName)"
    }
}

struct DayHistoryDirectionSummary: Identifiable {
    let directionID: UUID
    let symbol: String
    let name: String
    let colorHex: String
    let focusSeconds: Int
    let flowCount: Int
    let taskCount: Int

    var id: UUID { directionID }
}

@MainActor
private struct DayHistoryTaskGroupKey: Hashable {
    let value: String

    init(todo: Todo) {
        if todo.direction?.type == .habit, let directionID = todo.direction?.id {
            value = "habit-\(directionID.uuidString)"
        } else {
            value = "todo-\(todo.id.uuidString)"
        }
    }
}

@MainActor
struct DayHistoryBuilder {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func build(date: Date, sessions: [FlowSession], todos: [Todo]) -> DayHistorySnapshot {
        let day = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        return build(interval: DateInterval(start: day, end: end), sessions: sessions, todos: todos)
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
        if !session.segments.isEmpty {
            return session.segments.compactMap { segment in
                let focusSeconds = segment.resolvedFocusSeconds
                guard focusSeconds > 0 else { return nil }
                return makeFlow(
                    id: segment.id,
                    session: session,
                    direction: segment.direction,
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
            direction: session.direction,
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
        direction: Direction?,
        todo: Todo?,
        startedAt: Date,
        endedAt: Date,
        focusSeconds: Int,
        breakSeconds: Int
    ) -> DayHistoryFlow {
        let fallbackName = String(localized: "その他")
        let taskTitle = todo.map(TodoDisplay.title(for:)) ?? "(\(direction?.name ?? fallbackName))"

        return DayHistoryFlow(
            id: id,
            sessionID: session.id,
            session: session,
            startedAt: startedAt,
            endedAt: endedAt,
            focusSeconds: focusSeconds,
            breakSeconds: breakSeconds,
            todoID: todo?.id,
            taskTitle: taskTitle,
            directionID: direction?.id ?? session.id,
            directionSymbol: direction?.symbolName ?? "📥",
            directionName: direction?.name ?? fallbackName,
            directionColorHex: direction?.colorHex ?? "#8E8E93",
            memo: todo?.notes
        )
    }

    private func makeTask(_ todo: Todo) -> DayHistoryTask {
        let direction = todo.direction
        let directionName = direction?.name ?? String(localized: "その他")
        return DayHistoryTask(
            id: todo.id,
            todo: todo,
            title: TodoDisplay.title(for: todo),
            completedAt: todo.completedAt,
            directionSymbol: direction?.symbolName ?? "📥",
            directionName: directionName,
            directionColorHex: direction?.colorHex ?? "#8E8E93"
        )
    }
}
