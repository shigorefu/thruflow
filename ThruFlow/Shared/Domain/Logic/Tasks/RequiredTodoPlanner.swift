//
//  RequiredTodoPlanner.swift
//  ThruFlow
//
//

import Foundation

struct RequiredTodoPlanner {
    var calendar: Calendar = .current

    struct RescheduleOption: Equatable {
        let date: Date
        let isAllowed: Bool
    }

    func shouldAppearToday(_ area: Area, on date: Date = .now) -> Bool {
        shouldAppearToday(HabitDefinition(area: area), on: date)
    }
    func shouldCreateRequiredTodo(for area: Area, in todos: [Todo], on date: Date = .now) -> Bool {
        shouldCreateRequiredTodo(for: HabitDefinition(area: area), in: todos, on: date)
    }
    func existingRequiredTodo(for area: Area, in todos: [Todo], on date: Date = .now) -> Todo? {
        existingRequiredTodo(for: HabitDefinition(area: area), in: todos, on: date)
    }
    func makeRequiredTodo(for area: Area, existingTodos: [Todo] = [], on date: Date = .now, sortIndex: Int = 0) -> Todo? {
        makeRequiredTodo(for: HabitDefinition(area: area), existingTodos: existingTodos, on: date, sortIndex: sortIndex)
    }
    func matchesGeneratedTemplate(_ todo: Todo, for area: Area) -> Bool {
        matchesGeneratedTemplate(todo, for: HabitDefinition(area: area))
    }
    @discardableResult
    func applyGeneratedTemplate(to todo: Todo, for area: Area, now: Date = .now) -> Bool {
        applyGeneratedTemplate(to: todo, for: HabitDefinition(area: area), now: now)
    }

    func shouldAppearToday(_ area: HabitDefinition, on date: Date = .now) -> Bool {
        guard area.isActive,
              area.goalUnit != nil,
              !area.isPaused(on: date, calendar: calendar) else {
            return false
        }

        switch area.goalSchedule {
        case .everyDay:
            return true
        case .weekdays:
            return isSelectedWeekday(date, in: area.weekdayMask)
        case .weeklyCount:
            return isEligibleWeeklyDate(date, for: area)
        case nil:
            return false
        }
    }

    func shouldCreateRequiredTodo(
        for area: HabitDefinition,
        in todos: [Todo],
        on date: Date = .now
    ) -> Bool {
        guard shouldAppearToday(area, on: date) else { return false }

        if area.goalSchedule != .weeklyCount {
            return existingRequiredTodo(for: area, in: todos, on: date) == nil
        }

        let weeklyTodos = todosForCurrentWeek(area: area, in: todos, containing: date)
        guard !weeklyTodos.contains(where: { todo in
            guard let scheduledDate = todo.scheduledDate else { return false }
            return calendar.isDate(scheduledDate, inSameDayAs: date)
        }) else {
            return false
        }

        let completedCount = weeklyTodos.filter(\.isCompleted).count
        let targetCount = max(1, area.weeklyTargetCount ?? 1)
        guard completedCount < targetCount else { return false }

        // Past attempts retain their own progress and history. Only an explicit
        // pending occurrence today or later reserves the next weekly attempt.
        let targetDay = calendar.startOfDay(for: date)
        return !weeklyTodos.contains { todo in
            !todo.isCompleted &&
                calendar.startOfDay(for: todo.scheduledDate ?? .distantPast) >= targetDay
        }
    }

    func existingRequiredTodo(for area: HabitDefinition, in todos: [Todo], on date: Date = .now) -> Todo? {
        todos.first { todo in
            guard todo.isHabitOccurrence,
                  area.owns(todo),
                  todo.externalTaskLinkRawValue == nil,
                  !todo.isArchived,
                  !todo.isDeleted,
                  let scheduledDate = todo.scheduledDate else {
                return false
            }

            return calendar.isDate(scheduledDate, inSameDayAs: date)
        }
    }

