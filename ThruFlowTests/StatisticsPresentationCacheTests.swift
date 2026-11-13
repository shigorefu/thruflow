import Foundation
import Testing
@testable import ThruFlow

@MainActor
struct StatisticsPresentationCacheTests {
    @Test func returningToAReportReusesOnlyTheMatchingProjection() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let boundary = AppDayBoundary(hour: 3)
        let anchor = Date(timeIntervalSince1970: 1_784_000_000)
        let weekly = StatisticsPeriodFilter(period: .week, anchorDate: anchor)
        let monthly = StatisticsPeriodFilter(period: .month, anchorDate: anchor)
        let builder = StatisticsPeriodBuilder(calendar: calendar, dayBoundary: boundary)
        let week = builder.build(flowRecords: [], achievementRecords: [], filter: weekly)
        let month = builder.build(flowRecords: [], achievementRecords: [], filter: monthly)
        var cache = StatisticsPresentationCache()
        cache.store(week, calendar: calendar, dayBoundary: boundary)
        cache.store(month, calendar: calendar, dayBoundary: boundary)

        #expect(cache.snapshot(for: weekly, calendar: calendar, dayBoundary: boundary)?.filter == weekly)
        #expect(cache.snapshot(for: monthly, calendar: calendar, dayBoundary: boundary)?.filter == monthly)
        #expect(cache.snapshot(for: weekly, calendar: calendar, dayBoundary: .midnight) == nil)

        var newCalendar = calendar
        newCalendar.firstWeekday = calendar.firstWeekday == 1 ? 2 : 1
        #expect(cache.snapshot(for: weekly, calendar: newCalendar, dayBoundary: boundary) == nil)

        var filteredWeek = weekly
        filteredWeek.query = "report"
        #expect(cache.snapshot(for: filteredWeek, calendar: calendar, dayBoundary: boundary) == nil)
    }
}
