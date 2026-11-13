#if os(iOS)
import SwiftData
import SwiftUI

struct IOSFlowRecentRecords {
    let sessions: [FlowSession]
    let breaks: [FlowBreak]
    let revision: IOSFlowRecentRecordsRevision
}

struct IOSFlowRecentRecordsRevision: Hashable {
    let sessionCount: Int
    let latestSessionUpdate: Date?
    let breakCount: Int
    let latestBreakUpdate: Date?
}

struct IOSFlowRecentRecordsQuery: View {
    @Query private var sessions: [FlowSession]
    @Query private var breaks: [FlowBreak]

    let onUpdate: (IOSFlowRecentRecords) -> Void

    init(onUpdate: @escaping (IOSFlowRecentRecords) -> Void) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -16, to: .now) ?? .distantPast
        _sessions = Query(
            filter: #Predicate<FlowSession> { $0.startedAt >= cutoff },
            sort: \FlowSession.updatedAt,
            order: .reverse
        )
        _breaks = Query(
            filter: #Predicate<FlowBreak> { $0.startedAt >= cutoff },
            sort: \FlowBreak.updatedAt,
            order: .reverse
        )
        self.onUpdate = onUpdate
    }

    var body: some View {
        let revision = IOSFlowRecentRecordsRevision(
            sessionCount: sessions.count,
            latestSessionUpdate: sessions.first?.updatedAt,
            breakCount: breaks.count,
            latestBreakUpdate: breaks.first?.updatedAt
        )
        Color.clear
            .allowsHitTesting(false)
            .task(id: revision) {
                guard !Task.isCancelled else { return }
                onUpdate(IOSFlowRecentRecords(sessions: sessions, breaks: breaks, revision: revision))
            }
    }
}
#endif
