import Foundation
import Testing
@testable import ThruFlow

@MainActor
struct TaskWindowCacheTests {
    @Test func nearbyDaysAndBacklogAreAvailableImmediately() {
        let calendar = testCalendar()
        let now = date(2026, 8, 2, hour: 12, calendar: calendar)
        let direction = Direction(name: "仕事", type: .neutral)
        let yesterday = Todo(
            title: "昨日",
            direction: direction,
            scheduledDate: date(2026, 8, 1, calendar: calendar)
        )
        let today = Todo(
            title: "今日",
            direction: direction,
            scheduledDate: date(2026, 8, 2, calendar: calendar)
        )
        let tomorrow = Todo(
            title: "明日",
            direction: direction,
            scheduledDate: date(2026, 8, 3, calendar: calendar)
        )
        let unscheduled = Todo(title: "日付なし", direction: direction)
        let cache = TaskWindowCache()

        cache.refresh(
            todos: [tomorrow, unscheduled, today, yesterday],
            calendar: calendar,
            dayBoundary: AppDayBoundary(hour: 0),
            now: now
        )

        #expect(cache.todos(on: now).map(\.id) == [today.id])
        #expect(cache.todos(on: tomorrow.scheduledDate!).map(\.id) == [tomorrow.id])
        #expect(cache.backlogSnapshot().overdue.map(\.id) == [yesterday.id])
        #expect(cache.backlogSnapshot().unscheduled.map(\.id) == [unscheduled.id])
    }

    @Test func distantDaysBecomeAvailableAfterBackgroundIndexing() async {
        let calendar = testCalendar()
        let now = date(2026, 8, 2, hour: 12, calendar: calendar)
        let distantDate = date(2026, 11, 2, calendar: calendar)
        let direction = Direction(name: "仕事", type: .neutral)
        let distant = Todo(
            title: "遠い予定",
            direction: direction,
            scheduledDate: distantDate
        )
        let cache = TaskWindowCache()

        cache.refresh(
            todos: [distant],
            calendar: calendar,
            dayBoundary: AppDayBoundary(hour: 0),
            now: now
        )
        #expect(cache.todos(on: distantDate).isEmpty)

        await cache.waitForBackgroundIndex()

        #expect(cache.isFullyIndexed)
        #expect(cache.todos(on: distantDate).map(\.id) == [distant.id])
    }

    @Test func refreshMovesTaskBetweenCachedDays() async {
        let calendar = testCalendar()
        let now = date(2026, 8, 2, hour: 12, calendar: calendar)
        let originalDate = date(2026, 8, 2, calendar: calendar)
        let movedDate = date(2026, 8, 5, calendar: calendar)
        let direction = Direction(name: "仕事", type: .neutral)
        let todo = Todo(title: "移動", direction: direction, scheduledDate: originalDate)
        let cache = TaskWindowCache()

        cache.refresh(
            todos: [todo],
            calendar: calendar,
            dayBoundary: AppDayBoundary(hour: 0),
            now: now
        )
        #expect(cache.todos(on: originalDate).map(\.id) == [todo.id])

        todo.scheduledDate = movedDate
        todo.updatedAt = now.addingTimeInterval(1)
        cache.refresh(
            todos: [todo],
            calendar: calendar,
            dayBoundary: AppDayBoundary(hour: 0),
            now: now
        )

        #expect(cache.todos(on: originalDate).isEmpty)
        #expect(cache.todos(on: movedDate).map(\.id) == [todo.id])
        await cache.waitForBackgroundIndex()
        #expect(cache.todos(on: movedDate).map(\.id) == [todo.id])
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
        calendar: Calendar
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour
            )
        )!
    }
}
