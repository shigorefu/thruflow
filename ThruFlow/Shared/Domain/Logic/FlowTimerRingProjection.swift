import Foundation

/// A focus-time range on the current timer, independent of wall-clock pauses.
struct FlowTimerRingSlice: Equatable {
    let start: Double
    let end: Double
    let colorHex: String
}

struct FlowTimerRingProjection {
    func slices(
        session: FlowSession,
        plannedSeconds: Int,
        focusedSeconds: Int
    ) -> [FlowTimerRingSlice] {
        guard plannedSeconds > 0, focusedSeconds > 0 else { return [] }
        // Preserve segment topology when modes shorten the visible arc.
        // The renderer clips after interpolating all boundaries together.
        let visibleSeconds = focusedSeconds
        let segments = session.resolvedSegments.sorted {
            if $0.startFocusSeconds != $1.startFocusSeconds {
                return $0.startFocusSeconds < $1.startFocusSeconds
            }
            if $0.startedAt != $1.startedAt { return $0.startedAt < $1.startedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        return segments.compactMap { segment in
            let start = min(max(segment.startFocusSeconds, 0), visibleSeconds)
            let end = min(max(segment.endFocusSeconds ?? focusedSeconds, start), visibleSeconds)
            guard end > start else { return nil }
            return FlowTimerRingSlice(
                start: Double(start) / Double(plannedSeconds),
                end: Double(end) / Double(plannedSeconds),
                colorHex: segment.area?.colorHex ?? session.area?.colorHex ?? "#007AFF"
            )
        }
    }
}
