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

    @Test func builderProjectsActualHistoryAndExcludesPendingScheduledTask() {
        let day = Date(timeIntervalSince1970: 1783987200)
        let direction = Direction(name: "仕事", type: .neutral, symbolName: "💻", colorHex: "#34C759")
        let flowTodo = Todo(title: "実装", direction: direction, scheduledDate: day)
        let completedTodo = Todo(
            title: "レビュー",
            direction: direction,
            status: .completed,
            completedAt: day.addingTimeInterval(15 * 3600),
            scheduledDate: day
        )
        let pendingTodo = Todo(title: "資料", direction: direction, scheduledDate: day)
        let legacyTodo = Todo(
            title: "旧タスク",
            direction: direction,
            status: .completed,
            scheduledDate: day,
            updatedAt: day.addingTimeInterval(16 * 3600)
        )
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
        let interval = HistoryCalendarRange.day.interval(containing: day, calendar: calendar)

        let snapshot = HistoryCalendarBuilder(calendar: calendar).build(
            interval: interval,
            sessions: [session],
            breaks: [rest],
            todos: [flowTodo, completedTodo, pendingTodo, legacyTodo],
            referenceDate: interval.end
        )

        #expect(snapshot.items.filter { $0.kind == .flow }.count == 1)
        #expect(snapshot.items.filter { $0.kind == .rest }.count == 1)
        #expect(snapshot.items.filter { $0.kind == .completedTask }.count == 1)
        #expect(snapshot.items.filter { $0.kind == .untimedTask }.count == 1)
        #expect(snapshot.items.allSatisfy { $0.todo?.id != pendingTodo.id })
        #expect(snapshot.items.first { $0.kind == .rest }?.durationSeconds == 5 * 60)
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
}
