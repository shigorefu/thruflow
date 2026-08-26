//
//  TodayTodoFilter.swift
//  ThruFlow
//
//

import Foundation

struct TodayTodoFilter {
    var calendar: Calendar = .current
    var dayBoundary: AppDayBoundary = .midnight

    func includes(_ todo: Todo, now: Date = .now) -> Bool {
        includes(todo, on: dayBoundary.day(containing: now, calendar: calendar))
    }

    func includes(_ todo: Todo, on date: Date) -> Bool {
        guard !todo.isArchived, !todo.isDeleted, todo.direction != nil else { return false }

        guard let scheduledDate = todo.scheduledDate else { return false }

        return calendar.isDate(scheduledDate, inSameDayAs: date)
    }
}

struct InboxTodoFilter {
    func includes(_ todo: Todo) -> Bool {
        guard todo.direction != nil else { return false }
        return !todo.isArchived &&
        !todo.isDeleted &&
        todo.status == .active &&
        todo.scheduledDate == nil
    }
}
