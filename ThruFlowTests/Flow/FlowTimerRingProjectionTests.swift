import Foundation
import Testing
@testable import ThruFlow

@MainActor
struct FlowTimerRingProjectionTests {
    @Test func switchingModePreservesColorTopologyBeyondSprintBoundary() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let blue = Area(name: "Study", type: .neutral, colorHex: "#007AFF")
        let green = Area(name: "Work", type: .neutral, colorHex: "#34C759")
        let session = FlowSession(
            area: green, mode: .twentyFiveFive, startedAt: start,
            plannedEndAt: start.addingTimeInterval(1500),
            plannedFocusDurationSeconds: 1500, plannedBreakDurationSeconds: 300
        )
        let first = FlowSegment(session: session, area: blue, todo: nil, startedAt: start, startFocusSeconds: 0)
        first.close(at: start.addingTimeInterval(800), totalFocusSeconds: 800)
        let second = FlowSegment(session: session, area: green, todo: nil, startedAt: start.addingTimeInterval(800), startFocusSeconds: 800)
        session.resolvedSegments = [second, first]
        let projection = FlowTimerRingProjection()
        for mode in [FlowMode.sprint, .twentyFiveFive, .fiftyTen] {
            let duration = Double(mode.initialFocusDurationSeconds)
            let slices = projection.slices(session: session, plannedSeconds: Int(duration), focusedSeconds: 1000)
            #expect(slices == [
                FlowTimerRingSlice(start: 0, end: 800 / duration, colorHex: blue.colorHex),
                FlowTimerRingSlice(start: 800 / duration, end: 1000 / duration, colorHex: green.colorHex)
            ])
            // The renderer can animate both colors continuously even when the
            // destination duration puts an entire segment beyond the visible arc.
            #expect(slices.count == 2)
        }
    }
}
