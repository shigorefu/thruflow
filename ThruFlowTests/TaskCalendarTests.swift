//
//  TaskCalendarTests.swift
//  ThruFlowTests
//
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
        let weekDates = builder.dates(for: .sevenDays, anchoredAt: anchor)
        #expect(weekDates.count == 7)
        #expect(weekDates.first == calendar.dateInterval(of: .weekOfYear, for: anchor)?.start)
        #expect(weekDates.last == calendar.date(byAdding: .day, value: 6, to: weekDates[0]))
    }

    @Test func rangeNavigationUsesVisibleRangeSize() {
        let calendar = testCalendar()
        let builder = TaskCalendarBuilder(calendar: calendar)
        let anchor = date(2026, 7, 10, calendar: calendar)

        #expect(builder.advancedDate(from: anchor, range: .oneDay, area: 1) == date(2026, 7, 11, calendar: calendar))
        #expect(builder.advancedDate(from: anchor, range: .sevenDays, area: -1) == date(2026, 7, 3, calendar: calendar))
        #expect(builder.advancedDate(from: anchor, range: .month, area: 1) == date(2026, 8, 10, calendar: calendar))
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
        let habitArea = Area(name: "読書", type: .habit)
        let normalArea = Area(name: "仕事", type: .neutral)
        let habit = Todo(title: "", area: habitArea)
        let task = Todo(title: "資料", area: normalArea)

        #expect(TaskCalendarFilter.all.includes(habit))
        #expect(TaskCalendarFilter.tasks.includes(task))
        #expect(!TaskCalendarFilter.tasks.includes(habit))
        #expect(TaskCalendarFilter.habits.includes(habit))
        #expect(!TaskCalendarFilter.habits.includes(task))
    }

    @Test func calendarIndicatorsFollowTaskFilter() {
        let calendar = testCalendar()
        let selectedDate = date(2026, 7, 29, calendar: calendar)
        let taskArea = Area(
            name: "仕事",
            type: .neutral,
            colorHex: "#FF0000"
        )
        let habitArea = Area(
            name: "運動",
            type: .habit,
            colorHex: "#00FF00"
        )
        let task = Todo(title: "資料", area: taskArea, scheduledDate: selectedDate)
        let habit = Todo(title: "", area: habitArea, scheduledDate: selectedDate)
        let palette = TaskCalendarIndicatorPalette(calendar: calendar)

        #expect(
            palette.colors(on: selectedDate, todos: [task, habit], filter: .all)
                == ["#FF0000", "#00FF00"]
        )
        #expect(
            palette.colors(on: selectedDate, todos: [task, habit], filter: .tasks)
                == ["#FF0000"]
        )
        #expect(
            palette.colors(on: selectedDate, todos: [task, habit], filter: .habits)
                == ["#00FF00"]
        )
    }

    @MainActor
    @Test func calendarSnapshotIndexesOnlyActiveScheduledTasks() {
        let calendar = testCalendar()
        let selectedDate = date(2026, 7, 29, calendar: calendar)
        let area = Area(name: "仕事", type: .neutral)
        let active = Todo(title: "資料", area: area, scheduledDate: selectedDate)
        let undated = Todo(title: "受信箱", area: area)
        let archived = Todo(title: "保管", area: area, scheduledDate: selectedDate)
        archived.archive(now: selectedDate)
        let deleted = Todo(title: "削除", area: area, scheduledDate: selectedDate)
        deleted.softDelete(now: selectedDate)

        let snapshot = TaskCalendarSnapshot(
            todos: [active, undated, archived, deleted],
            calendar: calendar,
            now: selectedDate
        )

        #expect(snapshot.activeTodos.map(\.id) == [active.id, undated.id])
        #expect(snapshot.todos(on: selectedDate).map(\.id) == [active.id])
        #expect(snapshot.todo(id: active.id) === active)
        #expect(snapshot.todo(id: archived.id) == nil)
    }

    @MainActor
    @Test func calendarSnapshotIndicatorsRespectFilterSearchAndLimit() {
        let calendar = testCalendar()
        let selectedDate = date(2026, 7, 29, calendar: calendar)
        let work = Area(name: "AWS", type: .neutral, colorHex: "#FF0000")
        let duplicateColor = Area(name: "資料", type: .neutral, colorHex: "#ff0000")
        let habitArea = Area(name: "運動", type: .habit, colorHex: "#00FF00")
        let aws = Todo(title: "VPC", area: work, scheduledDate: selectedDate)
        let document = Todo(title: "設計", area: duplicateColor, scheduledDate: selectedDate)
        let habit = Todo(title: "", area: habitArea, scheduledDate: selectedDate)
        let snapshot = TaskCalendarSnapshot(
            todos: [aws, document, habit],
            calendar: calendar,
            now: selectedDate
        )

        #expect(
            snapshot.indicatorColors(on: selectedDate, filter: .all)
                == ["#FF0000", "#00FF00"]
        )
        #expect(
            snapshot.indicatorColors(on: selectedDate, filter: .habits)
                == ["#00FF00"]
        )
        #expect(
            snapshot.indicatorColors(
                on: selectedDate,
                filter: .all,
                matching: DatabaseSearchQuery(text: "VPC"),
                limit: 1
            ) == ["#FF0000"]
        )
    }

    @Test func backlogSeparatesOverdueAndUnscheduledTasks() {
        let calendar = testCalendar()
        let now = date(2026, 7, 17, calendar: calendar)
        let area = Area(name: "仕事", type: .neutral)
        let overdue = Todo(
            title: "期限切れ",
            area: area,
            scheduledDate: date(2026, 7, 16, calendar: calendar)
        )
        let today = Todo(title: "今日", area: area, scheduledDate: now)
        let future = Todo(
            title: "明日",
            area: area,
            scheduledDate: date(2026, 7, 18, calendar: calendar)
        )
        let unscheduled = Todo(title: "日付なし", area: area)

        let snapshot = TaskBacklogBuilder(calendar: calendar).build(
            todos: [future, unscheduled, today, overdue],
            now: now
        )

        #expect(snapshot.overdue.map(\.id) == [overdue.id])
        #expect(snapshot.unscheduled.map(\.id) == [unscheduled.id])
    }

    @Test func backlogUsesConfiguredDayBoundary() {
        let calendar = testCalendar()
        let area = Area(name: "仕事", type: .neutral)
        let july16 = date(2026, 7, 16, calendar: calendar)
        let task = Todo(title: "深夜作業", area: area, scheduledDate: july16)
        let builder = TaskBacklogBuilder(
            calendar: calendar,
            dayBoundary: AppDayBoundary(hour: 2)
        )

        let beforeBoundary = date(2026, 7, 17, hour: 1, minute: 59, calendar: calendar)
        #expect(builder.build(todos: [task], now: beforeBoundary).overdue.isEmpty)

        let atBoundary = date(2026, 7, 17, hour: 2, calendar: calendar)
        #expect(builder.build(todos: [task], now: atBoundary).overdue.map(\.id) == [task.id])
    }

    @Test func backlogExcludesHabitsAndInactiveTasks() {
        let calendar = testCalendar()
        let now = date(2026, 7, 17, calendar: calendar)
        let yesterday = date(2026, 7, 16, calendar: calendar)
        let normal = Area(name: "仕事", type: .neutral)
        let habit = Area(name: "運動", type: .habit)
        let overdueHabit = Todo(title: "", area: habit, scheduledDate: yesterday)
        let unscheduledHabit = Todo(title: "", area: habit)
        let completed = Todo(title: "完了", area: normal, scheduledDate: yesterday)
        completed.setCompleted(true, now: yesterday)
        let archived = Todo(title: "保管", area: normal)
        archived.archive(now: yesterday)
        let deleted = Todo(title: "削除", area: normal, scheduledDate: yesterday)
        deleted.softDelete(now: yesterday)

        let snapshot = TaskBacklogBuilder(calendar: calendar).build(
            todos: [overdueHabit, unscheduledHabit, completed, archived, deleted],
            now: now
        )

        #expect(snapshot.overdue.isEmpty)
        #expect(snapshot.unscheduled.isEmpty)
    }

    @Test func completedAndFixedHabitTasksCannotMove() {
        let calendar = testCalendar()
        let service = TaskRescheduleService(calendar: calendar)
        let target = date(2026, 7, 11, calendar: calendar)

        let normalArea = Area(name: "仕事", type: .neutral)
        let completed = Todo(title: "完了", area: normalArea)
        completed.setCompleted(true)

        let habitArea = Area(
            name: "読書",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .daily,
            goalUnit: .occurrences,
            goalSchedule: .everyDay
        )
        let fixedHabit = Todo(title: "", area: habitArea)

        #expect(failure(service.validate(completed, movingTo: target, among: [completed])) == .completedTask)
        #expect(failure(service.validate(fixedHabit, movingTo: target, among: [fixedHabit])) == .fixedHabit)
    }

    @Test func activeNormalTaskCanMove() {
        let calendar = testCalendar()
        let service = TaskRescheduleService(calendar: calendar)
        let area = Area(name: "仕事", type: .neutral)
        let todo = Todo(title: "資料", area: area)

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
        let area = Area(
            name: "筋トレ",
            type: .habit,
            goalTarget: 1,
            goalPeriod: .weekly,
            goalUnit: .occurrences,
            goalSchedule: .weeklyCount,
            weeklyTargetCount: 2
        )
        let todo = Todo(title: "", area: area, scheduledDate: monday)

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

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        minute: Int = 0,
        calendar: Calendar
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}
