//
//  TaskCalendarSnapshot.swift
//  ThruFlow
//
//  Created by Codex on 2026/08/02.
//

import Foundation

/// An immutable, render-scoped index for calendar task projections.
///
/// SwiftData remains the source of truth. The snapshot only prevents a single
/// SwiftUI render from repeatedly scanning the complete `@Query` result for
/// every visible day, week and month cell.
@MainActor
struct TaskCalendarSnapshot {
    let activeTodos: [Todo]
    let backlog: TaskBacklogSnapshot

    private let calendar: Calendar
    private let todosByDay: [Date: [Todo]]
    private let todosByID: [UUID: Todo]

    init(
        todos: [Todo],
        calendar: Calendar = .current,
        dayBoundary: AppDayBoundary = .midnight,
        now: Date = .now
    ) {
        self.calendar = calendar

        let activeTodos = todos.filter { !$0.isArchived && !$0.isDeleted }
        self.activeTodos = activeTodos
        backlog = TaskBacklogBuilder(
            calendar: calendar,
            dayBoundary: dayBoundary
        ).build(todos: activeTodos, now: now)

        var todosByID: [UUID: Todo] = [:]
        for todo in activeTodos {
            todosByID[todo.id] = todo
        }
        self.todosByID = todosByID
        let scheduledTodos: [(day: Date, todo: Todo)] = activeTodos.compactMap { todo in
            guard let scheduledDate = todo.scheduledDate else { return nil }
            return (calendar.startOfDay(for: scheduledDate), todo)
        }
        todosByDay = Dictionary(grouping: scheduledTodos, by: \.day)
            .mapValues { entries in entries.map(\.todo) }
    }

    func todos(on date: Date) -> [Todo] {
        todosByDay[calendar.startOfDay(for: date)] ?? []
    }

    func todo(id: UUID) -> Todo? {
        todosByID[id]
    }

    func indicatorColors(
        on date: Date,
        filter: TaskCalendarFilter,
        matching searchQuery: DatabaseSearchQuery? = nil,
        limit: Int = 4
    ) -> [String] {
        uniqueColors(
            in: todos(on: date),
            filter: filter,
            matching: searchQuery,
            limit: limit
        )
    }

    func indicatorColors(
        inWeekContaining date: Date,
        filter: TaskCalendarFilter,
        matching searchQuery: DatabaseSearchQuery? = nil,
        limit: Int = 4
    ) -> [String] {
        guard limit > 0,
              let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return []
        }

        var date = calendar.startOfDay(for: interval.start)
        var candidates: [Todo] = []
        while date < interval.end {
            candidates.append(contentsOf: todos(on: date))
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
                break
            }
            date = nextDate
        }
        return uniqueColors(
            in: candidates,
            filter: filter,
            matching: searchQuery,
            limit: limit
        )
    }

    private func uniqueColors(
        in todos: [Todo],
        filter: TaskCalendarFilter,
        matching searchQuery: DatabaseSearchQuery?,
        limit: Int
    ) -> [String] {
        guard limit > 0 else { return [] }

        var seen: Set<String> = []
        var colors: [String] = []
        for todo in todos where filter.includes(todo) {
            if let searchQuery, !searchQuery.matchesTask(todo) {
                continue
            }
            guard let colorHex = todo.direction?.colorHex else { continue }
            guard seen.insert(colorHex.lowercased()).inserted else { continue }
            colors.append(colorHex)
            if colors.count == limit { break }
        }
        return colors
    }
}