    func makeRequiredTodo(
        for area: HabitDefinition,
        existingTodos: [Todo] = [],
        on date: Date = .now,
        sortIndex: Int = 0
    ) -> Todo? {
        guard shouldCreateRequiredTodo(for: area, in: existingTodos, on: date),
              let goalUnit = area.goalUnit else {
            return nil
        }

        let target = max(1, area.goalTarget ?? area.weeklyTargetCount ?? 1)

        return Todo(
            title: "",
            area: area.area,
            project: area.project,
            habitOccurrence: true,
            measurement: measurement(for: goalUnit),
            priority: .high,
            isRoomIfPossible: false,
            plannedAmount: plannedAmount(for: goalUnit, target: target),
            scheduledDate: calendar.startOfDay(for: date),
            sortIndex: sortIndex
        )
    }

    func matchesGeneratedTemplate(_ todo: Todo, for area: HabitDefinition) -> Bool {
        let hasNoNotes = todo.notes?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty ?? true

        guard todo.habitOccurrence != false,
              todo.externalTaskLinkRawValue == nil,
              let scheduledDate = todo.scheduledDate,
              area.isActive,
              (area.owns(todo) || (area.project == nil && todo.area == nil && todo.project == nil)),
              (todo.habitOwnerKeyRawValue == nil || todo.habitOwnerKeyRawValue == area.ownerKey),
              area.goalSchedule != .weeklyCount,
              shouldAppearToday(area, on: scheduledDate),
              let goalUnit = area.goalUnit,
              todo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              hasNoNotes,
              todo.hashtags.isEmpty,
              todo.priority == .high,
              !todo.isRoomIfPossible else {
            return false
        }

        let target = max(1, area.goalTarget ?? area.weeklyTargetCount ?? 1)
        return todo.measurement == measurement(for: goalUnit) &&
            todo.plannedAmount == plannedAmount(for: goalUnit, target: target)
    }

    @discardableResult
    func applyGeneratedTemplate(
        to todo: Todo,
        for area: HabitDefinition,
        now: Date = .now
    ) -> Bool {
        guard HabitDefinition(todo: todo) != nil,
              todo.externalTaskLinkRawValue == nil,
              area.owns(todo),
              let goalUnit = area.goalUnit else { return false }

        let target = max(1, area.goalTarget ?? area.weeklyTargetCount ?? 1)
        let nextMeasurement = measurement(for: goalUnit)
        let nextPlannedAmount = plannedAmount(for: goalUnit, target: target)
        let changed = todo.measurement != nextMeasurement ||
            todo.plannedAmount != nextPlannedAmount ||
            todo.priority != .high ||
            todo.isRoomIfPossible

        guard changed else { return false }
        todo.measurement = nextMeasurement
        todo.plannedAmount = nextPlannedAmount
        todo.priority = .high
        todo.isRoomIfPossible = false
        todo.updatedAt = now
        return true
    }

    func weeklyRescheduleOptions(
        for todo: Todo,
        in todos: [Todo],
        now: Date = .now
    ) -> [RescheduleOption] {
        guard todo.isHabitOccurrence,
              todo.externalTaskLinkRawValue == nil,
              let area = HabitDefinition(todo: todo),
              area.goalSchedule == .weeklyCount,
              let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return []
        }

        let completedCount = todosForCurrentWeek(
            area: area,
            in: todos.filter { $0.id != todo.id },
            containing: now
        ).filter(\.isCompleted).count
        let remainingCount = max(1, max(1, area.weeklyTargetCount ?? 1) - completedCount)

        return dates(from: now, before: weekInterval.end)
            .filter { isEligibleWeeklyDate($0, for: area) && !isPaused(area, on: $0) }
            .map { date in
                let availableDates = dates(from: date, before: weekInterval.end)
                    .filter { isEligibleWeeklyDate($0, for: area) && !isPaused(area, on: $0) }

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

    private func isEligibleWeeklyDate(_ date: Date, for area: HabitDefinition) -> Bool {
        guard let weekdayMask = area.weekdayMask, weekdayMask > 0 else {
            return true
        }

        return isSelectedWeekday(date, in: weekdayMask)
    }

    private func isPaused(_ area: HabitDefinition, on date: Date) -> Bool {
        area.isPaused(on: date, calendar: calendar)
    }

    private func todosForCurrentWeek(
        area: HabitDefinition,
        in todos: [Todo],
        containing date: Date
    ) -> [Todo] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return []
        }

        return todos.filter { todo in
            guard todo.isHabitOccurrence,
                  area.owns(todo),
                  todo.externalTaskLinkRawValue == nil,
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
