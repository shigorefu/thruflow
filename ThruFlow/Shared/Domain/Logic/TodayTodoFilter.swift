//
//  TodayTodoFilter.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import Foundation

struct TodayTodoFilter {
    var calendar: Calendar = .current

    func includes(_ todo: Todo, on date: Date = .now) -> Bool {
        guard !todo.isArchived, !todo.isDeleted else { return false }

        guard let scheduledDate = todo.scheduledDate else { return false }

        return calendar.isDate(scheduledDate, inSameDayAs: date)
    }
}

struct InboxTodoFilter {
    func includes(_ todo: Todo) -> Bool {
        !todo.isArchived &&
        !todo.isDeleted &&
        todo.status == .active &&
        todo.scheduledDate == nil
    }
}
