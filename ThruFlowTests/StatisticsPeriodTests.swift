//
//  StatisticsPeriodTests.swift
//  ThruFlowTests
//
//  Created by Codex on 2026/08/03.
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

    @Test func taskTitleSearchAggregatesRepeatedWorkAndExcludesSiblingSegments() {
        let readingID = UUID()
        let firstSessionID = UUID()
        let switchedSessionID = UUID()
        let records = [
            flowRecord(
                sessionID: firstSessionID,
                date: date(2026, 8, 4, 9),
                seconds: 25 * 60,
                directionID: readingID,
                direction: "読書",
                task: "Dune"
            ),
            flowRecord(
                sessionID: switchedSessionID,
                date: date(2026, 8, 5, 9),
                seconds: 12 * 60,
                directionID: readingID,
                direction: "読書",
                task: "Dune"
            ),
            flowRecord(
                sessionID: switchedSessionID,
                date: date(2026, 8, 5, 9, 12),
                seconds: 13 * 60,
                directionID: UUID(),
                direction: "仕事",
                task: "Release notes"
            )
        ]
        let completion = StatisticsPeriodAchievementRecord(
            completedAt: date(2026, 8, 5, 10),
            todoID: UUID(),
            todoTitle: "Dune",
            todoHashtags: ["books"],
            todoNotes: "",
            directionID: readingID,
            directionName: "読書",
            directionSymbol: "📚",
            directionColorHex: "#00AA66"
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
            directionID: nil,
            direction: "",
            task: "Deep work"
        )
        let previous = flowRecord(
            sessionID: UUID(),
            date: date(2026, 7, 28, 9),
            seconds: 25 * 60,
            directionID: nil,
            direction: "",
            task: "Deep work"
        )

        let snapshot = StatisticsPeriodBuilder(calendar: calendar).build(
            flowRecords: [current, previous],
            achievementRecords: [],
            filter: StatisticsPeriodFilter(period: .week, anchorDate: date(2026, 8, 5))
        )

        #expect(snapshot.trend.count == 7)
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

    @Test func csvEscapesTextAndUsesStableMachineColumns() {
        let rows = [StatisticsCSVRow(
            date: date(2026, 8, 5),
            task: "Book, \"Dune\"",
            direction: "Reading",
            hashtags: ["books", "sci-fi"],
            focusedSeconds: 25 * 60,
            flowCount: 2,
            completedTaskCount: 1
        )]

        let csv = StatisticsCSVExporter().export(rows: rows, calendar: calendar)

        #expect(csv.hasPrefix("date,task,direction,hashtags,focused_seconds,focused_minutes,blocks,flow_count,completed_tasks\n"))
        #expect(csv.contains("2026-08-05,\"Book, \"\"Dune\"\"\",Reading,books sci-fi,1500,25,1,2,1"))
    }

    @Test func projectionActorMapsSearchableSegmentContext() async throws {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let reading = Direction(name: "読書", type: .habit, symbolName: "📚", colorHex: "#00AA66")
        let work = Direction(name: "仕事", type: .neutral, symbolName: "💻", colorHex: "#3366FF")
        let dune = Todo(title: "Dune", hashtags: ["books"], direction: reading)
        let release = Todo(title: "Release", direction: work)
        let start = date(2026, 8, 5, 9)
        let session = FlowSession(
            direction: reading,
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
            direction: reading,
            todo: dune,
            startedAt: start,
            startFocusSeconds: 0
        )
        first.close(at: start.addingTimeInterval(12 * 60), totalFocusSeconds: 12 * 60)
        let second = FlowSegment(
            session: session,
            direction: work,
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

    private func flowRecord(
        sessionID: UUID,
        date: Date,
        seconds: Int,
        directionID: UUID?,
        direction: String,
        task: String
    ) -> StatisticsPeriodFlowRecord {
        StatisticsPeriodFlowRecord(
            sessionID: sessionID,
            startedAt: date,
            focusSeconds: seconds,
            directionID: directionID,
            directionName: direction,
            directionSymbol: direction.isEmpty ? "" : "🎯",
            directionColorHex: "#00AA66",
            todoID: UUID(),
            todoTitle: task,
            todoHashtags: [],
            todoNotes: "",
            intent: "",
            result: ""
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
