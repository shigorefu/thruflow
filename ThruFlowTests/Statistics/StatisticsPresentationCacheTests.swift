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

    @Test func presentationPublishesEachCardBeforeTheMatchingCompleteReport() async throws {
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
        var partialCards = StatisticsPresentationCards()
        var sectionCount = 0
        var snapshot: StatisticsPeriodSnapshot?
        for try await update in updates {
            #expect(snapshot == nil, "The complete report must be the last update")
            if case .report(let report) = update {
                snapshot = report
            } else {
                partialCards.apply(update)
                sectionCount += 1
            }
        }

        let report = try #require(snapshot)
        #expect(sectionCount == 7)
        let cachedCards = StatisticsPresentationCards(snapshot: report)
        #expect(partialCards.summary == cachedCards.summary)
        #expect(partialCards.trend == cachedCards.trend)
        #expect(partialCards.dailyFocus == cachedCards.dailyFocus)
        #expect(partialCards.estimateAccuracy == cachedCards.estimateAccuracy)
        #expect(report.dailyFocus.first { $0.date == calendar.startOfDay(for: anchor) }?.focusSeconds == 1_500)
        #expect(partialCards.distribution == cachedCards.distribution)
        #expect(partialCards.habits == cachedCards.habits)
        #expect(partialCards.days == cachedCards.days)
        #expect(partialCards.summary?.summary.totalFocusSeconds == 1_500)
        #expect(partialCards.distribution?.totalFocusSeconds == 1_500)
        #expect(report.filter == filter)
    }

    @Test func estimateUsesCompletedTimedTasksAndTheirFullRecordedDuration() async throws {
        let schema = AppModelContainerFactory.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let anchor = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15)))
        let area = Area(name: "Writing", type: .neutral, symbolName: "✍️", colorHex: "#34C759")
        let other = Area(name: "Other", type: .neutral, symbolName: "📚", colorHex: "#34C759")
        container.mainContext.insert(area)
        container.mainContext.insert(other)

        func add(
            _ title: String, area: Area, unit: TodoMeasurement, plan: Int?, actual: Int,
            status: TodoStatus = .completed, completedAt: Date? = nil
        ) {
            container.mainContext.insert(Todo(
                title: title, area: area, measurement: unit, plannedAmount: plan,
                focusDurationSeconds: actual, status: status, completedAt: completedAt,
                updatedAt: anchor
            ))
        }
        // These plans and actual durations have equal totals but differ per task.
        // No Flow falls in the selected period: the stored actual is lifetime time.
        add("Report one", area: area, unit: .focusBlocks, plan: 2, actual: 1_500, completedAt: anchor)
        add("Report two", area: area, unit: .minutes, plan: 25, actual: 3_000)
        add("Report checkbox", area: area, unit: .checkbox, plan: 30, actual: 1_800)
        add("Report no time", area: area, unit: .minutes, plan: 20, actual: 0)
        add("Report no estimate", area: area, unit: .minutes, plan: nil, actual: 1_200)
        add("Report active", area: area, unit: .minutes, plan: 20, actual: 1_200, status: .active)
        add("Report other area", area: other, unit: .minutes, plan: 30, actual: 1_800)
        add("Lecture", area: area, unit: .minutes, plan: 30, actual: 1_800)
        add("Report previous period", area: area, unit: .minutes, plan: 20, actual: 1_200,
            completedAt: calendar.date(byAdding: .month, value: -1, to: anchor))
        try container.mainContext.save()

        let filter = StatisticsPeriodFilter(period: .month, anchorDate: anchor, areaIDs: [area.id], query: "report")
        let snapshot = try await StatisticsProjectionActor(modelContainer: container).load(
            filter: filter, calendar: calendar, dayBoundary: .midnight
        )
        #expect(snapshot.estimateAccuracy.plannedSeconds == 4_500)
        #expect(snapshot.estimateAccuracy.actualSeconds == 4_500)
        #expect(snapshot.estimateAccuracy.rate == 0.5)
    }

    @Test func dailyFocusUsesLogicalDaysAndLeavesOutFutureDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 3, hour: 2)))
        let builder = StatisticsPeriodBuilder(calendar: calendar, dayBoundary: AppDayBoundary(hour: 4))
        let filter = StatisticsPeriodFilter(period: .month, anchorDate: now)
        let flow = StatisticsPeriodFlowRecord(
            sessionID: UUID(), startedAt: now, focusSeconds: 600, areaID: nil,
            areaName: "", areaSymbol: "", areaColorHex: nil, todoID: nil, todoTitle: "",
            todoHashtags: [], todoNotes: "", intent: "", result: ""
        )
        let snapshot = builder.build(flowRecords: [flow], achievementRecords: [], filter: filter, now: now)
        #expect(snapshot.dailyFocus.map(\.focusSeconds) == [0, 600])
        #expect(snapshot.dailyFocus.map { calendar.component(.day, from: $0.date) } == [1, 2])
    }
}
