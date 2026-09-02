//
//  HistoryTaskRecordEditor.swift
//  ThruFlow
//
//

import Foundation
import SwiftData

enum HistoryTaskRecordError: Error, Equatable {
    case emptyTitle
    case invalidPlannedAmount
    case missingArea
}

struct HistoryTaskRecordResult {
    let todo: Todo?
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
                      todo.area != nil,
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

        guard let area = todo.area else {
            throw HistoryTaskRecordError.missingArea
        }
        let session = try FlowHistoryEditor().createManual(
            todo: todo,
            area: area,
            mode: mode,
            startedAt: recordedAt,
            focusSeconds: focusSeconds,
            modelContext: modelContext,
            now: now
        )
        return HistoryTaskRecordResult(todo: todo, flowSession: session)
    }

    @discardableResult
    func record(
        area: Area,
        recordedAt: Date,
        mode: FlowMode,
        focusSeconds: Int,
        modelContext: ModelContext,
        now: Date = .now
    ) throws -> HistoryTaskRecordResult {
        let session = try FlowHistoryEditor().createManual(
            todo: nil,
            area: area,
            mode: mode,
            startedAt: recordedAt,
            focusSeconds: focusSeconds,
            modelContext: modelContext,
            now: now
        )
        return HistoryTaskRecordResult(todo: nil, flowSession: session)
    }

    @discardableResult
    func recordFlow(
        todo: Todo?,
        area: Area,
        recordedAt: Date,
        mode: FlowMode,
        focusSeconds: Int,
        modelContext: ModelContext,
        now: Date = .now
    ) throws -> HistoryTaskRecordResult {
        let session = try FlowHistoryEditor().createManual(
            todo: todo,
            area: area,
            mode: mode,
            startedAt: recordedAt,
            focusSeconds: focusSeconds,
            modelContext: modelContext,
            now: now
        )
        return HistoryTaskRecordResult(todo: todo, flowSession: session)
    }

    @discardableResult
    func createHabitOccurrenceAndRecord(
        area: Area,
        scheduledDate: Date,
        recordedAt: Date,
        mode: FlowMode,
        focusSeconds: Int,
        modelContext: ModelContext,
        now: Date = .now
    ) throws -> HistoryTaskRecordResult {
        guard area.type == .habit, let goalUnit = area.goalUnit else {
            throw HistoryTaskRecordError.missingArea
        }

        let todo = makeHabitOccurrence(
            area: area,
            goalUnit: goalUnit,
            scheduledDate: scheduledDate,
            modelContext: modelContext,
            now: now
        )

        return try record(
            todo: todo,
            recordedAt: recordedAt,
            mode: mode,
            focusSeconds: focusSeconds,
            modelContext: modelContext,
            now: now
        )
    }

    @discardableResult
    func createHabitOccurrenceAndRecordFlow(
        area: Area,
        scheduledDate: Date,
        recordedAt: Date,
        mode: FlowMode,
        focusSeconds: Int,
        modelContext: ModelContext,
        now: Date = .now
    ) throws -> HistoryTaskRecordResult {
        guard area.type == .habit, let goalUnit = area.goalUnit else {
            throw HistoryTaskRecordError.missingArea
        }

        let todo = makeHabitOccurrence(
            area: area,
            goalUnit: goalUnit,
            scheduledDate: scheduledDate,
            modelContext: modelContext,
            now: now
        )
        return try recordFlow(
            todo: todo,
            area: area,
            recordedAt: recordedAt,
            mode: mode,
            focusSeconds: focusSeconds,
            modelContext: modelContext,
            now: now
        )
    }

    @discardableResult
    func createAndRecord(
        title: String,
        area: Area,
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
            area: area,
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
        let lhsHabit = lhs.area?.type == .habit
        let rhsHabit = rhs.area?.type == .habit
        if lhsHabit != rhsHabit { return lhsHabit }
        if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
        if lhs.priority != rhs.priority {
            return priorityRank(lhs.priority) < priorityRank(rhs.priority)
        }
        if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
        return lhs.createdAt < rhs.createdAt
    }

    private func makeHabitOccurrence(
        area: Area,
        goalUnit: GoalUnit,
        scheduledDate: Date,
        modelContext: ModelContext,
        now: Date
    ) -> Todo {
        let target = max(1, area.goalTarget ?? 1)
        let todo = Todo(
            title: "",
            area: area,
            measurement: measurement(for: goalUnit),
            priority: .high,
            isRoomIfPossible: false,
            plannedAmount: plannedAmount(for: goalUnit, target: target),
            scheduledDate: calendar.startOfDay(for: scheduledDate),
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(todo)
        return todo
    }

    private func priorityRank(_ priority: TodoPriority) -> Int {
        switch priority {
        case .high: 0
        case .medium: 1
        case .low: 2
        }
    }

    private func measurement(for goalUnit: GoalUnit) -> TodoMeasurement {
        switch goalUnit {
        case .occurrences:
            .checkbox
        case .focusBlocks:
            .focusBlocks
        case .minutes, .hours:
            .minutes
        }
    }

    private func plannedAmount(for goalUnit: GoalUnit, target: Int) -> Int? {
        switch goalUnit {
        case .occurrences:
            nil
        case .focusBlocks, .minutes:
            target
        case .hours:
            target * 60
        }
    }
}
