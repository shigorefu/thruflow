//
//  HabitTodoMaterializer.swift
//  ThruFlow
//

import Foundation
import SwiftData

@MainActor
struct HabitTodoMaterializer {
    var calendar: Calendar = .current
    var dayBoundary: AppDayBoundary = .midnight

    @discardableResult
    func materialize(
        areas: [Area],
        dates: [Date],
        modelContext: ModelContext,
        now: Date = .now,
        knownTodos: [Todo]? = nil,
        reconcilesDuplicates: Bool = true
    ) throws -> Bool {
        var todos: [Todo]
        if let knownTodos {
            todos = knownTodos
        } else {
            todos = try modelContext.fetch(FetchDescriptor<Todo>())
        }
        var changed = false

        if reconcilesDuplicates {
            let sessions = try modelContext.fetch(FetchDescriptor<FlowSession>())
            let segments = try modelContext.fetch(FetchDescriptor<FlowSegment>())
            let reconciliation = HabitTodoReconciler(calendar: calendar).reconcile(
                todos: todos,
                sessions: sessions,
                segments: segments,
                now: now
            )
            changed = reconciliation.changed

            if reconciliation.changed {
                try FlowProgressReconciler().reconcile(
                    todos: reconciliation.canonicalTodos.map(Optional.some),
                    areas: reconciliation.affectedAreas.map(Optional.some),
                    modelContext: modelContext,
                    now: now
                )
                todos = try modelContext.fetch(FetchDescriptor<Todo>())
            }
        }

        var knownTodos = todos.filter { !$0.isDeleted && !$0.isArchived }
        var nextSortIndex = (knownTodos.map(\.sortIndex).min() ?? 0) - 1
        let today = dayBoundary.day(containing: now, calendar: calendar)
        let normalizedDates = uniqueDays(dates).sorted()
        let planner = RequiredTodoPlanner(calendar: calendar)
        let activeHabits = areas.filter { $0.type == .habit && !$0.isArchived }

        for date in normalizedDates {
            for area in activeHabits {
                if area.goalSchedule == .weeklyCount &&
                    !calendar.isDate(date, inSameDayAs: today) {
                    continue
                }

                if let pendingTodo = planner.pendingWeeklyTodoToRollForward(
                    for: area,
                    in: knownTodos,
                    on: date
                ) {
                    pendingTodo.reschedule(to: date, now: now)
                    changed = true
                    continue
                }

                guard let todo = planner.makeRequiredTodo(
                    for: area,
                    existingTodos: knownTodos,
                    on: date,
                    sortIndex: nextSortIndex
                ) else {
                    continue
                }

                modelContext.insert(todo)
                knownTodos.append(todo)
                nextSortIndex -= 1
                changed = true
            }
        }

        if changed {
            try modelContext.save()
        }
        return changed
    }

    private func uniqueDays(_ dates: [Date]) -> [Date] {
        var seen = Set<Date>()
        return dates
            .map(calendar.startOfDay(for:))
            .filter { seen.insert($0).inserted }
    }
}
