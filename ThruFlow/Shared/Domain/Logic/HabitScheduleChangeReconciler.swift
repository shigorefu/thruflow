//
//  HabitScheduleChangeReconciler.swift
//  ThruFlow
//

import Foundation
import SwiftData

@MainActor
struct HabitScheduleChangeReconciler {
    var calendar: Calendar = .current
    var dayBoundary: AppDayBoundary = .midnight

    @discardableResult
    func reconcile(
        area: Area,
        todos: [Todo],
        modelContext: ModelContext,
        now: Date = .now
    ) -> Bool {
        reconcile(habit: HabitDefinition(area: area), todos: todos, modelContext: modelContext, now: now)
    }

    @discardableResult
    func reconcile(habit area: HabitDefinition, todos: [Todo], modelContext: ModelContext, now: Date = .now) -> Bool {

        let today = dayBoundary.day(containing: now, calendar: calendar)
        let planner = RequiredTodoPlanner(calendar: calendar)
        let futureTodos = todos.filter { todo in
            guard HabitDefinition(todo: todo) != nil,
                  area.owns(todo),
                  todo.externalTaskLinkRawValue == nil,
                  !todo.isArchived,
                  !todo.isDeleted,
                  let scheduledDate = todo.scheduledDate else {
                return false
            }
            return calendar.startOfDay(for: scheduledDate) >= today
        }
        let finalPlannedDay = futureTodos
            .compactMap(\.scheduledDate)
            .map(calendar.startOfDay(for:))
            .max() ?? today

        var changed = false
        for todo in futureTodos where isUnstarted(todo) {
            guard let scheduledDate = todo.scheduledDate else { continue }
            let day = calendar.startOfDay(for: scheduledDate)

            if area.goalSchedule == .weeklyCount ||
                !planner.shouldAppearToday(area, on: day) {
                todo.softDelete(now: now)
                changed = true
                continue
            }

            changed = planner.applyGeneratedTemplate(
                to: todo,
                for: area,
                now: now
            ) || changed
        }

        var knownTodos = todos
        var nextSortIndex = (todos.map(\.sortIndex).min() ?? 0) - 1
        let planningDates = area.goalSchedule == .weeklyCount
            ? [today]
            : dates(from: today, through: finalPlannedDay)

        for date in planningDates {
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

        return changed
    }

    private func isUnstarted(_ todo: Todo) -> Bool {
        !todo.isCompleted &&
            todo.actualProgress == 0 &&
            todo.recordedFocusSeconds == 0 &&
            (todo.flowSessions?.isEmpty ?? true) &&
            (todo.flowSegments?.isEmpty ?? true)
    }

    private func dates(from start: Date, through end: Date) -> [Date] {
        var result: [Date] = []
        var day = calendar.startOfDay(for: start)
        let finalDay = calendar.startOfDay(for: end)

        while day <= finalDay {
            result.append(day)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = nextDay
        }

        return result
    }
}
