//
//  StatisticsPeriodTests.swift
//  ThruFlowTests
//
//

import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct StatisticsPeriodTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    @Test func calendarMonthSelectionDoesNotMoveToPreviousMonthAtAMidnightBoundary() {
        let builder = StatisticsPeriodBuilder(
            calendar: calendar,
            dayBoundary: AppDayBoundary(hour: 2)
        )

        let selectedDate = builder.anchorDate(
            forCalendarSelection: date(2026, 8, 1),
            maximumDate: date(2026, 8, 27)
        )

        #expect(selectedDate == date(2026, 8, 1))
        #expect(calendar.component(.month, from: selectedDate) == 8)
    }

    @Test(arguments: [0, 2, 23])
    func selectedSeptemberReachesDotsWithoutShiftingToAugust(boundaryHour: Int) {
        let builder = StatisticsPeriodBuilder(calendar: calendar, dayBoundary: AppDayBoundary(hour: boundaryHour))
        let selected = builder.anchorDate(
            forCalendarSelection: date(2026, 9, 1), maximumDate: date(2026, 9, 11)
        )
        let snapshot = builder.build(
            flowRecords: [], achievementRecords: [],
            filter: StatisticsPeriodFilter(period: .month, anchorDate: selected)
        )
        #expect(snapshot.bounds.currentStart == date(2026, 9, 1))
        #expect(snapshot.bounds.currentEnd == date(2026, 10, 1))
        #expect(snapshot.flowDays.count == 30)
        #expect(snapshot.flowDays.first?.date == date(2026, 9, 1))
        #expect(snapshot.flowDays.last?.date == date(2026, 9, 30))
        #expect(snapshot.achievementDays.map(\.date) == snapshot.flowDays.map(\.date))
    }

    @Test func weekAndYearSelectionsDoNotMoveToThePreviousPeriod() {
        let builder = StatisticsPeriodBuilder(calendar: calendar, dayBoundary: AppDayBoundary(hour: 2))
        let week = builder.bounds(for: StatisticsPeriodFilter(period: .week, anchorDate: date(2026, 9, 7)))
        let year = builder.bounds(for: StatisticsPeriodFilter(period: .year, anchorDate: date(2026, 1, 1)))
        #expect(week.currentStart == date(2026, 9, 7))
        #expect(year.currentStart == date(2026, 1, 1))
        #expect(year.currentEnd == date(2027, 1, 1))
    }

    @Test func selectedCalendarPeriodPreservesLogicalRecordGrouping() {
        let builder = StatisticsPeriodBuilder(calendar: calendar, dayBoundary: AppDayBoundary(hour: 2))
        let records = [
            flowRecord(sessionID: UUID(), date: date(2026, 9, 1, 1), seconds: 60, areaID: nil, area: "", task: "Before boundary"),
            flowRecord(sessionID: UUID(), date: date(2026, 9, 1, 3), seconds: 120, areaID: nil, area: "", task: "After boundary")
        ]
        let snapshot = builder.build(
            flowRecords: records, achievementRecords: [],
            filter: StatisticsPeriodFilter(period: .month, anchorDate: date(2026, 9, 1))
        )
        #expect(snapshot.summary.totalFocusSeconds == 120)
        #expect(snapshot.previousSummary.totalFocusSeconds == 60)
        #expect(snapshot.flowDays.first?.totalFocusSeconds == 120)
    }

    @Test func monthGridPadsDaysOutsideTheSelectedMonthToCompleteWeeks() {
        let augustDates = (1...31).map { date(2026, 8, $0) }
        let padding = StatisticsMonthGridPadding(dates: augustDates, calendar: calendar)
        let paddedDates = padding.padding(augustDates)

        #expect(padding.leadingPlaceholderCount == 5)
        #expect(padding.trailingPlaceholderCount == 6)
        #expect(paddedDates.count == 42)
        #expect(paddedDates.prefix(5).allSatisfy { $0 == nil })
        #expect(paddedDates[5] == date(2026, 8, 1))
        #expect(paddedDates[35] == date(2026, 8, 31))
        #expect(paddedDates.suffix(6).allSatisfy { $0 == nil })
    }

    @Test func weekBoundsIncludeTheEquivalentPreviousWeek() {
        let filter = StatisticsPeriodFilter(
            period: .week,
            anchorDate: date(2026, 8, 5)
        )

        let bounds = StatisticsPeriodBuilder(calendar: calendar).bounds(for: filter)

        #expect(bounds.currentStart == date(2026, 8, 3))
        #expect(bounds.currentEnd == date(2026, 8, 10))
        #expect(bounds.previousStart == date(2026, 7, 27))
        #expect(bounds.previousEnd == date(2026, 8, 3))
    }

    @Test func customBoundsIncludeBothSelectedDatesAndUseAnEqualComparisonRange() {
        let filter = StatisticsPeriodFilter(
            period: .month,
            anchorDate: date(2026, 8, 5),
            customStartDate: date(2026, 8, 5),
            customEndDate: date(2026, 8, 7)
        )

        let builder = StatisticsPeriodBuilder(calendar: calendar)
        let bounds = builder.bounds(for: filter)
        let snapshot = builder.build(
            flowRecords: [],
            achievementRecords: [],
            filter: filter
        )

        #expect(bounds.currentStart == date(2026, 8, 5))
        #expect(bounds.currentEnd == date(2026, 8, 8))
        #expect(bounds.previousStart == date(2026, 8, 2))
        #expect(bounds.previousEnd == date(2026, 8, 5))
        #expect(snapshot.flowDays.map(\.date) == [
            date(2026, 8, 5),
            date(2026, 8, 6),
            date(2026, 8, 7)
        ])
    }

    @Test(arguments: [0, 2, 23])
    func customSelectionAndExportKeepTheirCalendarDates(boundaryHour: Int) {
        let builder = StatisticsPeriodBuilder(calendar: calendar, dayBoundary: AppDayBoundary(hour: boundaryHour))
        // Reversed picker endpoints must normalize without shifting either date.
        let filter = StatisticsPeriodFilter(
            period: .month, anchorDate: date(2026, 9, 5),
            customStartDate: date(2026, 9, 7), customEndDate: date(2026, 9, 5)
        )
        let snapshot = builder.build(
            flowRecords: [flowRecord(sessionID: UUID(), date: date(2026, 9, 7, 23), seconds: 120, areaID: nil, area: "", task: "Selected last day")],
            achievementRecords: [], filter: filter
        )
        #expect(snapshot.flowDays.map(\.date) == [date(2026, 9, 5), date(2026, 9, 6), date(2026, 9, 7)])
        #expect(snapshot.bounds.previousStart == date(2026, 9, 2))
        #expect(snapshot.summary.totalFocusSeconds == 120)
        #expect(snapshot.csvRows.first?.date == date(2026, 9, 7))
        #expect(StatisticsCSVExporter().export(rows: snapshot.csvRows, calendar: calendar).contains("2026-09-07,Selected last day"))
    }

    @Test func customPeriodAcrossDaylightSavingKeepsEverySelectedDate() {
        var localCalendar = calendar
        localCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let start = localCalendar.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let end = localCalendar.date(from: DateComponents(year: 2026, month: 3, day: 9))!
        let builder = StatisticsPeriodBuilder(calendar: localCalendar, dayBoundary: AppDayBoundary(hour: 2))
        let snapshot = builder.build(flowRecords: [], achievementRecords: [], filter: StatisticsPeriodFilter(
            anchorDate: start, customStartDate: start, customEndDate: end
        ))
        #expect(snapshot.flowDays.map { localCalendar.component(.day, from: $0.date) } == [7, 8, 9])
        #expect(snapshot.bounds.currentEnd.timeIntervalSince(snapshot.bounds.currentStart) == 71 * 3_600)
        #expect(snapshot.trend.count == 3)
    }

    @Test func multipleAreasFilterEveryProjectionAndKeepSessionCountsUnique() {
        let first = UUID(), second = UUID(), excluded = UUID(), session = UUID()
        let current = date(2026, 9, 7, 12)
        let previous = date(2026, 8, 7, 12)
        let records = [
            flowRecord(sessionID: session, date: current, seconds: 60, areaID: first, area: "First", task: "Work"),
            flowRecord(sessionID: session, date: current, seconds: 120, areaID: second, area: "Second", task: "Work"),
            flowRecord(sessionID: UUID(), date: current, seconds: 240, areaID: excluded, area: "Excluded", task: "Work"),
            flowRecord(sessionID: UUID(), date: current, seconds: 480, areaID: nil, area: "", task: "Work"),
            flowRecord(sessionID: UUID(), date: previous, seconds: 30, areaID: first, area: "First", task: "Work"),
            flowRecord(sessionID: UUID(), date: previous, seconds: 900, areaID: excluded, area: "Excluded", task: "Work")
        ]
        let achievements = [first, second, excluded].map { areaID in
            StatisticsPeriodAchievementRecord(completedAt: current, todoID: UUID(), todoTitle: "Work", todoHashtags: [], todoNotes: "", areaID: areaID, areaName: areaID == excluded ? "Excluded" : "Selected", areaSymbol: "", areaColorHex: nil)
        }
        let builder = StatisticsPeriodBuilder(calendar: calendar)
        var filter = StatisticsPeriodFilter(period: .month, anchorDate: current, areaIDs: [first, second], query: "work")
        let snapshot = builder.build(flowRecords: records, achievementRecords: achievements, filter: filter)
        #expect(snapshot.summary.totalFocusSeconds == 180)
        #expect(snapshot.summary.flowCount == 1)
        #expect(snapshot.summary.completedTaskCount == 2)
        #expect(snapshot.previousSummary.totalFocusSeconds == 30)
        #expect(snapshot.flowDays.reduce(0) { $0 + $1.totalFocusSeconds } == 180)
        #expect(snapshot.achievementDays.reduce(0) { $0 + $1.completedCount } == 2)
        #expect(snapshot.trend.reduce(0) { $0 + $1.focusSeconds } == 180)
        #expect(snapshot.areaDistribution.count == 2)
        #expect(snapshot.taskDistribution.first?.focusSeconds == 180)
        #expect(snapshot.csvRows.reduce(0) { $0 + $1.focusedSeconds } == 180)
        #expect(snapshot.csvRows.reduce(0) { $0 + $1.completedTaskCount } == 2)
        #expect(!snapshot.csvRows.contains { $0.area == "Excluded" })
        var sameSelection = filter
        sameSelection.areaIDs = [second, first]
        #expect(Set([filter, sameSelection]).count == 1)
        filter.areaIDs.removeAll()
        let all = builder.build(flowRecords: records, achievementRecords: achievements, filter: filter)
        #expect(all.summary.totalFocusSeconds == 900)
        #expect(all.summary.completedTaskCount == 3)
        filter.areaIDs = [second]
        #expect(builder.build(flowRecords: records, achievementRecords: achievements, filter: filter).summary.totalFocusSeconds == 120)
    }

    @Test func taskTitleSearchAggregatesRepeatedWorkAndExcludesSiblingSegments() {
        let readingID = UUID()
        let firstSessionID = UUID()
        let switchedSessionID = UUID()
        let records = [
            flowRecord(
                sessionID: firstSessionID,
                date: date(2026, 8, 4, 9),
                seconds: 25 * 60,
                areaID: readingID,
                area: "読書",
                task: "Dune"
            ),
            flowRecord(
                sessionID: switchedSessionID,
                date: date(2026, 8, 5, 9),
                seconds: 12 * 60,
                areaID: readingID,
                area: "読書",
                task: "Dune"
            ),
            flowRecord(
                sessionID: switchedSessionID,
                date: date(2026, 8, 5, 9, 12),
                seconds: 13 * 60,
                areaID: UUID(),
                area: "仕事",
                task: "Release notes"
            )
        ]
        let completion = StatisticsPeriodAchievementRecord(
            completedAt: date(2026, 8, 5, 10),
            todoID: UUID(),
            todoTitle: "Dune",
            todoHashtags: ["books"],
            todoNotes: "",
            areaID: readingID,
            areaName: "読書",
            areaSymbol: "📚",
            areaColorHex: "#00AA66"
        )

        let snapshot = StatisticsPeriodBuilder(calendar: calendar).build(
            flowRecords: records,
            achievementRecords: [completion],
            filter: StatisticsPeriodFilter(
                period: .week,
                anchorDate: date(2026, 8, 5),
                query: "dune"
            )
        )

        #expect(snapshot.summary.totalFocusSeconds == 37 * 60)
        #expect(snapshot.summary.flowCount == 2)
        #expect(snapshot.summary.completedTaskCount == 1)
        #expect(snapshot.taskDistribution.count == 1)
        #expect(snapshot.taskDistribution.first?.name == "Dune")
        #expect(snapshot.csvRows.reduce(0) { $0 + $1.focusedSeconds } == 37 * 60)
    }

    @Test func currentAndPreviousTrendUseTheSameDayPositions() {
        let current = flowRecord(
            sessionID: UUID(),
            date: date(2026, 8, 4, 9),
            seconds: 50 * 60,
            areaID: nil,
            area: "",
            task: "Deep work"
        )
        let previous = flowRecord(
            sessionID: UUID(),
            date: date(2026, 7, 28, 9),
            seconds: 25 * 60,
            areaID: nil,
            area: "",
            task: "Deep work"
        )

        let snapshot = StatisticsPeriodBuilder(calendar: calendar).build(
            flowRecords: [current, previous],
            achievementRecords: [],
            filter: StatisticsPeriodFilter(period: .week, anchorDate: date(2026, 8, 5))
        )

        #expect(snapshot.trend.count == 7)
        #expect(snapshot.flowDays.count == 7)
        #expect(snapshot.trend[1].focusSeconds == 50 * 60)
        #expect(snapshot.trend[1].previousFocusSeconds == 25 * 60)
        #expect(snapshot.previousSummary.totalFocusSeconds == 25 * 60)
    }

    @Test func yearTrendUsesTwelveMonthlyPoints() {
        let snapshot = StatisticsPeriodBuilder(calendar: calendar).build(
            flowRecords: [],
            achievementRecords: [],
            filter: StatisticsPeriodFilter(period: .year, anchorDate: date(2026, 8, 5))
        )

        #expect(snapshot.trend.count == 12)
        #expect(snapshot.flowDays.count == 365)
    }

    @Test func monthTrendUsesSevenDayTotalsInsteadOfDailySpikes() {
        let records = [
            flowRecord(
                sessionID: UUID(),
                date: date(2026, 8, 1, 9),
                seconds: 25 * 60,
                areaID: nil,
                area: "",
                task: "Reading"
            ),
            flowRecord(
                sessionID: UUID(),
                date: date(2026, 8, 7, 9),
                seconds: 50 * 60,
                areaID: nil,
                area: "",
                task: "Reading"
            ),
            flowRecord(
                sessionID: UUID(),
                date: date(2026, 8, 8, 9),
                seconds: 75 * 60,
                areaID: nil,
                area: "",
                task: "Reading"
            ),
            flowRecord(
                sessionID: UUID(),
                date: date(2026, 7, 1, 9),
                seconds: 20 * 60,
                areaID: nil,
                area: "",
                task: "Reading"
            )
        ]
        let achievements = [
            achievementRecord(date: date(2026, 8, 1, 10), title: "Reading"),
            achievementRecord(date: date(2026, 8, 7, 10), title: "Reading"),
            achievementRecord(date: date(2026, 8, 8, 10), title: "Reading"),
            achievementRecord(date: date(2026, 7, 1, 10), title: "Reading")
        ]

        let snapshot = StatisticsPeriodBuilder(calendar: calendar).build(
            flowRecords: records,
            achievementRecords: achievements,
            filter: StatisticsPeriodFilter(period: .month, anchorDate: date(2026, 8, 5))
        )

        #expect(snapshot.trend.count == 5)
        #expect(snapshot.flowDays.count == 31)
        #expect(snapshot.flowDays.last?.date == date(2026, 8, 31))
        #expect(snapshot.trend[0].focusSeconds == 75 * 60)
        #expect(snapshot.trend[0].previousFocusSeconds == 20 * 60)
        #expect(snapshot.trend[1].focusSeconds == 75 * 60)
        #expect(snapshot.trend[0].completedTaskCount == 2)
        #expect(snapshot.trend[0].previousCompletedTaskCount == 1)
        #expect(snapshot.trend[1].completedTaskCount == 1)
    }

    @Test func csvEscapesTextAndUsesStableMachineColumns() {
        let rows = [StatisticsCSVRow(
            date: date(2026, 8, 5),
            task: "Book, \"Dune\"",
            area: "Reading",
            hashtags: ["books", "sci-fi"],
            focusedSeconds: 25 * 60,
            flowCount: 2,
            completedTaskCount: 1
        )]

        let csv = StatisticsCSVExporter().export(rows: rows, calendar: calendar)

        #expect(csv.hasPrefix("date,task,area,hashtags,focused_seconds,focused_minutes,blocks,flow_count,completed_tasks\n"))
        #expect(csv.contains("2026-08-05,\"Book, \"\"Dune\"\"\",Reading,books sci-fi,1500,25,1,2,1"))
    }

    @Test func csvCanExportFlowAndTaskSpecificSchemas() {
        let rows = [
            StatisticsCSVRow(
                date: date(2026, 8, 5),
                task: "Deep work",
                area: "Work",
                hashtags: [],
                focusedSeconds: 25 * 60,
                flowCount: 1,
                completedTaskCount: 0
            ),
            StatisticsCSVRow(
                date: date(2026, 8, 6),
                task: "Release",
                area: "Work",
                hashtags: ["ship"],
                focusedSeconds: 0,
                flowCount: 0,
                completedTaskCount: 1
            )
        ]

        let exporter = StatisticsCSVExporter()
        let flowCSV = exporter.export(rows: rows, content: .flow, calendar: calendar)
        let taskCSV = exporter.export(rows: rows, content: .task, calendar: calendar)

        #expect(flowCSV.hasPrefix("date,task,area,hashtags,focused_seconds,focused_minutes,blocks,flow_count\n"))
        #expect(flowCSV.contains("Deep work"))
        #expect(!flowCSV.contains("Release"))
        #expect(taskCSV.hasPrefix("date,task,area,hashtags,completed_tasks\n"))
        #expect(taskCSV.contains("Release"))
        #expect(!taskCSV.contains("Deep work"))
    }

    @Test func projectionActorMapsSearchableSegmentContext() async throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let reading = Area(name: "読書", type: .habit, symbolName: "📚", colorHex: "#00AA66")
        let work = Area(name: "仕事", type: .neutral, symbolName: "💻", colorHex: "#3366FF")
        let dune = Todo(title: "Dune", hashtags: ["books"], area: reading)
        let release = Todo(title: "Release", area: work)
        let start = date(2026, 8, 5, 9)
        let session = FlowSession(
            area: reading,
            todo: dune,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: start,
            plannedEndAt: start.addingTimeInterval(25 * 60),
            endedAt: start.addingTimeInterval(25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        let first = FlowSegment(
            session: session,
            area: reading,
            todo: dune,
            startedAt: start,
            startFocusSeconds: 0
        )
        first.close(at: start.addingTimeInterval(12 * 60), totalFocusSeconds: 12 * 60)
        let second = FlowSegment(
            session: session,
            area: work,
            todo: release,
            startedAt: start.addingTimeInterval(12 * 60),
            startFocusSeconds: 12 * 60
        )
        second.close(at: start.addingTimeInterval(25 * 60), totalFocusSeconds: 25 * 60)
        session.resolvedSegments = [first, second]
        context.insert(reading)
        context.insert(work)
        context.insert(dune)
        context.insert(release)
        context.insert(session)
        try context.save()

        let snapshot = try await StatisticsProjectionActor(modelContainer: container).load(
            filter: StatisticsPeriodFilter(
                period: .week,
                anchorDate: start,
                query: "Dune"
            ),
            calendar: calendar,
            dayBoundary: .midnight
        )

        #expect(snapshot.summary.totalFocusSeconds == 12 * 60)
        #expect(snapshot.summary.flowCount == 1)
        #expect(snapshot.taskDistribution.first?.name == "Dune")
    }

    @Test func distributionDetailsGroupLogicalDaysAndAreaTasksWithinFilters() throws {
        let area = UUID()
        let records = [
            flowRecord(sessionID: UUID(), date: date(2026, 9, 7, 10), seconds: 600, areaID: area, area: "Study", task: "Read"),
            flowRecord(sessionID: UUID(), date: date(2026, 9, 8, 1), seconds: 300, areaID: area, area: "Study", task: "read"),
            flowRecord(sessionID: UUID(), date: date(2026, 9, 8, 10), seconds: 1200, areaID: area, area: "Study", task: "Read"),
            flowRecord(sessionID: UUID(), date: date(2026, 9, 8, 11), seconds: 60, areaID: area, area: "Study", task: "Write"),
            flowRecord(sessionID: UUID(), date: date(2026, 9, 8, 11), seconds: 90, areaID: UUID(), area: "Other", task: "Read"),
            flowRecord(sessionID: UUID(), date: date(2026, 8, 8, 11), seconds: 900, areaID: area, area: "Study", task: "Read")
        ]
        let builder = StatisticsPeriodBuilder(calendar: calendar, dayBoundary: AppDayBoundary(hour: 2))
        var filter = StatisticsPeriodFilter(period: .month, anchorDate: date(2026, 9, 11), areaIDs: [area])
        let snapshot = builder.build(flowRecords: records, achievementRecords: [], filter: filter)
        let task = try #require(snapshot.taskDistribution.first)
        #expect(task.details.map(\.date) == [date(2026, 9, 7), date(2026, 9, 8)])
        #expect(task.details.map(\.focusSeconds) == [900, 1200])
        let details = try #require(snapshot.areaDistribution.first).details
        #expect(details.map(\.focusSeconds) == [2100, 60])
        #expect(details.allSatisfy { $0.date == nil })
        filter.query = "Read"
        let searched = builder.build(flowRecords: records, achievementRecords: [], filter: filter)
        #expect(searched.areaDistribution.first?.details.count == 1)
        #expect(searched.areaDistribution.first?.details.first?.focusSeconds == 2100)
    }

    @Test func remainderDistributionDetailsIncludeAndMergeEveryHiddenCategory() throws {
        let records = (0..<8).map { index in
            flowRecord(sessionID: UUID(), date: date(2026, 9, 7, 10), seconds: (index + 1) * 60,
                       areaID: UUID(), area: "Area \(index)", task: "Task \(index)")
        }
        let snapshot = StatisticsPeriodBuilder(calendar: calendar, dayBoundary: .midnight).build(
            flowRecords: records, achievementRecords: [],
            filter: StatisticsPeriodFilter(period: .month, anchorDate: date(2026, 9, 11))
        )
        let taskRemainder = try #require(snapshot.taskDistribution.last)
        #expect(taskRemainder.id == "distribution:other")
        #expect(taskRemainder.details.count == 1)
        #expect(taskRemainder.details.first?.focusSeconds == 360)
        #expect(snapshot.areaDistribution.last?.details.count == 3)
        for item in snapshot.taskDistribution + snapshot.areaDistribution {
            #expect(item.details.reduce(0) { $0 + $1.focusSeconds } == item.focusSeconds)
        }
    }

    private func flowRecord(
        sessionID: UUID,
        date: Date,
        seconds: Int,
        areaID: UUID?,
        area: String,
        task: String
    ) -> StatisticsPeriodFlowRecord {
        StatisticsPeriodFlowRecord(
            sessionID: sessionID,
            startedAt: date,
            focusSeconds: seconds,
            areaID: areaID,
            areaName: area,
            areaSymbol: area.isEmpty ? "" : "🎯",
            areaColorHex: "#00AA66",
            todoID: UUID(),
            todoTitle: task,
            todoHashtags: [],
            todoNotes: "",
            intent: "",
            result: ""
        )
    }

    private func achievementRecord(date: Date, title: String) -> StatisticsPeriodAchievementRecord {
        StatisticsPeriodAchievementRecord(
            completedAt: date,
            todoID: UUID(),
            todoTitle: title,
            todoHashtags: [],
            todoNotes: "",
            areaID: nil,
            areaName: "",
            areaSymbol: "",
            areaColorHex: "#00AA66"
        )
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 0,
        _ minute: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
