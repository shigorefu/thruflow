//
//  FlowDashboardTests.swift
//  ThruFlowTests
//
//  Created by Codex on 2026/07/12.
//

import Foundation
import Testing
@testable import ThruFlow

@MainActor
struct FlowDashboardTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func dashboardBuildsDailyTotalsPaletteAndTimelineFractions() {
        let day = Date(timeIntervalSince1970: 86_400)
        let reading = Direction(name: "読書", type: .neutral, symbolName: "📚", colorHex: "#34C759")
        let writing = Direction(name: "執筆", type: .neutral, symbolName: "✍️", colorHex: "#0A84FF")
        let first = makeSession(
            direction: reading,
            start: day.addingTimeInterval(6 * 3_600),
            duration: 25 * 60
        )
        let second = makeSession(
            direction: writing,
            start: day.addingTimeInterval(18 * 3_600),
            duration: 50 * 60
        )

        let snapshot = FlowDashboardBuilder(calendar: calendar).build(
            date: day.addingTimeInterval(20 * 3_600),
            sessions: [first, second]
        )

        #expect(snapshot.totalFocusSeconds == 75 * 60)
        #expect(snapshot.blocks == 3)
        #expect(snapshot.flowCount == 2)
        #expect(snapshot.palette == ["#0A84FF", "#34C759"])
        #expect(snapshot.directionSummaries.map(\.name) == ["執筆", "読書"])
        #expect(snapshot.directionSummaries.map(\.focusSeconds) == [50 * 60, 25 * 60])
        #expect(abs(snapshot.segments[0].startFraction - 0.25) < 0.0001)
        #expect(abs(snapshot.segments[1].startFraction - 0.75) < 0.0001)
    }

    @Test func elasticTimelineUsesCurrentAndFollowingHourWhenEmpty() {
        let now = Date(timeIntervalSince1970: 14 * 3_600 + 37 * 60)
        let range = FlowTimelineRange(
            date: now,
            segments: [],
            calendar: calendar
        )

        #expect(range.start == Date(timeIntervalSince1970: 14 * 3_600))
        #expect(range.end == Date(timeIntervalSince1970: 16 * 3_600))
        #expect(range.duration == 2 * 3_600)
    }

    @Test func elasticTimelineGrowsFromFirstFlowHourThroughLastFlowHour() {
        let day = Date(timeIntervalSince1970: 86_400)
        let direction = Direction(name: "仕事", type: .neutral)
        let morning = makeSession(
            direction: direction,
            start: day.addingTimeInterval(10 * 3_600 + 15 * 60),
            duration: 25 * 60
        )
        let afternoon = makeSession(
            direction: direction,
            start: day.addingTimeInterval(16 * 3_600 + 10 * 60),
            duration: 25 * 60
        )
        let snapshot = FlowDashboardBuilder(calendar: calendar).build(
            date: day.addingTimeInterval(17 * 3_600),
            sessions: [morning, afternoon]
        )
        let range = FlowTimelineRange(
            date: day,
            segments: snapshot.segments,
            calendar: calendar
        )

        #expect(range.start == day.addingTimeInterval(10 * 3_600))
        #expect(range.end == day.addingTimeInterval(17 * 3_600))
        #expect(range.labelDates(calendar: calendar) == [
            day.addingTimeInterval(10 * 3_600),
            day.addingTimeInterval(12 * 3_600),
            day.addingTimeInterval(14 * 3_600),
            day.addingTimeInterval(16 * 3_600),
            day.addingTimeInterval(17 * 3_600),
        ])
        #expect(abs(range.fraction(for: snapshot.segments[0].startedAt) - (15.0 / 420.0)) < 0.0001)
    }

    @Test func elasticTimelineKeepsTwoHourMinimumForOneFlow() {
        let day = Date(timeIntervalSince1970: 86_400)
        let direction = Direction(name: "仕事", type: .neutral)
        let session = makeSession(
            direction: direction,
            start: day.addingTimeInterval(10 * 3_600 + 15 * 60),
            duration: 25 * 60
        )
        let snapshot = FlowDashboardBuilder(calendar: calendar).build(
            date: day.addingTimeInterval(11 * 3_600),
            sessions: [session]
        )
        let range = FlowTimelineRange(
            date: day,
            segments: snapshot.segments,
            calendar: calendar
        )

        #expect(range.start == day.addingTimeInterval(10 * 3_600))
        #expect(range.end == day.addingTimeInterval(12 * 3_600))
    }

    @Test func dashboardBuildsPersistedBreakAndConnectedSeriesSpan() {
        let day = Date(timeIntervalSince1970: 86_400)
        let direction = Direction(name: "仕事", type: .neutral)
        let seriesID = UUID()
        let first = makeSession(
            direction: direction,
            start: day.addingTimeInterval(10 * 3_600),
            duration: 25 * 60,
            seriesID: seriesID
        )
        let secondStart = day.addingTimeInterval(10 * 3_600 + 30 * 60)
        let second = makeSession(
            direction: direction,
            start: secondStart,
            duration: 25 * 60,
            seriesID: seriesID
        )
        let flowBreak = FlowBreak(
            seriesID: seriesID,
            previousSessionID: first.id,
            nextSessionID: second.id,
            startedAt: first.endedAt!,
            timerStoppedAt: secondStart,
            connectedUntil: secondStart,
            plannedDurationSeconds: 5 * 60
        )

        let snapshot = FlowDashboardBuilder(calendar: calendar).build(
            date: day.addingTimeInterval(12 * 3_600),
            sessions: [first, second],
            breaks: [flowBreak]
        )

        #expect(snapshot.breaks.count == 1)
        #expect(snapshot.breaks[0].startedAt == first.endedAt)
        #expect(snapshot.breaks[0].endedAt == secondStart)
        #expect(snapshot.seriesSpans.count == 1)
        #expect(snapshot.seriesSpans[0].startedAt == first.startedAt)
        #expect(snapshot.seriesSpans[0].endedAt == second.endedAt)
    }

    @Test func dashboardSeriesSpanIncludesTrailingBreakWithoutConnectingNextSeries() {
        let day = Date(timeIntervalSince1970: 86_400)
        let direction = Direction(name: "仕事", type: .neutral)
        let firstSeriesID = UUID()
        let first = makeSession(
            direction: direction,
            start: day.addingTimeInterval(10 * 3_600),
            duration: 25 * 60,
            seriesID: firstSeriesID
        )
        let breakEnd = first.endedAt!.addingTimeInterval(5 * 60)
        let trailingBreak = FlowBreak(
            seriesID: firstSeriesID,
            previousSessionID: first.id,
            startedAt: first.endedAt!,
            timerStoppedAt: breakEnd,
            plannedDurationSeconds: 5 * 60
        )
        let second = makeSession(
            direction: direction,
            start: breakEnd.addingTimeInterval(30 * 60),
            duration: 25 * 60,
            seriesID: UUID()
        )

        let snapshot = FlowDashboardBuilder(calendar: calendar).build(
            date: day.addingTimeInterval(12 * 3_600),
            sessions: [first, second],
            breaks: [trailingBreak]
        )

        #expect(snapshot.seriesSpans.count == 1)
        #expect(snapshot.seriesSpans[0].id == firstSeriesID)
        #expect(snapshot.seriesSpans[0].startedAt == first.startedAt)
        #expect(snapshot.seriesSpans[0].endedAt == breakEnd)
    }

    @Test func liveFlowAppearsOnlyAfterCreditableMinuteAndUsesCurrentEndTime() {
        let day = Date(timeIntervalSince1970: 172_800)
        let direction = Direction(name: "仕事", type: .neutral, colorHex: "#FF9F0A")
        let start = day.addingTimeInterval(9 * 3_600)
        let session = FlowSession(
            direction: direction,
            mode: .twentyFiveFive,
            startedAt: start,
            plannedEndAt: start.addingTimeInterval(25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        let builder = FlowDashboardBuilder(calendar: calendar)

        let accidental = builder.build(
            date: start.addingTimeInterval(59),
            sessions: [session],
            activeSessionID: session.id,
            activeFocusSeconds: 59
        )
        let credited = builder.build(
            date: start.addingTimeInterval(10 * 60),
            sessions: [session],
            activeSessionID: session.id,
            activeFocusSeconds: 8 * 60
        )

        #expect(accidental.segments.isEmpty)
        #expect(credited.totalFocusSeconds == 8 * 60)
        #expect(credited.flowCount == 1)
        #expect(abs(credited.segments[0].endFraction - ((9 * 3_600 + 10 * 60) / 86_400.0)) < 0.0001)
    }

    @Test func dashboardExcludesOtherDaysAndInterruptedSessions() {
        let day = Date(timeIntervalSince1970: 259_200)
        let direction = Direction(name: "学習", type: .neutral)
        let valid = makeSession(direction: direction, start: day.addingTimeInterval(3_600), duration: 12 * 60)
        let interrupted = makeSession(
            direction: direction,
            start: day.addingTimeInterval(2 * 3_600),
            duration: 25 * 60,
            status: .interrupted
        )
        let tomorrow = makeSession(direction: direction, start: day.addingTimeInterval(26 * 3_600), duration: 25 * 60)

        let snapshot = FlowDashboardBuilder(calendar: calendar).build(
            date: day.addingTimeInterval(12 * 3_600),
            sessions: [valid, interrupted, tomorrow]
        )

        #expect(snapshot.segments.map(\.id) == [valid.id])
        #expect(snapshot.blocks == 0.5)
    }

    @Test func visualStateGrowsSmoothlyAndStopsAtSixBlocks() {
        let empty = FlowVisualState(blocks: 0, flowCount: 0, isActive: false, mode: .twentyFiveFive)
        let middle = FlowVisualState(blocks: 3, flowCount: 3, isActive: false, mode: .twentyFiveFive)
        let full = FlowVisualState(blocks: 6, flowCount: 8, isActive: false, mode: .twentyFiveFive)
        let overflow = FlowVisualState(blocks: 12, flowCount: 20, isActive: false, mode: .twentyFiveFive)

        #expect(empty.progress == 0)
        #expect(middle.progress == 0.5)
        #expect(full.progress == 1)
        #expect(overflow.progress == 1)
        #expect(empty.speed < middle.speed)
        #expect(middle.speed < full.speed)
        #expect(full.speed == overflow.speed)
        #expect(full.volume == overflow.volume)
        #expect(full.detail == overflow.detail)
        #expect(full.layerCount <= 8)
    }

    @Test func visualOccupancyStopsGrowingBeforeDetailReachesMaximum() {
        let fourBlocks = FlowVisualState(blocks: 4, flowCount: 4, isActive: false, mode: .twentyFiveFive)
        let sixBlocks = FlowVisualState(blocks: 6, flowCount: 6, isActive: false, mode: .twentyFiveFive)

        #expect(abs(fourBlocks.volume - 0.68) < 0.0001)
        #expect(fourBlocks.volume == sixBlocks.volume)
        #expect(fourBlocks.detail < sixBlocks.detail)
    }

    @Test func completedBlocksKeepIdleCalmAndAmplifyActiveFlow() {
        let emptyIdle = FlowVisualState(blocks: 0, flowCount: 0, isActive: false, mode: .twentyFiveFive)
        let fourBlockIdle = FlowVisualState(blocks: 4, flowCount: 4, isActive: false, mode: .twentyFiveFive)
        let fullIdle = FlowVisualState(blocks: 6, flowCount: 6, isActive: false, mode: .twentyFiveFive)
        let emptyActive = FlowVisualState(blocks: 0, flowCount: 0, isActive: true, mode: .twentyFiveFive)
        let fourBlockActive = FlowVisualState(blocks: 4, flowCount: 4, isActive: true, mode: .twentyFiveFive)
        let fullActive = FlowVisualState(blocks: 6, flowCount: 6, isActive: true, mode: .twentyFiveFive)

        #expect(emptyIdle.speed == 0.06)
        #expect(fourBlockIdle.speed > emptyIdle.speed)
        #expect(fourBlockIdle.speed < 0.28)
        #expect(abs(fullIdle.speed - 0.28) < 0.0001)
        #expect(emptyActive.speed == 1.10)
        #expect(fourBlockActive.speed > emptyActive.speed)
        #expect(fourBlockActive.speed > fourBlockIdle.speed)
        #expect(abs(fullActive.speed - 2.80) < 0.0001)
    }

    @Test func activeFlowAcceleratesWithoutChangingDailyGrowth() {
        let idle = FlowVisualState(blocks: 2, flowCount: 2, isActive: false, mode: .twentyFiveFive)
        let active = FlowVisualState(blocks: 2, flowCount: 2, isActive: true, mode: .twentyFiveFive)

        #expect(active.progress == idle.progress)
        #expect(active.volume == idle.volume)
        #expect(active.speed > idle.speed)
        #expect(active.speed - idle.speed >= 0.5)
    }

    @Test func animationClockKeepsPhaseContinuousWhenSpeedChanges() {
        let clock = FlowAnimationClock()
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        #expect(clock.phase(at: start, speed: 0.1, isPaused: false) == 0)
        #expect(abs(clock.phase(at: start.addingTimeInterval(2), speed: 0.1, isPaused: false) - 0.2) < 0.0001)

        let transitionPhase = clock.phase(
            at: start.addingTimeInterval(2),
            speed: 0.8,
            isPaused: false
        )
        #expect(abs(transitionPhase - 0.2) < 0.0001)
        #expect(abs(clock.phase(at: start.addingTimeInterval(3), speed: 0.8, isPaused: false) - 1.0) < 0.0001)
    }

    @Test func animationClockFreezesWhilePaused() {
        let clock = FlowAnimationClock()
        let start = Date(timeIntervalSinceReferenceDate: 2_000)

        _ = clock.phase(at: start, speed: 0.5, isPaused: false)
        #expect(abs(clock.phase(at: start.addingTimeInterval(2), speed: 0.5, isPaused: false) - 1.0) < 0.0001)
        #expect(abs(clock.phase(at: start.addingTimeInterval(20), speed: 0.5, isPaused: true) - 1.0) < 0.0001)
        #expect(abs(clock.phase(at: start.addingTimeInterval(40), speed: 0.5, isPaused: false) - 1.0) < 0.0001)
        #expect(abs(clock.phase(at: start.addingTimeInterval(41), speed: 0.5, isPaused: false) - 1.5) < 0.0001)
    }

    @Test func oneFlowWithTaskSwitchesBuildsMultipleTimelineSegments() {
        let day = Date(timeIntervalSince1970: 518_400)
        let writing = Direction(name: "執筆", type: .neutral, colorHex: "#0A84FF")
        let review = Direction(name: "レビュー", type: .neutral, colorHex: "#FF9F0A")
        let firstTodo = Todo(title: "本文", direction: writing)
        let secondTodo = Todo(title: "確認", direction: review)
        let session = makeSession(direction: review, start: day.addingTimeInterval(9 * 3_600), duration: 25 * 60)
        let first = FlowSegment(
            session: session,
            direction: writing,
            todo: firstTodo,
            startedAt: session.startedAt,
            startFocusSeconds: 0
        )
        first.close(at: session.startedAt.addingTimeInterval(16 * 60), totalFocusSeconds: 16 * 60)
        let second = FlowSegment(
            session: session,
            direction: review,
            todo: secondTodo,
            startedAt: session.startedAt.addingTimeInterval(16 * 60),
            startFocusSeconds: 16 * 60
        )
        second.close(at: session.startedAt.addingTimeInterval(25 * 60), totalFocusSeconds: 25 * 60)
        session.segments = [first, second]

        let snapshot = FlowDashboardBuilder(calendar: calendar).build(
            date: day.addingTimeInterval(12 * 3_600),
            sessions: [session]
        )

        #expect(snapshot.flowCount == 1)
        #expect(snapshot.segments.count == 2)
        #expect(snapshot.totalFocusSeconds == 25 * 60)
        #expect(snapshot.segments.map(\.taskTitle) == ["本文", "確認"])
        #expect(snapshot.segments.map(\.focusSeconds) == [16 * 60, 9 * 60])
        #expect(snapshot.taskSummaries.map(\.title) == ["本文", "確認"])
        #expect(snapshot.taskSummaries.map(\.focusSeconds) == [16 * 60, 9 * 60])
    }

    @Test func dashboardTaskSummaryCombinesFocusFromRepeatedFlows() {
        let day = Date(timeIntervalSince1970: 604_800)
        let direction = Direction(name: "開発", type: .neutral, colorHex: "#BF5AF2")
        let todo = Todo(title: "実装", direction: direction)
        let morning = makeSession(
            direction: direction,
            start: day.addingTimeInterval(9 * 3_600),
            duration: 25 * 60
        )
        let afternoon = makeSession(
            direction: direction,
            start: day.addingTimeInterval(14 * 3_600),
            duration: 50 * 60
        )
        morning.todo = todo
        afternoon.todo = todo

        let snapshot = FlowDashboardBuilder(calendar: calendar).build(
            date: day.addingTimeInterval(16 * 3_600),
            sessions: [morning, afternoon]
        )

        #expect(snapshot.taskSummaries.count == 1)
        #expect(snapshot.taskSummaries[0].title == "実装")
        #expect(snapshot.taskSummaries[0].focusSeconds == 75 * 60)
        #expect(snapshot.taskSummaries[0].colorHex == "#BF5AF2")
    }

    @Test func dashboardTodosSortByCompletionThenPriority() {
        let direction = Direction(name: "仕事", type: .neutral)
        let completedHigh = Todo(
            title: "完了済み",
            direction: direction,
            priority: .high,
            status: .completed,
            sortIndex: 0
        )
        let roomIfPossible = Todo(
            title: "余裕",
            direction: direction,
            priority: .low,
            isRoomIfPossible: true,
            sortIndex: 1
        )
        let low = Todo(title: "低", direction: direction, priority: .low, sortIndex: 2)
        let medium = Todo(title: "中", direction: direction, priority: .medium, sortIndex: 3)
        let highLater = Todo(title: "高2", direction: direction, priority: .high, sortIndex: 5)
        let highEarlier = Todo(title: "高1", direction: direction, priority: .high, sortIndex: 4)

        let sorted = FlowDashboardTodoSorter().sorted([
            completedHigh,
            roomIfPossible,
            low,
            medium,
            highLater,
            highEarlier,
        ])

        #expect(sorted.map(\.title) == ["高1", "高2", "中", "低", "余裕", "完了済み"])
    }

    @Test func dashboardStatisticsBuildsRequestedDayRange() {
        let day = Date(timeIntervalSince1970: 10 * 86_400)
        let direction = Direction(name: "開発", type: .neutral, colorHex: "#0A84FF")
        let earlier = makeSession(
            direction: direction,
            start: day.addingTimeInterval(-2 * 86_400 + 9 * 3_600),
            duration: 25 * 60
        )
        let current = makeSession(
            direction: direction,
            start: day.addingTimeInterval(9 * 3_600),
            duration: 50 * 60
        )

        let days = DashboardStatisticsBuilder(calendar: calendar).days(
            count: 3,
            endingOn: day,
            sessions: [earlier, current],
            breaks: []
        )

        #expect(days.count == 3)
        #expect(days.map(\.focusSeconds) == [25 * 60, 0, 50 * 60])
        #expect(days.last?.colorHex == "#0A84FF")
    }

    @Test func dashboardStatisticsComparesPreviousDayAndFindsGrowingDirection() {
        let day = Date(timeIntervalSince1970: 12 * 86_400)
        let direction = Direction(name: "開発", type: .neutral, symbolName: "💻")
        let previous = makeSession(
            direction: direction,
            start: day.addingTimeInterval(-86_400 + 9 * 3_600),
            duration: 25 * 60
        )
        let current = makeSession(
            direction: direction,
            start: day.addingTimeInterval(9 * 3_600),
            duration: 50 * 60
        )
        let previousTodo = Todo(
            title: "昨日",
            direction: direction,
            status: .completed,
            completedAt: day.addingTimeInterval(-86_400 + 12 * 3_600)
        )
        let firstTodayTodo = Todo(
            title: "今日1",
            direction: direction,
            status: .completed,
            completedAt: day.addingTimeInterval(12 * 3_600)
        )
        let secondTodayTodo = Todo(
            title: "今日2",
            direction: direction,
            status: .completed,
            completedAt: day.addingTimeInterval(13 * 3_600)
        )

        let comparison = DashboardStatisticsBuilder(calendar: calendar).comparison(
            on: day,
            sessions: [previous, current],
            breaks: [],
            todos: [previousTodo, firstTodayTodo, secondTodayTodo]
        )

        #expect(comparison.focusSecondsDelta == 25 * 60)
        #expect(comparison.completedTaskDelta == 1)
        #expect(comparison.blocksDelta == 1)
        #expect(comparison.growingDirection?.name == "開発")
        #expect(comparison.growingDirection?.focusSecondsDelta == 25 * 60)
    }

    private func makeSession(
        direction: Direction,
        start: Date,
        duration: Int,
        status: FlowSessionStatus = .completed,
        seriesID: UUID? = nil
    ) -> FlowSession {
        FlowSession(
            seriesID: seriesID,
            direction: direction,
            mode: .twentyFiveFive,
            phase: status == .completed ? .completed : .focusing,
            status: status,
            startedAt: start,
            plannedEndAt: start.addingTimeInterval(TimeInterval(duration)),
            endedAt: start.addingTimeInterval(TimeInterval(duration)),
            plannedFocusDurationSeconds: duration,
            actualFocusDurationSeconds: duration,
            plannedBreakDurationSeconds: 5 * 60
        )
    }
}
