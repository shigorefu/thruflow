#if os(macOS)
import SwiftData
import SwiftUI

struct MacHistoryRequest: Hashable {
    let period: DateInterval?
    let miniCalendar: DateInterval?
    let calendar: Calendar

    var sessionInterval: DateInterval? {
        guard let period else { return nil }
        guard let miniCalendar else { return period }
        return DateInterval(start: min(period.start, miniCalendar.start), end: max(period.end, miniCalendar.end))
    }
}

struct MacHistoryCacheEntry {
    let request: MacHistoryRequest
    let data: MacHistoryData
}

struct MacHistoryData {
    let sessions: [FlowSession]
    let breaks: [FlowBreak]
    let todos: [Todo]
    let areas: [Area]
}

struct MacHistoryDataSource: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [FlowSession]
    @Query private var breaks: [FlowBreak]
    @Query private var todos: [Todo]
    @Query(sort: \Area.sortIndex) private var areas: [Area]

    let request: MacHistoryRequest
    let onUpdate: (Result<MacHistoryData, Error>) -> Void

    init(request: MacHistoryRequest, onUpdate: @escaping (Result<MacHistoryData, Error>) -> Void) {
        self.request = request
        self.onUpdate = onUpdate
        let periodQueries = HistoryPresentationQueries(interval: request.period, calendar: request.calendar)
        let sessionQueries = HistoryPresentationQueries(interval: request.sessionInterval, calendar: request.calendar)
        _sessions = Query(sessionQueries.sessions)
        _breaks = Query(periodQueries.breaks)
        _todos = Query(periodQueries.todos)
    }

    var body: some View {
        let revision = Revision(
            sessions: sessions.map { RecordVersion(id: $0.id, updatedAt: $0.updatedAt) },
            breaks: breaks.map { RecordVersion(id: $0.id, updatedAt: $0.updatedAt) },
            todos: todos.map { RecordVersion(id: $0.id, updatedAt: $0.updatedAt) },
            areas: areas.map { RecordVersion(id: $0.id, updatedAt: $0.updatedAt) },
            failed: loadError != nil
        )

        Color.clear
            .onChange(of: revision, initial: true) { _, _ in
                onUpdate(Result { try readData() })
            }
    }

    private var loadError: Error? {
        _sessions.fetchError ?? _breaks.fetchError ?? _todos.fetchError ?? _areas.fetchError
    }

    private func readData() throws -> MacHistoryData {
        if let loadError { throw loadError }

        let loadedSessionIDs = Set(sessions.map(\.id))
        let missingSessionIDs = Set(breaks.map(\.previousSessionID)).subtracting(loadedSessionIDs)
        let relatedSessions = missingSessionIDs.isEmpty
            ? []
            : try modelContext.fetch(HistoryPresentationQueries.relatedSessions(for: Array(missingSessionIDs)))

        return MacHistoryData(
            sessions: sessions + relatedSessions,
            breaks: breaks,
            todos: HistoryPresentationQueries.includingLinkedTodos(
                todos,
                from: sessions,
                interval: request.period
            ),
            areas: areas
        )
    }

    private struct RecordVersion: Equatable {
        let id: UUID
        let updatedAt: Date
    }

    private struct Revision: Equatable {
        let sessions: [RecordVersion]
        let breaks: [RecordVersion]
        let todos: [RecordVersion]
        let areas: [RecordVersion]
        let failed: Bool
    }
}
#endif
