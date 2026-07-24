//
//  HistoryTaskRecordEditor.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/24.
//

import Foundation
import SwiftData

enum HistoryTaskRecordError: Error, Equatable {
    case emptyTitle
    case invalidPlannedAmount
    case missingDirection
}

struct HistoryTaskRecordResult {
    let todo: Todo
    let flowSession: FlowSession?
}

@MainActor
struct HistoryTaskRecordEditor {
    var calendar: Calendar = .current

    func availableTodos(on date: Date, from todos: [Todo]) -> [Todo] {
        todos
            .filter { todo in
                guard !todo.isDeleted,
                      !todo.isArchived,
                      todo.direction != nil,
                      let scheduledDate = todo.scheduledDate else {
                    return false
                }
                return calendar.isDate(scheduledDate, inSameDayAs: date)
            }
            .sorted(by: taskSort)
    }

    @discardableResult
    func record(
        todo: Todo,
        recordedAt: Date,
        mode: FlowMode,
        focusSeconds: Int,
        modelContext: ModelContext,
        now: Date = .now
    ) throws -> HistoryTaskRecordResult {
        if todo.measurement == .checkbox {
            todo.setManuallyCompleted(true, now: recordedAt)
            todo.completedAt = recordedAt
            todo.updatedAt = now
            return HistoryTaskRecordResult(todo: todo, flowSession: nil)
        }

        guard let direction = todo.direction else {
            throw HistoryTaskRecordError.missingDirection
        }
        let session = FlowHistoryEditor().createManual(
            todo: todo,
            direction: direction,
            mode: mode,
            startedAt: recordedAt,
            focusSeconds: focusSeconds,
            modelContext: modelContext,
            now: now
        )
        return HistoryTaskRecordResult(todo: todo, flowSession: session)
    }

    @discardableResult
    func createAndRecord(
        title: String,
        direction: Direction,
        measurement: TodoMeasurement,
        priority: TodoPriority,
        isRoomIfPossible: Bool,
        plannedAmount: Int?,
        scheduledDate: Date,
        recordedAt: Date,
        mode: FlowMode,
        focusSeconds: Int,
        modelContext: ModelContext,
        now: Date = .now
    ) throws -> HistoryTaskRecordResult {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            throw HistoryTaskRecordError.emptyTitle
        }
        if measurement != .checkbox, max(0, plannedAmount ?? 0) == 0 {
            throw HistoryTaskRecordError.invalidPlannedAmount
        }

        let todo = Todo(
            title: normalizedTitle,
            direction: direction,
            measurement: measurement,
            priority: priority,
            isRoomIfPossible: priority == .low && isRoomIfPossible,
            plannedAmount: measurement == .checkbox ? nil : plannedAmount,
            scheduledDate: calendar.startOfDay(for: scheduledDate),
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(todo)

        return try record(
            todo: todo,
            recordedAt: recordedAt,
            mode: mode,
            focusSeconds: focusSeconds,
            modelContext: modelContext,
            now: now
        )
    }

    private func taskSort(_ lhs: Todo, _ rhs: Todo) -> Bool {
        let lhsHabit = lhs.direction?.type == .habit
        let rhsHabit = rhs.direction?.type == .habit
        if lhsHabit != rhsHabit { return lhsHabit }
        if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
        if lhs.priority != rhs.priority {
            return priorityRank(lhs.priority) < priorityRank(rhs.priority)
        }
        if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
        return lhs.createdAt < rhs.createdAt
    }

    private func priorityRank(_ priority: TodoPriority) -> Int {
        switch priority {
        case .high: 0
        case .medium: 1
        case .low: 2
        }
    }
}
