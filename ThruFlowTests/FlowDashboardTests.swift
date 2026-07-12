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

    private func makeSession(
        direction: Direction,
        start: Date,
        duration: Int,
        status: FlowSessionStatus = .completed
    ) -> FlowSession {
        FlowSession(
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
