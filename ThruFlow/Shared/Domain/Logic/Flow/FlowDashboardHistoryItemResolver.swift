import Foundation

@MainActor
struct FlowDashboardHistoryItemResolver {
    func item(
        for segment: FlowDashboardSegment,
        in items: [HistoryCalendarItem]
    ) -> HistoryCalendarItem? {
        guard segment.session.status == .completed else { return nil }
        let recordID = segment.storedSegment?.id ?? segment.session.id
        return items.first { $0.id == "flow-\(recordID.uuidString)" }
    }

    func item(
        for flowBreak: FlowDashboardBreak,
        in items: [HistoryCalendarItem]
    ) -> HistoryCalendarItem? {
        guard !flowBreak.isActive else { return nil }
        return items.first { $0.id == "rest-\(flowBreak.storedBreak.id.uuidString)" }
    }
}
