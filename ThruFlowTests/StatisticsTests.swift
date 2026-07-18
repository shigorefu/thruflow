//
//  StatisticsTests.swift
//  ThruFlowTests
//
//  Created by Codex on 2026/07/09.
//

import Foundation
import Testing
@testable import ThruFlow

struct StatisticsTests {
    @Test func mixedColorUsesFocusDurationWeights() {
        let color = StatisticsHeatmapBuilder.mixedHexColor([
            WeightedHexColor(hex: "#FF0000", weight: 25 * 60),
            WeightedHexColor(hex: "#0000FF", weight: 25 * 60)
        ])

        #expect(color == "#800080")
    }

    @Test func heatmapFiltersByDirectionAndBuildsEveryDayInRange() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let builder = StatisticsHeatmapBuilder(calendar: calendar)

        let reading = Direction(name: "読書", type: .habit, symbolName: "📚", colorHex: "#00FF00")
        let work = Direction(name: "仕事", type: .neutral, symbolName: "💻", colorHex: "#0000FF")
        let now = Date(timeIntervalSince1970: 2 * 24 * 60 * 60)

        let result = builder.build(
            sessions: [
                session(direction: reading, startedAt: now, seconds: 25 * 60),
                session(direction: work, startedAt: now, seconds: 50 * 60)
            ],
            filter: StatisticsFilter(range: .days180, directionID: reading.id),
            now: now
        )

        #expect(result.days.count == 180)
        #expect(result.summary.sessionCount == 1)
        #expect(result.summary.totalFocusSeconds == 25 * 60)
        #expect(result.days.last?.mixedColorHex == "#00FF00")
        #expect(result.days.last?.sessionCount == 1)
    }

    @Test func achievementHeatmapUsesCompletedTodosAndDirectionFilter() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let builder = AchievementHeatmapBuilder(calendar: calendar)

        let reading = Direction(name: "読書", type: .habit, symbolName: "📚", colorHex: "#00FF00")
        let work = Direction(name: "仕事", type: .neutral, symbolName: "💻", colorHex: "#0000FF")
        let now = Date(timeIntervalSince1970: 2 * 24 * 60 * 60)

        let result = builder.build(
            todos: [
                todo(direction: reading, updatedAt: now, status: .completed),
                todo(direction: work, updatedAt: now, status: .completed),
                todo(direction: reading, updatedAt: now, status: .active)
            ],
            filter: StatisticsFilter(range: .days180, directionID: reading.id),
            now: now
        )

        #expect(result.days.count == 180)
        #expect(result.summary.completedCount == 1)
        #expect(result.summary.activeDayCount == 1)
        #expect(result.days.last?.mixedColorHex == "#00FF00")
    }

    @Test func calendarYearRangeBuildsWholeYear() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let builder = StatisticsHeatmapBuilder(calendar: calendar)
        let reading = Direction(name: "読書", type: .habit, symbolName: "📚", colorHex: "#00FF00")
        let now = Date(timeIntervalSince1970: 1704067200)

        let result = builder.build(
            sessions: [
                session(direction: reading, startedAt: now, seconds: 12 * 60)
            ],
            filter: StatisticsFilter(range: .calendarYear),
            now: now
        )

        #expect(result.days.count == 366)
        #expect(result.days.first == StatisticsDay(
            date: now,
            totalFocusSeconds: 12 * 60,
            mixedColorHex: "#00FF00",
            directionCount: 1,
            sessionCount: 1
        ))
    }

    @Test func segmentedFlowFiltersAndMixesBySegmentDirection() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 4 * 24 * 60 * 60)
        let writing = Direction(name: "執筆", type: .neutral, colorHex: "#FF0000")
        let review = Direction(name: "確認", type: .neutral, colorHex: "#0000FF")
        let flow = session(direction: review, startedAt: now, seconds: 25 * 60)
        let first = FlowSegment(session: flow, direction: writing, todo: nil, startedAt: now, startFocusSeconds: 0)
        first.close(at: now.addingTimeInterval(10 * 60), totalFocusSeconds: 10 * 60)
        let second = FlowSegment(session: flow, direction: review, todo: nil, startedAt: now.addingTimeInterval(10 * 60), startFocusSeconds: 10 * 60)
        second.close(at: now.addingTimeInterval(25 * 60), totalFocusSeconds: 25 * 60)
        flow.resolvedSegments = [first, second]
        let builder = StatisticsHeatmapBuilder(calendar: calendar)

        let all = builder.build(sessions: [flow], filter: StatisticsFilter(range: .days180), now: now)
        let writingOnly = builder.build(
            sessions: [flow],
            filter: StatisticsFilter(range: .days180, directionID: writing.id),
            now: now
        )

        #expect(all.summary.sessionCount == 1)
        #expect(all.summary.totalFocusSeconds == 25 * 60)
        #expect(all.days.last?.directionCount == 2)
        #expect(writingOnly.summary.sessionCount == 1)
        #expect(writingOnly.summary.totalFocusSeconds == 10 * 60)
        #expect(writingOnly.days.last?.mixedColorHex == "#FF0000")
    }

    private func session(direction: Direction, startedAt: Date, seconds: Int) -> FlowSession {
        FlowSession(
            direction: direction,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: startedAt,
            plannedEndAt: startedAt.addingTimeInterval(TimeInterval(seconds)),
            endedAt: startedAt.addingTimeInterval(TimeInterval(seconds)),
            plannedFocusDurationSeconds: seconds,
            actualFocusDurationSeconds: seconds,
            plannedBreakDurationSeconds: 5 * 60
        )
    }

    private func todo(direction: Direction, updatedAt: Date, status: TodoStatus) -> Todo {
        Todo(
            title: "Task",
            direction: direction,
            status: status,
            updatedAt: updatedAt
        )
    }
}
