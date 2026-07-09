//
//  RequiredTodoPlanner.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import Foundation

struct RequiredTodoPlanner {
    var calendar: Calendar = .current

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
            guard let weekdayMask = direction.weekdayMask, weekdayMask > 0 else {
                return false
            }
            return isSelectedWeekday(date, in: weekdayMask)
        case nil:
            return false
        }
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

    func makeRequiredTodo(for direction: Direction, on date: Date = .now, sortIndex: Int = 0) -> Todo? {
        guard shouldAppearToday(direction, on: date),
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
