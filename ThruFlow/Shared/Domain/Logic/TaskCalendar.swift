//
//  TaskCalendar.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/10.
//

import Foundation

enum TaskCalendarRange: String, CaseIterable, Identifiable {
    case oneDay
    case sevenDays
    case month

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneDay:
            String(localized: "日")
        case .sevenDays:
            String(localized: "週")
        case .month:
            String(localized: "月")
        }
    }
}

enum TaskCalendarFilter: String, CaseIterable, Identifiable {
    case all
    case tasks
    case habits

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:
            String(localized: "すべて")
        case .tasks:
            String(localized: "タスク")
        case .habits:
            String(localized: "習慣一覧")
        }
    }

    func includes(_ todo: Todo) -> Bool {
        switch self {
        case .all:
            true
        case .tasks:
            todo.direction?.type != .habit
        case .habits:
            todo.direction?.type == .habit
        }
    }
}

struct TaskCalendarIndicatorPalette {
    var calendar: Calendar = .current

    func colors(
        for interval: DateInterval,
        todos: [Todo],
        filter: TaskCalendarFilter,
        limit: Int = 4
    ) -> [String] {
        guard limit > 0 else { return [] }

        var seenColors: Set<String> = []
        var colors: [String] = []

        for todo in todos where filter.includes(todo) && !todo.isArchived && !todo.isDeleted {
            guard let scheduledDate = todo.scheduledDate,
                  interval.contains(scheduledDate),
                  let colorHex = todo.direction?.colorHex else {
                continue
            }

            let normalizedColor = colorHex.lowercased()
            guard seenColors.insert(normalizedColor).inserted else { continue }

            colors.append(colorHex)
            if colors.count == limit {
                break
            }
        }

        return colors
    }

    func colors(
        on date: Date,
        todos: [Todo],
        filter: TaskCalendarFilter,
        limit: Int = 4
    ) -> [String] {
        guard let interval = calendar.dateInterval(of: .day, for: date) else { return [] }
        return colors(for: interval, todos: todos, filter: filter, limit: limit)
    }

    func colors(
        inWeekContaining date: Date,
        todos: [Todo],
        filter: TaskCalendarFilter,
        limit: Int = 4
    ) -> [String] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return colors(for: interval, todos: todos, filter: filter, limit: limit)
    }
}

struct TaskCalendarBuilder {
    var calendar: Calendar = .current

    func dates(for range: TaskCalendarRange, anchoredAt date: Date) -> [Date] {
        let anchor = calendar.startOfDay(for: date)

        switch range {
        case .oneDay:
            return [anchor]
        case .sevenDays:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: anchor)?.start ?? anchor
            return consecutiveDates(count: 7, from: calendar.startOfDay(for: weekStart))
        case .month:
            return monthGridDates(containing: anchor)
        }
    }

    func advancedDate(from date: Date, range: TaskCalendarRange, direction: Int) -> Date {
        let value = direction < 0 ? -1 : 1

        switch range {
        case .oneDay:
            return calendar.date(byAdding: .day, value: value, to: date) ?? date
        case .sevenDays:
            return calendar.date(byAdding: .weekOfYear, value: value, to: date) ?? date
        case .month:
            return calendar.date(byAdding: .month, value: value, to: date) ?? date
        }
    }

    func isDate(_ date: Date, inMonthContaining anchor: Date) -> Bool {
        calendar.isDate(date, equalTo: anchor, toGranularity: .month)
    }

    private func monthGridDates(containing date: Date) -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start),
              let lastDate = calendar.date(byAdding: .day, value: -1, to: monthInterval.end),
              let lastWeek = calendar.dateInterval(of: .weekOfYear, for: lastDate) else {
            return []
        }

        let dayCount = max(
            0,
            calendar.dateComponents([.day], from: firstWeek.start, to: lastWeek.end).day ?? 0
        )
        return consecutiveDates(count: dayCount, from: firstWeek.start)
    }

    private func consecutiveDates(count: Int, from start: Date) -> [Date] {
        (0..<count).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }
    }
}

enum TaskRescheduleFailure: Error, Equatable {
    case completedTask
    case fixedHabit
    case weeklyTargetWouldBecomeImpossible

    var message: String {
        switch self {
        case .completedTask:
            String(localized: "完了したタスクは移動できません")
        case .fixedHabit:
            String(localized: "固定された習慣の日付は変更できません")
        case .weeklyTargetWouldBecomeImpossible:
            String(localized: "週間目標を達成できなくなるため移動できません")
        }
    }
}

struct TaskRescheduleService {
    var calendar: Calendar = .current
    var dayBoundary: AppDayBoundary = .midnight

    func validate(
        _ todo: Todo,
        movingTo date: Date,
        among todos: [Todo],
        now: Date = .now
    ) -> Result<Void, TaskRescheduleFailure> {
        guard !todo.isCompleted else {
            return .failure(.completedTask)
        }

        guard todo.direction?.type == .habit else {
            return .success(())
        }

        guard todo.direction?.goalSchedule == .weeklyCount else {
            return .failure(.fixedHabit)
        }

        let planner = RequiredTodoPlanner(calendar: calendar)
        let referenceDate = todo.scheduledDate
            ?? dayBoundary.day(containing: now, calendar: calendar)
        let option = planner.weeklyRescheduleOptions(for: todo, in: todos, now: referenceDate)
            .first { calendar.isDate($0.date, inSameDayAs: date) }

        guard option?.isAllowed == true else {
            return .failure(.weeklyTargetWouldBecomeImpossible)
        }

        return .success(())
    }
}
