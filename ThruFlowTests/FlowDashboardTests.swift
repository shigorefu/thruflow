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

    @Test func streamPaletteKeepsEveryActiveColorVisible() {
        let ribbons = FlowStreamPaletteLayout.ribbonColorHexes(
            palette: ["#FF9500", "#FFD60A", "#0A84FF", "#30D158"],
            weights: [0.50, 0.30, 0.15, 0.05],
            ribbonCount: 7
        )

        #expect(ribbons.count == 7)
        #expect(Set(ribbons) == Set(["#FF9500", "#FFD60A", "#0A84FF", "#30D158"]))
        #expect(ribbons.filter { $0 == "#FF9500" }.count > 1)
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
        #expect(abs(snapshot.paletteWeights[0] - (2.0 / 3.0)) < 0.0001)
        #expect(abs(snapshot.paletteWeights[1] - (1.0 / 3.0)) < 0.0001)
        #expect(snapshot.directionSummaries.map(\.name) == ["執筆", "読書"])
        #expect(snapshot.directionSummaries.map(\.focusSeconds) == [50 * 60, 25 * 60])
        #expect(abs(snapshot.focusShare(for: 50 * 60) - (2.0 / 3.0)) < 0.0001)
        #expect(abs(snapshot.focusShare(for: 25 * 60) - (1.0 / 3.0)) < 0.0001)
        #expect(abs(snapshot.segments[0].startFraction - 0.25) < 0.0001)
        #expect(abs(snapshot.segments[1].startFraction - 0.75) < 0.0001)
    }

    @Test func dashboardKeepsEarlyMorningFlowInPreviousLogicalDay() {
        let boundary = AppDayBoundary(hour: 2)
        let july16 = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 16)
        )!
        let earlyMorning = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 17, hour: 1)
        )!
        let direction = Direction(name: "深夜作業", type: .neutral)
        let session = makeSession(
            direction: direction,
            start: earlyMorning,
            duration: 25 * 60
        )
        let builder = FlowDashboardBuilder(
            calendar: calendar,
            dayBoundary: boundary
        )

        let previousDay = builder.build(
            date: earlyMorning,
            sessions: [session]
        )
        #expect(previousDay.date == july16)
        #expect(previousDay.totalFocusSeconds == 25 * 60)

        let nextDay = builder.build(
            date: calendar.date(
                from: DateComponents(year: 2026, month: 7, day: 17, hour: 2)
            )!,
            sessions: [session]
        )
        #expect(nextDay.totalFocusSeconds == 0)
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
        #expect(empty.identityReveal == 0)
        #expect(middle.progress == 0.5)
        #expect(full.progress == 1)
        #expect(overflow.progress == 1)
        #expect(empty.speed < middle.speed)
        #expect(middle.speed < full.speed)
        #expect(full.speed == overflow.speed)
        #expect(full.volume == overflow.volume)
        #expect(full.detail == overflow.detail)
        #expect(FlowVisualState.baselineRibbonCount == 6)
        #expect(FlowVisualState.ribbonCount == 7)
    }

    @Test func dailyIdentityEmergesDuringFirstBlock() {
        let empty = FlowVisualState(blocks: 0, flowCount: 0, isActive: false, mode: .twentyFiveFive)
        let halfBlock = FlowVisualState(blocks: 0.5, flowCount: 1, isActive: false, mode: .twentyFiveFive)
        let firstBlock = FlowVisualState(blocks: 1, flowCount: 1, isActive: false, mode: .twentyFiveFive)
        let later = FlowVisualState(blocks: 4, flowCount: 4, isActive: false, mode: .twentyFiveFive)

        #expect(empty.identityReveal == 0)
        #expect(abs(halfBlock.identityReveal - 0.5) < 0.0001)
        #expect(firstBlock.identityReveal == 1)
        #expect(later.identityReveal == 1)
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

        #expect(abs(emptyIdle.speed - 0.075) < 0.0001)
        #expect(fourBlockIdle.speed > emptyIdle.speed)
        #expect(fourBlockIdle.speed < 0.35)
        #expect(abs(fullIdle.speed - 0.35) < 0.0001)
        #expect(abs(emptyActive.speed - 1.375) < 0.0001)
        #expect(fourBlockActive.speed > emptyActive.speed)
        #expect(fourBlockActive.speed > fourBlockIdle.speed)
        #expect(abs(fullActive.speed - 3.50) < 0.0001)
        #expect(FlowVisualState.speedMultiplier == 1.25)
    }

    @Test func activeFlowAcceleratesWithoutChangingDailyGrowth() {
        let idle = FlowVisualState(blocks: 2, flowCount: 2, isActive: false, mode: .twentyFiveFive)
        let active = FlowVisualState(blocks: 2, flowCount: 2, isActive: true, mode: .twentyFiveFive)

        #expect(active.progress == idle.progress)
        #expect(active.volume == idle.volume)
        #expect(active.speed > idle.speed)
        #expect(active.speed - idle.speed >= 0.5)
    }

    @Test func dailyAppearanceIsStableForOneProfileAndCalendarDay() {
        let identity = UUID(uuidString: "A5220B23-7957-49AA-A796-65D20424BE06")!
        let morning = Date(timeIntervalSince1970: 10 * 86_400 + 8 * 3_600)
        let evening = Date(timeIntervalSince1970: 10 * 86_400 + 21 * 3_600)

        let first = DailyFlowAppearance(date: morning, identityID: identity, calendar: calendar)
        let second = DailyFlowAppearance(date: evening, identityID: identity, calendar: calendar)

        #expect(first == second)
    }

    @Test func dailyAppearanceChangesForAnotherDayOrProfile() {
        let firstIdentity = UUID(uuidString: "A5220B23-7957-49AA-A796-65D20424BE06")!
        let secondIdentity = UUID(uuidString: "81F71AD5-9D05-4A99-892B-0F733D083EB4")!
        let day = Date(timeIntervalSince1970: 10 * 86_400)
        let nextDay = day.addingTimeInterval(86_400)

        let baseline = DailyFlowAppearance(date: day, identityID: firstIdentity, calendar: calendar)
        let anotherDay = DailyFlowAppearance(date: nextDay, identityID: firstIdentity, calendar: calendar)
        let anotherProfile = DailyFlowAppearance(date: day, identityID: secondIdentity, calendar: calendar)

        #expect(baseline.seed != anotherDay.seed)
        #expect(baseline.seed != anotherProfile.seed)
    }

    @Test func dailyIdentityUsesOldestSyncedDirection() {
        let firstID = UUID(uuidString: "A5220B23-7957-49AA-A796-65D20424BE06")!
        let secondID = UUID(uuidString: "81F71AD5-9D05-4A99-892B-0F733D083EB4")!
        let first = Direction(
            id: firstID,
            name: "First",
            type: .neutral,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let second = Direction(
            id: secondID,
            name: "Second",
            type: .neutral,
            createdAt: Date(timeIntervalSince1970: 200)
        )

        #expect(DailyFlowIdentity.resolve(from: [second, first]) == firstID)
    }

    @Test func renderCadenceUsesSixtyActiveAndThirtyIdleFramesPerSecond() {
        #expect(FlowRenderCadence.frameInterval(isActive: true) == 1.0 / 60.0)
        #expect(FlowRenderCadence.frameInterval(isActive: false) == 1.0 / 30.0)
    }

    @Test func restReactionTimingsAndStyleEncodingsAreBounded() {
        let start = Date(timeIntervalSinceReferenceDate: 3_000)

        #expect(
            FlowStreamReactionTiming.duration(for: .requested) ==
                FlowStreamReactionTiming.requestDuration
        )
        #expect(
            FlowStreamReactionTiming.duration(for: .started(isLong: false)) ==
                FlowStreamReactionTiming.regularBreakDuration
        )
        #expect(
            FlowStreamReactionTiming.duration(for: .started(isLong: true)) ==
                FlowStreamReactionTiming.longBreakDuration
        )
        #expect(FlowStreamReactionTiming.longBreakDuration > FlowStreamReactionTiming.regularBreakDuration)
        #expect(FlowStreamBreakStyle.none.rawValue == 0)
        #expect(FlowStreamBreakStyle.regular.rawValue == 1)
        #expect(FlowStreamBreakStyle.long.rawValue == 2)

        #expect(
            FlowStreamReactionTiming.progress(
                at: start.addingTimeInterval(-0.1),
                since: start,
                duration: 2
            ) == -1
        )
        #expect(FlowStreamReactionTiming.progress(at: start, since: start, duration: 2) == 0)
        #expect(
            FlowStreamReactionTiming.progress(
                at: start.addingTimeInterval(1),
                since: start,
                duration: 2
            ) == 0.5
        )
        #expect(
            FlowStreamReactionTiming.progress(
                at: start.addingTimeInterval(2),
                since: start,
                duration: 2
            ) == 1
        )
        #expect(
            FlowStreamReactionTiming.progress(
                at: start.addingTimeInterval(2.1),
                since: start,
                duration: 2
            ) == -1
        )
        #expect(FlowStreamReactionTiming.envelope(for: -1) == 0)
        #expect(abs(FlowStreamReactionTiming.envelope(for: 0.5) - 1) < 0.0001)
        #expect(abs(FlowStreamReactionTiming.envelope(for: 1)) < 0.0001)
    }

    @Test func reactionStateRetriggersRequestsAndRejectsStaleConfirmedBreaks() {
        let firstAt = Date(timeIntervalSinceReferenceDate: 4_000)
        let secondAt = firstAt.addingTimeInterval(0.2)
        let regularAt = firstAt.addingTimeInterval(1)
        let longAt = firstAt.addingTimeInterval(2)
        var state = FlowStreamReactionState()

        state.consume(
            FlowBreakInteraction(sequence: 1, kind: .requested, occurredAt: firstAt),
            breakStyle: .none
        )
        #expect(state.restRequestStartedAt == firstAt)

        state.consume(
            FlowBreakInteraction(sequence: 2, kind: .requested, occurredAt: secondAt),
            breakStyle: .none
        )
        #expect(state.restRequestStartedAt == secondAt)
        #expect(
            abs(
                state.progress(
                    for: .requested,
                    at: secondAt.addingTimeInterval(0.7)
                ) - 0.5
            ) < 0.0001
        )

        let regular = FlowBreakInteraction(
            sequence: 3,
            kind: .started(isLong: false),
            occurredAt: regularAt
        )
        state.consume(regular, breakStyle: .none)
        #expect(state.regularBreakStartedAt == nil)
        #expect(state.restRequestStartedAt == secondAt)

        state.consume(regular, breakStyle: .regular)
        #expect(state.restRequestStartedAt == nil)
        #expect(state.regularBreakStartedAt == regularAt)

        state.consume(
            FlowBreakInteraction(
                sequence: 4,
                kind: .started(isLong: true),
                occurredAt: longAt
            ),
            breakStyle: .long
        )
        #expect(state.regularBreakStartedAt == nil)
        #expect(state.longBreakStartedAt == longAt)

        state.clearConfirmedBreak()
        #expect(state.regularBreakStartedAt == nil)
        #expect(state.longBreakStartedAt == nil)
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

    @Test func emptyIdleVisualStateAdvancesTheProductionAnimationClockAtBoostedSpeed() {
        let state = FlowVisualState(
            blocks: 0,
            flowCount: 0,
            isActive: false,
            mode: .twentyFiveFive
        )
        let clock = FlowAnimationClock()
        let start = Date(timeIntervalSinceReferenceDate: 1_500)

        _ = clock.phase(at: start, visualState: state, isPaused: false)
        let phase = clock.phase(
            at: start.addingTimeInterval(8),
            visualState: state,
            isPaused: false
        )

        #expect(abs(phase - 0.6) < 0.0001)
        #expect(phase > 0.48)
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
        session.resolvedSegments = [first, second]

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
        #expect(snapshot.sessionGroups.count == 1)
        #expect(snapshot.sessionGroups[0].id == session.id)
        #expect(snapshot.sessionGroups[0].startedAt == session.startedAt)
        #expect(snapshot.sessionGroups[0].endedAt == session.endedAt)
        #expect(snapshot.sessionGroups[0].segments.map(\.id) == [first.id, second.id])
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
