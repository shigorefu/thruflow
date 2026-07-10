//
//  DayHistoryBuilder.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/11.
//

import Foundation

struct DayHistorySnapshot {
    let date: Date
    let flows: [DayHistoryFlow]
    let completedTasks: [DayHistoryTask]

    var totalFocusSeconds: Int {
        flows.reduce(0) { $0 + $1.focusSeconds }
    }

    var completedTaskCount: Int {
        completedTasks.count
    }

    var directionSummaries: [DayHistoryDirectionSummary] {
        let grouped = Dictionary(grouping: flows, by: \DayHistoryFlow.directionID)

        return grouped.values.map { flows in
            let first = flows[0]
            return DayHistoryDirectionSummary(
                directionID: first.directionID,
                symbol: first.directionSymbol,
                name: first.directionName,
                colorHex: first.directionColorHex,
                focusSeconds: flows.reduce(0) { $0 + $1.focusSeconds },
                flowCount: flows.count
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
        let grouped = Dictionary(grouping: flows) { flow in
            DayHistoryTaskKey(todoID: flow.todoID, directionID: flow.directionID)
        }

        return grouped.values.map { flows in
            let first = flows[0]
            return DayHistoryTaskSummary(
                todoID: first.todoID,
                title: first.taskTitle,
                directionSymbol: first.directionSymbol,
                directionName: first.directionName,
                directionColorHex: first.directionColorHex,
                focusSeconds: flows.reduce(0) { $0 + $1.focusSeconds },
                flowCount: flows.count
            )
        }
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

struct DayHistoryTaskSummary: Identifiable {
    let todoID: UUID?
    let title: String
    let directionSymbol: String
    let directionName: String
    let directionColorHex: String
    let focusSeconds: Int
    let flowCount: Int

    var id: String {
        todoID?.uuidString ?? "direction-only-\(directionName)"
    }
}

struct DayHistoryDirectionSummary: Identifiable {
    let directionID: UUID
    let symbol: String
    let name: String
    let colorHex: String
    let focusSeconds: Int
    let flowCount: Int

    var id: UUID { directionID }
}

private struct DayHistoryTaskKey: Hashable {
    let todoID: UUID?
    let directionID: UUID
}

@MainActor
struct DayHistoryBuilder {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func build(date: Date, sessions: [FlowSession], todos: [Todo]) -> DayHistorySnapshot {
        let day = calendar.startOfDay(for: date)
        let flows = sessions
            .filter { session in
                calendar.isDate(session.startedAt, inSameDayAs: day)
                    && session.resolvedActualFocusDurationSeconds > 0
                    && session.status != .interrupted
            }
            .map(makeFlow)
            .sorted { $0.startedAt < $1.startedAt }

        let completedTasks = todos
            .filter { todo in
                guard todo.status == .completed, !todo.isDeleted else { return false }
                return calendar.isDate(todo.completedAt ?? todo.updatedAt, inSameDayAs: day)
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

        return DayHistorySnapshot(date: day, flows: flows, completedTasks: completedTasks)
    }

    private func makeFlow(_ session: FlowSession) -> DayHistoryFlow {
        let direction = session.direction
        let fallbackName = "その他"
        let taskTitle = session.todo.map(TodoDisplay.title(for:)) ?? "(\(direction?.name ?? fallbackName))"

        return DayHistoryFlow(
            id: session.id,
            session: session,
            startedAt: session.startedAt,
            endedAt: session.endedAt ?? session.startedAt.addingTimeInterval(TimeInterval(session.resolvedActualFocusDurationSeconds)),
            focusSeconds: session.resolvedActualFocusDurationSeconds,
            breakSeconds: session.plannedBreakDurationSeconds,
            todoID: session.todo?.id,
            taskTitle: taskTitle,
            directionID: direction?.id ?? session.id,
            directionSymbol: direction?.symbolName ?? "📥",
            directionName: direction?.name ?? fallbackName,
            directionColorHex: direction?.colorHex ?? "#8E8E93",
            memo: session.todo?.notes
        )
    }

    private func makeTask(_ todo: Todo) -> DayHistoryTask {
        let direction = todo.direction
        let directionName = direction?.name ?? "その他"
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
