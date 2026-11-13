import Foundation
import SwiftData
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

    @Test func presentationPublishesTheMatchingSummaryBeforeTheReport() async throws {
        let schema = AppModelContainerFactory.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let anchor = Date(timeIntervalSince1970: 1_784_000_000)
        let filter = StatisticsPeriodFilter(period: .month, anchorDate: anchor)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let area = Area(name: "Reading", type: .neutral, symbolName: "📚", colorHex: "#34C759")
        let endDate = anchor.addingTimeInterval(1_500)
        let session = FlowSession(
            area: area, mode: .twentyFiveFive, phase: .completed, status: .completed,
            startedAt: anchor, plannedEndAt: endDate, endedAt: endDate,
            plannedFocusDurationSeconds: 1_500, actualFocusDurationSeconds: 1_500,
            plannedBreakDurationSeconds: 300
        )
        container.mainContext.insert(area)
        container.mainContext.insert(session)
        try container.mainContext.save()

        let updates = StatisticsProjectionActor.presentationUpdates(
            modelContainer: container,
            filter: filter,
            calendar: calendar,
            dayBoundary: .midnight
        )
        var iterator = updates.makeAsyncIterator()
        guard case let .summary(first)? = try await iterator.next(),
              case let .report(report)? = try await iterator.next() else {
            Issue.record("Expected a summary followed by the complete report")
            return
        }
        #expect(first.summary.totalFocusSeconds == 1_500)
        #expect(first.summary == report.summary)
        #expect(first.previousSummary == report.previousSummary)
        #expect(report.filter == filter)
        let end = try await iterator.next()
        #expect(end == nil)
    }
}
