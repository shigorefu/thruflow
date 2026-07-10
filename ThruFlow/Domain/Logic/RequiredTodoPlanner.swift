//
//  RequiredTodoPlanner.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import Foundation

struct RequiredTodoPlanner {
    var calendar: Calendar = .current

    struct RescheduleOption: Equatable {
        let date: Date
        let isAllowed: Bool
    }

    func shouldAppearToday(_ direction: Direction, on date: Date = .now) -> Bool {
        guard direction.type == .habit,
              !direction.isArchived,
              direction.hasGoal,
              direction.goalUnit != nil else {
            return false
        }

        switch direction.goalSchedule {
        case .everyDay:
            return true
        case .weekdays:
            return isSelectedWeekday(date, in: direction.weekdayMask)
        case .weeklyCount:
            return isEligibleWeeklyDate(date, for: direction)
        case nil:
            return false
        }
    }

    func shouldCreateRequiredTodo(
        for direction: Direction,
        in todos: [Todo],
        on date: Date = .now
    ) -> Bool {
        guard shouldAppearToday(direction, on: date) else { return false }

        if direction.goalSchedule != .weeklyCount {
            return existingRequiredTodo(for: direction, in: todos, on: date) == nil
        }

        let weeklyTodos = todosForCurrentWeek(direction: direction, in: todos, containing: date)
        guard !weeklyTodos.contains(where: { todo in
            guard let scheduledDate = todo.scheduledDate else { return false }
            return calendar.isDate(scheduledDate, inSameDayAs: date)
        }) else {
            return false
        }

        let completedCount = weeklyTodos.filter(\.isCompleted).count
        let targetCount = max(1, direction.weeklyTargetCount ?? 1)
        guard completedCount < targetCount else { return false }

        return !weeklyTodos.contains(where: { !$0.isCompleted })
    }

    func existingRequiredTodo(for direction: Direction, in todos: [Todo], on date: Date = .now) -> Todo? {
        todos.first { todo in
            guard todo.direction?.id == direction.id,
                  !todo.isArchived,
                  !todo.isDeleted,
                  let scheduledDate = todo.scheduledDate else {
                return false
            }

            return calendar.isDate(scheduledDate, inSameDayAs: date)
        }
    }

    func makeRequiredTodo(
        for direction: Direction,
        existingTodos: [Todo] = [],
        on date: Date = .now,
        sortIndex: Int = 0
    ) -> Todo? {
        guard shouldCreateRequiredTodo(for: direction, in: existingTodos, on: date),
              let goalUnit = direction.goalUnit else {
            return nil
        }

        let target = max(1, direction.goalTarget ?? direction.weeklyTargetCount ?? 1)

        return Todo(
            title: "",
            direction: direction,
            measurement: measurement(for: goalUnit),
            priority: .high,
            isRoomIfPossible: false,
            plannedAmount: plannedAmount(for: goalUnit, target: target),
            scheduledDate: date,
            sortIndex: sortIndex
        )
    }

    func weeklyRescheduleOptions(
        for todo: Todo,
        in todos: [Todo],
        now: Date = .now
    ) -> [RescheduleOption] {
        guard let direction = todo.direction,
              direction.type == .habit,
              direction.goalSchedule == .weeklyCount,
              let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return []
        }

        let completedCount = todosForCurrentWeek(
            direction: direction,
            in: todos.filter { $0.id != todo.id },
            containing: now
        ).filter(\.isCompleted).count
        let remainingCount = max(1, max(1, direction.weeklyTargetCount ?? 1) - completedCount)

        return dates(from: now, before: weekInterval.end)
            .filter { isEligibleWeeklyDate($0, for: direction) }
            .map { date in
                let availableDates = dates(from: date, before: weekInterval.end)
                    .filter { isEligibleWeeklyDate($0, for: direction) }

                return RescheduleOption(
                    date: date,
                    isAllowed: availableDates.count >= remainingCount
                )
            }
    }

    private func measurement(for goalUnit: GoalUnit) -> TodoMeasurement {
        switch goalUnit {
        case .occurrences:
            return .checkbox
        case .focusBlocks:
            return .focusBlocks
        case .minutes, .hours:
            return .minutes
        }
    }

    private func plannedAmount(for goalUnit: GoalUnit, target: Int) -> Int? {
        switch goalUnit {
        case .occurrences:
            return nil
        case .focusBlocks, .minutes:
            return target
        case .hours:
            return target * 60
        }
    }

    private func isSelectedWeekday(_ date: Date, in mask: Int?) -> Bool {
        guard let mask else { return false }
        let weekday = calendar.component(.weekday, from: date)

        guard let goalWeekday = GoalWeekday.allCases.first(where: { $0.calendarWeekday == weekday }) else {
            return false
        }

        return mask & goalWeekday.rawValue != 0
    }

    private func isEligibleWeeklyDate(_ date: Date, for direction: Direction) -> Bool {
        guard let weekdayMask = direction.weekdayMask, weekdayMask > 0 else {
            return true
        }

        return isSelectedWeekday(date, in: weekdayMask)
    }

    private func todosForCurrentWeek(
        direction: Direction,
        in todos: [Todo],
        containing date: Date
    ) -> [Todo] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return []
        }

        return todos.filter { todo in
            guard todo.direction?.id == direction.id,
                  !todo.isArchived,
                  !todo.isDeleted,
                  let scheduledDate = todo.scheduledDate else {
                return false
            }

            return weekInterval.contains(scheduledDate)
        }
    }

    private func dates(from start: Date, before end: Date) -> [Date] {
        var dates: [Date] = []
        var date = calendar.startOfDay(for: start)

        while date < end {
            dates.append(date)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
                break
            }
            date = nextDate
        }

        return dates
    }
}

private extension GoalWeekday {
    var calendarWeekday: Int {
        switch self {
        case .sunday:
            return 1
        case .monday:
            return 2
        case .tuesday:
            return 3
        case .wednesday:
            return 4
        case .thursday:
            return 5
        case .friday:
            return 6
        case .saturday:
            return 7
        }
    }
}
