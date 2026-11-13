#if os(iOS)
import SwiftData
import SwiftUI

struct IOSHistoryRequest: Hashable {
    let interval: DateInterval?
    let calendar: Calendar
}

struct IOSHistoryRecords {
    let request: IOSHistoryRequest
    let sessions: [FlowSession]
    let breaks: [FlowBreak]
    let todos: [Todo]
}

struct IOSHistoryIndicatorWindow {
    let interval: DateInterval
    let range: HistoryCalendarRange
    let calendar: Calendar
}

struct IOSHistoryIndicators {
    let request: IOSHistoryRequest
    let sessions: [FlowSession]
}

struct IOSHistoryRecordsQuery: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [FlowSession]
    @Query private var breaks: [FlowBreak]
    @Query private var todos: [Todo]

    let request: IOSHistoryRequest
    let onUpdate: (Result<IOSHistoryRecords, Error>) -> Void

    init(request: IOSHistoryRequest, onUpdate: @escaping (Result<IOSHistoryRecords, Error>) -> Void) {
        self.request = request
        self.onUpdate = onUpdate
        let queries = HistoryPresentationQueries(interval: request.interval, calendar: request.calendar)
        _sessions = Query(queries.sessions)
        _breaks = Query(queries.breaks)
        _todos = Query(queries.todos)
    }

    var body: some View {
        let revisions = [
            sessions.map { IOSHistoryRecordRevision(id: $0.id, updatedAt: $0.updatedAt) },
            breaks.map { IOSHistoryRecordRevision(id: $0.id, updatedAt: $0.updatedAt) },
            todos.map { IOSHistoryRecordRevision(id: $0.id, updatedAt: $0.updatedAt) }
        ]
        let error = _sessions.fetchError ?? _breaks.fetchError ?? _todos.fetchError
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task(id: Revision(records: revisions, failed: error != nil)) {
                guard !Task.isCancelled else { return }
                do {
                    if let error { throw error }
                    let sessionIDs = Set(sessions.map(\.id))
                    let relatedIDs = Set(breaks.map(\.previousSessionID)).subtracting(sessionIDs)
                    let relatedSessions = relatedIDs.isEmpty ? [] : try modelContext.fetch(
                        HistoryPresentationQueries.relatedSessions(for: Array(relatedIDs))
                    )
                    onUpdate(.success(IOSHistoryRecords(
                        request: request,
                        sessions: sessions + relatedSessions,
                        breaks: breaks,
                        todos: HistoryPresentationQueries.includingLinkedTodos(todos, from: sessions, interval: request.interval)
                    )))
                } catch {
                    onUpdate(.failure(error))
                }
            }
    }

    private struct Revision: Hashable {
        let records: [[IOSHistoryRecordRevision]]
        let failed: Bool
    }
}

struct IOSHistoryIndicatorQuery: View {
    @Query private var sessions: [FlowSession]
    let onUpdate: ([FlowSession]) -> Void

    init(request: IOSHistoryRequest, onUpdate: @escaping ([FlowSession]) -> Void) {
        _sessions = Query(HistoryPresentationQueries(interval: request.interval, calendar: request.calendar).sessions)
        self.onUpdate = onUpdate
    }

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task(id: sessions.map { IOSHistoryRecordRevision(id: $0.id, updatedAt: $0.updatedAt) }) {
                guard !Task.isCancelled else { return }
                onUpdate(sessions)
            }
    }
}

private struct IOSHistoryRecordRevision: Hashable {
    let id: UUID
    let updatedAt: Date
}
#endif
