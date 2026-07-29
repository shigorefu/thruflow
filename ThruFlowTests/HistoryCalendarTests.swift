//
//  HistoryCalendarTests.swift
//  ThruFlowTests
//
//  Created by Codex on 2026/07/14.
//

import Foundation
import Testing
@testable import ThruFlow

@MainActor
struct HistoryCalendarTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    @Test func rangesUseCalendarDayWeekAndMonthBoundaries() {
        let date = Date(timeIntervalSince1970: 1784016000) // 2026-07-14 08:00 UTC

        let day = HistoryCalendarRange.day.interval(containing: date, calendar: calendar)
        let week = HistoryCalendarRange.week.interval(containing: date, calendar: calendar)
        let month = HistoryCalendarRange.month.interval(containing: date, calendar: calendar)

        #expect(day.duration == 86_400)
        #expect(calendar.component(.weekday, from: week.start) == 2)
        #expect(calendar.component(.day, from: month.start) == 1)
        #expect(calendar.component(.month, from: month.start) == 7)
    }

    @Test func builderProjectsOnlyFlowAndBreakHistory() {
        let day = Date(timeIntervalSince1970: 1783987200)
        let direction = Direction(name: "仕事", type: .neutral, symbolName: "💻", colorHex: "#34C759")
        let flowTodo = Todo(title: "実装", direction: direction, scheduledDate: day)
        let session = FlowSession(
            direction: direction,
            todo: flowTodo,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: day.addingTimeInterval(10 * 3600),
            plannedEndAt: day.addingTimeInterval(10 * 3600 + 25 * 60),
            endedAt: day.addingTimeInterval(10 * 3600 + 25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        let rest = FlowBreak(
            seriesID: session.seriesID!,
            previousSessionID: session.id,
            startedAt: day.addingTimeInterval(10 * 3600 + 25 * 60),
            timerStoppedAt: day.addingTimeInterval(10 * 3600 + 30 * 60),
            plannedDurationSeconds: 5 * 60
        )
        let separateSession = FlowSession(
            direction: direction,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: day.addingTimeInterval(12 * 3600),
            plannedEndAt: day.addingTimeInterval(12 * 3600 + 25 * 60),
            endedAt: day.addingTimeInterval(12 * 3600 + 25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        let interval = HistoryCalendarRange.day.interval(containing: day, calendar: calendar)

        let snapshot = HistoryCalendarBuilder(calendar: calendar).build(
            interval: interval,
            sessions: [session, separateSession],
            breaks: [rest],
            referenceDate: interval.end
        )
        #expect(snapshot.items.filter { $0.kind == .flow }.count == 2)
        #expect(snapshot.items.filter { $0.kind == .rest }.count == 1)
        #expect(snapshot.items.count == 3)
        #expect(snapshot.items.allSatisfy { $0.kind == .flow || $0.kind == .rest })
        #expect(snapshot.items.first { $0.kind == .rest }?.durationSeconds == 5 * 60)
        let directionOnlyItem = snapshot.items.first { $0.session?.id == separateSession.id }
        #expect(directionOnlyItem?.todo == nil)
        #expect(directionOnlyItem?.session?.direction?.id == direction.id)
    }

    @Test func overlapLayoutSharesLanesOnlyInsideConnectedCluster() {
        let base = Date(timeIntervalSince1970: 10_000)
        let placements = HistoryOverlapLayout().place([
            HistoryOverlapInput(id: "a", start: base, end: base.addingTimeInterval(60)),
            HistoryOverlapInput(id: "b", start: base.addingTimeInterval(30), end: base.addingTimeInterval(90)),
            HistoryOverlapInput(id: "c", start: base.addingTimeInterval(120), end: base.addingTimeInterval(180))
        ])
        let byID = Dictionary(uniqueKeysWithValues: placements.map { ($0.id, $0) })

        #expect(byID["a"]?.laneCount == 2)
        #expect(byID["b"]?.lane == 1)
        #expect(byID["c"]?.lane == 0)
        #expect(byID["c"]?.laneCount == 1)
    }

    @Test func overlapLayoutUsesMinimumVisualDurationForShortEntries() {
        let base = Date(timeIntervalSince1970: 10_000)
        let placements = HistoryOverlapLayout().place([
            HistoryOverlapInput(id: "short", start: base, end: base.addingTimeInterval(3 * 60)),
            HistoryOverlapInput(id: "next", start: base.addingTimeInterval(8 * 60), end: base.addingTimeInterval(20 * 60))
        ], minimumDuration: 15 * 60)
        let byID = Dictionary(uniqueKeysWithValues: placements.map { ($0.id, $0) })

        #expect(byID["short"]?.laneCount == 2)
        #expect(byID["next"]?.lane == 1)
    }

    @Test func contiguousFlowAndBreaksStayInOneLaneUsingActualTime() {
        let base = Date(timeIntervalSince1970: 10_000)
        let firstEnd = base.addingTimeInterval(12 * 60)
        let breakEnd = firstEnd.addingTimeInterval(3 * 60)
        let secondEnd = breakEnd.addingTimeInterval(12 * 60)
        let placements = HistoryOverlapLayout().place([
            HistoryOverlapInput(id: "flow-1", start: base, end: firstEnd),
            HistoryOverlapInput(id: "rest", start: firstEnd, end: breakEnd),
            HistoryOverlapInput(id: "flow-2", start: breakEnd, end: secondEnd)
        ])

        #expect(placements.allSatisfy { $0.lane == 0 && $0.laneCount == 1 })
    }

    @Test func dayElasticWindowWrapsActivityAndKeepsFourHourMinimum() {
        let day = Date(timeIntervalSince1970: 1783987200)
        let direction = Direction(name: "仕事", type: .neutral)
        let session = FlowSession(
            direction: direction,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: day.addingTimeInterval(10 * 3600 + 15 * 60),
            plannedEndAt: day.addingTimeInterval(10 * 3600 + 40 * 60),
            endedAt: day.addingTimeInterval(10 * 3600 + 40 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        let interval = HistoryCalendarRange.day.interval(containing: day, calendar: calendar)
        let item = HistoryCalendarBuilder(calendar: calendar).build(
            interval: interval,
            sessions: [session],
            breaks: []
        ).items[0]

        let range = HistoryDayTimelineWindowBuilder().hourRange(
            for: day,
            items: [item],
            scale: .elastic,
            now: day.addingTimeInterval(36 * 3600),
            calendar: calendar
        )

        #expect(range == 9..<13)
        #expect(HistoryDayTimelineWindowBuilder().hourRange(
            for: day,
            items: [item],
            scale: .fullDay,
            now: day.addingTimeInterval(36 * 3600),
            calendar: calendar
        ) == 0..<24)
    }

    @Test func dayElasticWindowIncludesActivityCrossingMidnight() {
        let day = Date(timeIntervalSince1970: 1783987200)
        let item = HistoryCalendarItem(
            id: "cross-midnight",
            kind: .flow,
            startedAt: day.addingTimeInterval(-15 * 60),
            endedAt: day.addingTimeInterval(30 * 60),
            title: "深夜 Flow",
            subtitle: "仕事",
            symbol: "🌙",
            colorHex: "#007AFF",
            session: nil,
            flowBreak: nil,
            todo: nil
        )

        let range = HistoryDayTimelineWindowBuilder().hourRange(
            for: day,
            items: [item],
            scale: .elastic,
            now: day.addingTimeInterval(36 * 3600),
            calendar: calendar
        )

        #expect(range == 0..<4)
    }

    @Test func seriesProjectorGroupsConnectedFlowAndBreakRecords() {
        let base = Date(timeIntervalSince1970: 10_000)
        let firstSeriesID = UUID()
        let secondSeriesID = UUID()
        let direction = Direction(name: "仕事", type: .neutral)
        let firstSession = FlowSession(
            seriesID: firstSeriesID,
            direction: direction,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: base,
            plannedEndAt: base.addingTimeInterval(12 * 60),
            endedAt: base.addingTimeInterval(12 * 60),
            plannedFocusDurationSeconds: 12 * 60,
            actualFocusDurationSeconds: 12 * 60,
            plannedBreakDurationSeconds: 3 * 60
        )
        let flowBreak = FlowBreak(
            seriesID: firstSeriesID,
            previousSessionID: firstSession.id,
            startedAt: base.addingTimeInterval(12 * 60),
            timerStoppedAt: base.addingTimeInterval(15 * 60),
            plannedDurationSeconds: 3 * 60
        )
        let secondSession = FlowSession(
            seriesID: secondSeriesID,
            direction: direction,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: base.addingTimeInterval(60 * 60),
            plannedEndAt: base.addingTimeInterval(72 * 60),
            endedAt: base.addingTimeInterval(72 * 60),
            plannedFocusDurationSeconds: 12 * 60,
            actualFocusDurationSeconds: 12 * 60,
            plannedBreakDurationSeconds: 3 * 60
        )
        let interval = DateInterval(start: base, end: base.addingTimeInterval(2 * 3600))
        let snapshot = HistoryCalendarBuilder(calendar: calendar).build(
            interval: interval,
            sessions: [firstSession, secondSession],
            breaks: [flowBreak],
            referenceDate: interval.end
        )

        let blocks = HistoryCalendarSeriesProjector().project(snapshot.items)

        #expect(blocks.count == 2)
        #expect(blocks.first { $0.seriesID == firstSeriesID }?.items.count == 2)
        #expect(blocks.first { $0.seriesID == secondSeriesID }?.items.count == 1)
    }

    @Test func dayTimelineConnectsOnlyContinuousRecordsFromTheSameSeries() throws {
        let base = Date(timeIntervalSince1970: 10_000)
        let firstSeriesID = UUID()
        let secondSeriesID = UUID()
        let direction = Direction(name: "仕事", type: .neutral)
        let firstSession = FlowSession(
            seriesID: firstSeriesID,
            direction: direction,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: base,
            plannedEndAt: base.addingTimeInterval(25 * 60),
            endedAt: base.addingTimeInterval(25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        let recordedBreak = FlowBreak(
            seriesID: firstSeriesID,
            previousSessionID: firstSession.id,
            startedAt: base.addingTimeInterval(25 * 60),
            timerStoppedAt: base.addingTimeInterval(30 * 60),
            plannedDurationSeconds: 5 * 60
        )
        let sameSeriesAfterMissingRecord = FlowSession(
            seriesID: firstSeriesID,
            direction: direction,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: base.addingTimeInterval(40 * 60),
            plannedEndAt: base.addingTimeInterval(65 * 60),
            endedAt: base.addingTimeInterval(65 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        let nextSeries = FlowSession(
            seriesID: secondSeriesID,
            direction: direction,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: base.addingTimeInterval(65 * 60),
            plannedEndAt: base.addingTimeInterval(90 * 60),
            endedAt: base.addingTimeInterval(90 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        let interval = DateInterval(start: base, end: base.addingTimeInterval(2 * 3600))
        let items = HistoryCalendarBuilder(calendar: calendar).build(
            interval: interval,
            sessions: [firstSession, sameSeriesAfterMissingRecord, nextSeries],
            breaks: [recordedBreak],
            referenceDate: interval.end
        ).items
        let policy = HistoryTimelineChainPolicy()
        let firstFlow = try #require(items.first { $0.session?.id == firstSession.id })
        let breakItem = try #require(items.first { $0.flowBreak?.id == recordedBreak.id })
        let flowAfterGap = try #require(items.first { $0.session?.id == sameSeriesAfterMissingRecord.id })
        let flowFromNextSeries = try #require(items.first { $0.session?.id == nextSeries.id })

        #expect(policy.connects(firstFlow, to: breakItem))
        #expect(!policy.connects(breakItem, to: flowAfterGap))
        #expect(!policy.connects(flowAfterGap, to: flowFromNextSeries))
    }

    @Test func timelineGapBuilderReturnsOnlyInternalLongGaps() {
        let base = Date(timeIntervalSince1970: 10_000)
        let interval = DateInterval(start: base, end: base.addingTimeInterval(6 * 3600))
        let first = HistoryCalendarItem(
            id: "first",
            kind: .flow,
            startedAt: base.addingTimeInterval(30 * 60),
            endedAt: base.addingTimeInterval(60 * 60),
            title: "First",
            subtitle: "",
            symbol: "1",
            colorHex: "#007AFF",
            session: nil,
            flowBreak: nil,
            todo: nil
        )
        let second = HistoryCalendarItem(
            id: "second",
            kind: .flow,
            startedAt: base.addingTimeInterval(3 * 3600),
            endedAt: base.addingTimeInterval(3.5 * 3600),
            title: "Second",
            subtitle: "",
            symbol: "2",
            colorHex: "#007AFF",
            session: nil,
            flowBreak: nil,
            todo: nil
        )

        let gaps = HistoryTimelineGapBuilder().internalGaps(
            in: interval,
            items: [second, first],
            minimumDuration: 60 * 60
        )

        #expect(gaps == [
            HistoryTimelineGap(
                startedAt: base.addingTimeInterval(60 * 60),
                endedAt: base.addingTimeInterval(3 * 3600)
            )
        ])
    }
}
