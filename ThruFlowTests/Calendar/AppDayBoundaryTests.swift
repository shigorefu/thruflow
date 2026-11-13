import Foundation
import Testing
@testable import ThruFlow

struct AppDayBoundaryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func assignsEarlyMorningToPreviousLogicalDay() {
        let boundary = AppDayBoundary(hour: 2)
        let previousDay = date(2026, 7, 16)

        #expect(boundary.day(containing: date(2026, 7, 17, hour: 1, minute: 59), calendar: calendar) == previousDay)
        #expect(boundary.day(containing: date(2026, 7, 17, hour: 2), calendar: calendar) == date(2026, 7, 17))
    }

    @Test func intervalRunsBetweenConfiguredBoundaries() {
        let boundary = AppDayBoundary(hour: 2)
        let interval = boundary.interval(for: date(2026, 7, 17), calendar: calendar)

        #expect(interval.start == date(2026, 7, 17, hour: 2))
        #expect(interval.end == date(2026, 7, 18, hour: 2))
        #expect(boundary.contains(date(2026, 7, 18, hour: 1, minute: 59), in: date(2026, 7, 17), calendar: calendar))
        #expect(!boundary.contains(date(2026, 7, 18, hour: 2), in: date(2026, 7, 17), calendar: calendar))
    }

    @Test func midnightKeepsCalendarDayBehavior() {
        let boundary = AppDayBoundary.midnight
        let instant = date(2026, 7, 17, hour: 1)

        #expect(boundary.day(containing: instant, calendar: calendar) == date(2026, 7, 17))
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        minute: Int = 0
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
