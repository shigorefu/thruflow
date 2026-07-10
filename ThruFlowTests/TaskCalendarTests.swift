//
//  TaskCalendarTests.swift
//  ThruFlowTests
//
//  Created by Codex on 2026/07/10.
//

import Foundation
import Testing
@testable import ThruFlow

struct TaskCalendarTests {
    @Test func dayRangesBuildConsecutiveDates() {
        let calendar = testCalendar()
        let builder = TaskCalendarBuilder(calendar: calendar)
        let anchor = date(2026, 7, 10, calendar: calendar)

        #expect(builder.dates(for: .oneDay, anchoredAt: anchor).count == 1)
        #expect(builder.dates(for: .threeDays, anchoredAt: anchor).count == 3)
        #expect(builder.dates(for: .sevenDays, anchoredAt: anchor).count == 7)
        #expect(builder.dates(for: .sevenDays, anchoredAt: anchor).last == date(2026, 7, 16, calendar: calendar))
    }

    @Test func rangeNavigationUsesVisibleRangeSize() {
        let calendar = testCalendar()
        let builder = TaskCalendarBuilder(calendar: calendar)
        let anchor = date(2026, 7, 10, calendar: calendar)

        #expect(builder.advancedDate(from: anchor, range: .oneDay, direction: 1) == date(2026, 7, 11, calendar: calendar))
        #expect(builder.advancedDate(from: anchor, range: .threeDays, direction: 1) == date(2026, 7, 13, calendar: calendar))
        #expect(builder.advancedDate(from: anchor, range: .sevenDays, direction: -1) == date(2026, 7, 3, calendar: calendar))
        #expect(builder.advancedDate(from: anchor, range: .month, direction: 1) == date(2026, 8, 10, calendar: calendar))
    }

    @Test func monthGridContainsWholeWeeks() {
        let calendar = testCalendar()
        let builder = TaskCalendarBuilder(calendar: calendar)
        let anchor = date(2026, 7, 10, calendar: calendar)
        let dates = builder.dates(for: .month, anchoredAt: anchor)

        #expect(!dates.isEmpty)
        #expect(dates.count.isMultiple(of: 7))
        #expect(dates.contains(anchor))
        #expect(calendar.component(.weekday, from: dates[0]) == calendar.firstWeekday)
    }

    @Test func taskCalendarFilterSeparatesHabits() {
        let habitDirection = Direction(name: "読書", type: .habit)
        let normalDirection = Direction(name: "仕事", type: .neutral)
        let habit = Todo(title: "", direction: habitDirection)
        let task = Todo(title: "資料", direction: normalDirection)

        #expect(TaskCalendarFilter.all.includes(habit))
        #expect(TaskCalendarFilter.tasks.includes(task))
        #expect(!TaskCalendarFilter.tasks.includes(habit))
        #expect(TaskCalendarFilter.habits.includes(habit))
        #expect(!TaskCalendarFilter.habits.includes(task))
    }

    @Test func completedAndFixedHabitTasksCannotMove() {
        let calendar = testCalendar()
        let service = TaskRescheduleService(calendar: calendar)
        let target = date(2026, 7, 11, calendar: calendar)

        let normalDirection = Direction(name: "仕事", type: .neutral)
        let completed = Todo(title: "完了", direction: normalDirection)
        completed.setCompleted(true)

        let habitDirection = Direction(
            name: "読書",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .daily,
            goalUnit: .occurrences,
            goalSchedule: .everyDay
        )
        let fixedHabit = Todo(title: "", direction: habitDirection)

        #expect(failure(service.validate(completed, movingTo: target, among: [completed])) == .completedTask)
        #expect(failure(service.validate(fixedHabit, movingTo: target, among: [fixedHabit])) == .fixedHabit)
    }

    @Test func activeNormalTaskCanMove() {
        let calendar = testCalendar()
        let service = TaskRescheduleService(calendar: calendar)
        let direction = Direction(name: "仕事", type: .neutral)
        let todo = Todo(title: "資料", direction: direction)

        switch service.validate(
            todo,
            movingTo: date(2026, 7, 11, calendar: calendar),
            among: [todo]
        ) {
        case .success:
            break
        case .failure:
            Issue.record("Active normal Task should be movable")
        }
    }

    @Test func weeklyHabitMoveUsesItsScheduledWeek() {
        let calendar = testCalendar()
        let service = TaskRescheduleService(calendar: calendar)
        let monday = date(2026, 7, 20, calendar: calendar)
        let tuesday = date(2026, 7, 21, calendar: calendar)
        let direction = Direction(
            name: "筋トレ",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .weekly,
            goalUnit: .occurrences,
            goalSchedule: .weeklyCount,
            weeklyTargetCount: 2
        )
        let todo = Todo(title: "", direction: direction, scheduledDate: monday)

        switch service.validate(todo, movingTo: tuesday, among: [todo], now: date(2026, 7, 10, calendar: calendar)) {
        case .success:
            break
        case .failure:
            Issue.record("Weekly Habit should validate within its scheduled week")
        }
    }

    private func failure(_ result: Result<Void, TaskRescheduleFailure>) -> TaskRescheduleFailure? {
        guard case .failure(let failure) = result else { return nil }
        return failure
    }

    private func testCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
