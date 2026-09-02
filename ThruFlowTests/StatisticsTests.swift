//
//  StatisticsTests.swift
//  ThruFlowTests
//
//

import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct StatisticsTests {
    @Test func mixedColorUsesFocusDurationWeights() {
        let color = StatisticsHeatmapBuilder.mixedHexColor([
            WeightedHexColor(hex: "#FF0000", weight: 25 * 60),
            WeightedHexColor(hex: "#0000FF", weight: 25 * 60)
        ])

        #expect(color == "#800080")
    }

    @Test func heatmapFiltersByAreaAndBuildsEveryDayInRange() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let builder = StatisticsHeatmapBuilder(calendar: calendar)

        let reading = Area(name: "読書", type: .habit, symbolName: "📚", colorHex: "#00FF00")
        let work = Area(name: "仕事", type: .neutral, symbolName: "💻", colorHex: "#0000FF")
        let now = Date(timeIntervalSince1970: 2 * 24 * 60 * 60)

        let result = builder.build(
            sessions: [
                session(area: reading, startedAt: now, seconds: 25 * 60),
                session(area: work, startedAt: now, seconds: 50 * 60)
            ],
            filter: StatisticsFilter(range: .days180, areaID: reading.id),
            now: now
        )

        #expect(result.days.count == 180)
        #expect(result.summary.sessionCount == 1)
        #expect(result.summary.totalFocusSeconds == 25 * 60)
        #expect(result.days.last?.mixedColorHex == "#00FF00")
        #expect(result.days.last?.sessionCount == 1)
    }

    @Test func achievementHeatmapUsesCompletedTodosAndAreaFilter() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let builder = AchievementHeatmapBuilder(calendar: calendar)

        let reading = Area(name: "読書", type: .habit, symbolName: "📚", colorHex: "#00FF00")
        let work = Area(name: "仕事", type: .neutral, symbolName: "💻", colorHex: "#0000FF")
        let now = Date(timeIntervalSince1970: 2 * 24 * 60 * 60)

        let result = builder.build(
            todos: [
                todo(area: reading, updatedAt: now, status: .completed),
                todo(area: work, updatedAt: now, status: .completed),
                todo(area: reading, updatedAt: now, status: .active)
            ],
            filter: StatisticsFilter(range: .days180, areaID: reading.id),
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
        let reading = Area(name: "読書", type: .habit, symbolName: "📚", colorHex: "#00FF00")
        let now = Date(timeIntervalSince1970: 1704067200)

        let result = builder.build(
            sessions: [
                session(area: reading, startedAt: now, seconds: 12 * 60)
            ],
            filter: StatisticsFilter(range: .calendarYear),
            now: now
        )

        #expect(result.days.count == 366)
        #expect(result.days.first == StatisticsDay(
            date: now,
            totalFocusSeconds: 12 * 60,
            mixedColorHex: "#00FF00",
            areaCount: 1,
            sessionCount: 1
        ))
    }

    @Test func segmentedFlowFiltersAndMixesBySegmentArea() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 4 * 24 * 60 * 60)
        let writing = Area(name: "執筆", type: .neutral, colorHex: "#FF0000")
        let review = Area(name: "確認", type: .neutral, colorHex: "#0000FF")
        let flow = session(area: review, startedAt: now, seconds: 25 * 60)
        let first = FlowSegment(session: flow, area: writing, todo: nil, startedAt: now, startFocusSeconds: 0)
        first.close(at: now.addingTimeInterval(10 * 60), totalFocusSeconds: 10 * 60)
        let second = FlowSegment(session: flow, area: review, todo: nil, startedAt: now.addingTimeInterval(10 * 60), startFocusSeconds: 10 * 60)
        second.close(at: now.addingTimeInterval(25 * 60), totalFocusSeconds: 25 * 60)
        flow.resolvedSegments = [first, second]
        let builder = StatisticsHeatmapBuilder(calendar: calendar)

        let all = builder.build(sessions: [flow], filter: StatisticsFilter(range: .days180), now: now)
        let writingOnly = builder.build(
            sessions: [flow],
            filter: StatisticsFilter(range: .days180, areaID: writing.id),
            now: now
        )

        #expect(all.summary.sessionCount == 1)
        #expect(all.summary.totalFocusSeconds == 25 * 60)
        #expect(all.days.last?.areaCount == 2)
        #expect(writingOnly.summary.sessionCount == 1)
        #expect(writingOnly.summary.totalFocusSeconds == 10 * 60)
        #expect(writingOnly.days.last?.mixedColorHex == "#FF0000")
    }

    @Test func projectionActorFetchesOnlyTheRequestedPeriod() async throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_735_689_600)
        let area = Area(name: "読書", type: .habit, colorHex: "#00FF00")
        let currentSession = session(area: area, startedAt: now, seconds: 25 * 60)
        let oldSession = session(
            area: area,
            startedAt: calendar.date(byAdding: .day, value: -200, to: now)!,
            seconds: 25 * 60
        )
        let completedTodo = Todo(
            title: "本を読む",
            area: area,
            status: .completed,
            completedAt: now,
            updatedAt: calendar.date(byAdding: .day, value: 30, to: now)!
        )
        context.insert(area)
        context.insert(currentSession)
        context.insert(oldSession)
        context.insert(completedTodo)
        try context.save()

        let projection = try await StatisticsProjectionActor(modelContainer: container).load(
            filter: StatisticsFilter(range: .days180),
            calendar: calendar,
            dayBoundary: AppDayBoundary(hour: 0),
            now: now
        )

        #expect(projection.flow.summary.sessionCount == 1)
        #expect(projection.flow.summary.totalFocusSeconds == 25 * 60)
        #expect(projection.achievement.summary.completedCount == 1)
    }

    @Test func projectionActorUsesTheConfiguredDayBoundary() async throws {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 31,
            hour: 23
        ))!
        let sessionStart = calendar.date(from: DateComponents(
            year: 2026,
            month: 9,
            day: 1,
            hour: 1,
            minute: 45
        ))!
        let area = Area(name: "読書", type: .habit, colorHex: "#00FF00")
        context.insert(area)
        context.insert(session(area: area, startedAt: sessionStart, seconds: 25 * 60))
        try context.save()

        let projection = try await StatisticsProjectionActor(modelContainer: container).load(
            filter: StatisticsFilter(range: .currentMonth),
            calendar: calendar,
            dayBoundary: AppDayBoundary(hour: 2),
            now: now
        )

        #expect(projection.flow.summary.sessionCount == 1)
        #expect(projection.flow.summary.totalFocusSeconds == 25 * 60)
    }

    private func session(area: Area, startedAt: Date, seconds: Int) -> FlowSession {
        FlowSession(
            area: area,
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

    private func todo(area: Area, updatedAt: Date, status: TodoStatus) -> Todo {
        Todo(
            title: "Task",
            area: area,
            status: status,
            updatedAt: updatedAt
        )
    }
}
