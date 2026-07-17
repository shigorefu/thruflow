//
//  TaskBacklogBuilder.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/17.
//

import Foundation

struct TaskBacklogSnapshot {
    let overdue: [Todo]
    let unscheduled: [Todo]
}

struct TaskBacklogBuilder {
    var calendar: Calendar = .current

    func build(todos: [Todo], now: Date = .now) -> TaskBacklogSnapshot {
        let today = calendar.startOfDay(for: now)
        let actionable = todos.filter(isActionableTask)

        return TaskBacklogSnapshot(
            overdue: actionable
                .filter { todo in
                    guard let scheduledDate = todo.scheduledDate else { return false }
                    return calendar.startOfDay(for: scheduledDate) < today
                }
                .sorted(by: backlogOrder),
            unscheduled: actionable
                .filter { $0.scheduledDate == nil }
                .sorted(by: backlogOrder)
        )
    }

    private func isActionableTask(_ todo: Todo) -> Bool {
        !todo.isArchived &&
        !todo.isDeleted &&
        todo.status == .active &&
        todo.direction?.type != .habit
    }

    private func backlogOrder(_ lhs: Todo, _ rhs: Todo) -> Bool {
        let leftPriority = priorityRank(lhs.priority)
        let rightPriority = priorityRank(rhs.priority)
        if leftPriority != rightPriority {
            return leftPriority < rightPriority
        }

        let leftDate = lhs.scheduledDate ?? lhs.createdAt
        let rightDate = rhs.scheduledDate ?? rhs.createdAt
        if leftDate != rightDate {
            return leftDate < rightDate
        }

        if lhs.sortIndex != rhs.sortIndex {
            return lhs.sortIndex < rhs.sortIndex
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func priorityRank(_ priority: TodoPriority) -> Int {
        switch priority {
        case .high: 0
        case .medium: 1
        case .low: 2
        }
    }
}
