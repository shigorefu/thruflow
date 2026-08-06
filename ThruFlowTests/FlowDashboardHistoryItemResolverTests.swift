import Foundation
import Testing
@testable import ThruFlow

@MainActor
struct FlowDashboardHistoryItemResolverTests {
    @Test func resolvesExactTaskSwitchSegmentsAndCompletedBreaksButRejectsActiveRecords() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let day = Date(timeIntervalSince1970: 1_786_060_800)
        let writing = Direction(name: "執筆", type: .neutral, colorHex: "#0A84FF")
        let review = Direction(name: "確認", type: .neutral, colorHex: "#FF9F0A")
        let writingTodo = Todo(title: "本文", direction: writing)
        let reviewTodo = Todo(title: "校正", direction: review)
        let start = day.addingTimeInterval(9 * 3_600)
        let session = FlowSession(
            direction: writing,
            todo: writingTodo,
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
        let writingSegment = FlowSegment(
            session: session,
            direction: writing,
            todo: writingTodo,
            startedAt: start,
            startFocusSeconds: 0
        )
        writingSegment.close(
            at: start.addingTimeInterval(15 * 60),
            totalFocusSeconds: 15 * 60
        )
        let reviewSegment = FlowSegment(
            session: session,
            direction: review,
            todo: reviewTodo,
            startedAt: start.addingTimeInterval(15 * 60),
            startFocusSeconds: 15 * 60
        )
        reviewSegment.close(
            at: start.addingTimeInterval(25 * 60),
            totalFocusSeconds: 25 * 60
        )
        session.resolvedSegments = [writingSegment, reviewSegment]

        let rest = FlowBreak(
            seriesID: try #require(session.seriesID),
            previousSessionID: session.id,
            startedAt: start.addingTimeInterval(25 * 60),
            timerStoppedAt: start.addingTimeInterval(30 * 60),
            plannedDurationSeconds: 5 * 60
        )
        let dashboard = FlowDashboardBuilder(calendar: calendar).build(
            date: day.addingTimeInterval(12 * 3_600),
            sessions: [session],
            breaks: [rest]
        )
        let history = HistoryCalendarBuilder(calendar: calendar).build(
            interval: HistoryCalendarRange.day.interval(containing: day, calendar: calendar),
            sessions: [session],
            breaks: [rest],
            referenceDate: day.addingTimeInterval(12 * 3_600)
        )
        let resolver = FlowDashboardHistoryItemResolver()
        let dashboardWriting = try #require(dashboard.segments.first { $0.id == writingSegment.id })
        let dashboardReview = try #require(dashboard.segments.first { $0.id == reviewSegment.id })
        let dashboardBreak = try #require(dashboard.breaks.first)

        #expect(resolver.item(for: dashboardWriting, in: history.items)?.flowSegment?.id == writingSegment.id)
        #expect(resolver.item(for: dashboardReview, in: history.items)?.flowSegment?.id == reviewSegment.id)
        #expect(resolver.item(for: dashboardBreak, in: history.items)?.flowBreak?.id == rest.id)

        session.status = .awaitingResult
        #expect(resolver.item(for: dashboardWriting, in: history.items) == nil)

        let activeBreak = FlowDashboardBreak(
            id: dashboardBreak.id,
            storedBreak: dashboardBreak.storedBreak,
            seriesID: dashboardBreak.seriesID,
            startedAt: dashboardBreak.startedAt,
            endedAt: dashboardBreak.endedAt,
            plannedDurationSeconds: dashboardBreak.plannedDurationSeconds,
            isLongBreak: dashboardBreak.isLongBreak,
            isActive: true
        )
        #expect(resolver.item(for: activeBreak, in: history.items) == nil)
    }
}
