import Foundation

@MainActor
struct DatabaseSearchQuery {
    let text: String

    var normalizedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isActive: Bool {
        !normalizedText.isEmpty
    }

    func matchesTask(_ todo: Todo) -> Bool {
        matches(taskCandidates(for: todo, includesNotes: false))
    }

    func matchesHistory(_ todo: Todo) -> Bool {
        matches(taskCandidates(for: todo, includesNotes: true))
    }

    func matchesHistory(_ session: FlowSession) -> Bool {
        guard isActive else { return true }

        if let todo = session.todo, matchesHistory(todo) {
            return true
        }
        if matches(directionCandidates(for: session.direction)) {
            return true
        }

        for segment in session.resolvedSegments {
            if let todo = segment.todo, matchesHistory(todo) {
                return true
            }
            if matches(directionCandidates(for: segment.direction)) {
                return true
            }
        }

        return matches([session.intent, session.result ?? ""])
    }

    func matchesHistory(_ item: HistoryCalendarItem) -> Bool {
        guard isActive else { return true }

        if matches([item.title, item.subtitle, item.symbol]) {
            return true
        }
        if let todo = item.todo, matchesHistory(todo) {
            return true
        }
        if let session = item.session, matchesHistory(session) {
            return true
        }
        return false
    }

    private func taskCandidates(for todo: Todo, includesNotes: Bool) -> [String] {
        var candidates = [
            TodoDisplay.title(for: todo),
            todo.direction?.name ?? "",
            todo.direction?.symbolName ?? ""
        ] + todo.hashtags.flatMap { [$0, "#\($0)"] }

        if includesNotes {
            candidates.append(todo.notes ?? "")
        }
        return candidates
    }

    private func directionCandidates(for direction: Direction?) -> [String] {
        [direction?.name ?? "", direction?.symbolName ?? ""]
    }

    private func matches(_ candidates: [String]) -> Bool {
        let query = normalizedText
        guard !query.isEmpty else { return true }
        return candidates.contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

@MainActor
struct DatabaseTaskSearchSection: Identifiable {
    let date: Date?
    let todos: [Todo]

    var id: String {
        date.map { "date-\($0.timeIntervalSinceReferenceDate)" } ?? "unscheduled"
    }
}

@MainActor
struct DatabaseSearchBuilder {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func taskSections(
        query: String,
        todos: [Todo],
        filter: TaskCalendarFilter
    ) -> [DatabaseTaskSearchSection] {
        let search = DatabaseSearchQuery(text: query)
        guard search.isActive else { return [] }

        let matches = todos
            .filter { !$0.isArchived && !$0.isDeleted }
            .filter(filter.includes)
            .filter(search.matchesTask)

        let grouped = Dictionary(grouping: matches) { todo -> Date? in
            todo.scheduledDate.map(calendar.startOfDay(for:))
        }

        return grouped
            .map { date, todos in
                DatabaseTaskSearchSection(
                    date: date,
                    todos: todos.sorted(by: taskSort)
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.date, rhs.date) {
                case let (lhsDate?, rhsDate?):
                    lhsDate > rhsDate
                case (.some, .none):
                    true
                case (.none, .some):
                    false
                case (.none, .none):
                    false
                }
            }
    }

    func historyCalendarItems(
        query: String,
        sessions: [FlowSession],
        breaks: [FlowBreak],
        referenceDate: Date = .now
    ) -> [HistoryCalendarItem] {
        let search = DatabaseSearchQuery(text: query)
        guard search.isActive else { return [] }

        let interval = historyInterval(
            sessions: sessions,
            breaks: breaks,
            todos: [],
            referenceDate: referenceDate
        )
        return HistoryCalendarBuilder(calendar: calendar)
            .build(
                interval: interval,
                sessions: sessions,
                breaks: breaks,
                referenceDate: referenceDate
            )
            .items
            .filter(search.matchesHistory)
            .sorted { lhs, rhs in
                if lhs.startedAt == rhs.startedAt {
                    return lhs.id < rhs.id
                }
                return lhs.startedAt > rhs.startedAt
            }
    }

    func historySnapshot(
        query: String,
        sessions: [FlowSession],
        todos: [Todo],
        referenceDate: Date = .now
    ) -> DayHistorySnapshot {
        let search = DatabaseSearchQuery(text: query)
        guard search.isActive else {
            return DayHistoryBuilder(calendar: calendar).build(
                interval: emptyInterval(referenceDate: referenceDate),
                sessions: [],
                todos: []
            )
        }

        let matchingSessions = sessions.filter(search.matchesHistory)
        let linkedTodoIDs = Set(matchingSessions.flatMap { session in
            [session.todo?.id] + session.resolvedSegments.map { $0.todo?.id }
        }.compactMap { $0 })
        let matchingTodos = todos.filter { todo in
            linkedTodoIDs.contains(todo.id) || search.matchesHistory(todo)
        }
        let interval = historyInterval(
            sessions: matchingSessions,
            breaks: [],
            todos: matchingTodos,
            referenceDate: referenceDate
        )

        return DayHistoryBuilder(calendar: calendar).build(
            interval: interval,
            sessions: matchingSessions,
            todos: matchingTodos
        )
    }

    private func historyInterval(
        sessions: [FlowSession],
        breaks: [FlowBreak],
        todos: [Todo],
        referenceDate: Date
    ) -> DateInterval {
        var dates: [Date] = []

        for session in sessions {
            dates.append(session.startedAt)
            dates.append(session.endedAt ?? session.plannedEndAt)
            for segment in session.resolvedSegments {
                dates.append(segment.startedAt)
                dates.append(segment.endedAt ?? segment.startedAt)
            }
        }
        for flowBreak in breaks where !flowBreak.isDeleted {
            dates.append(flowBreak.startedAt)
            dates.append(flowBreak.resolvedEndAt(referenceDate: referenceDate))
        }
        for todo in todos where !todo.isDeleted {
            dates.append(todo.createdAt)
            dates.append(todo.updatedAt)
            if let scheduledDate = todo.scheduledDate {
                dates.append(scheduledDate)
            }
            if let completedAt = todo.completedAt {
                dates.append(completedAt)
            }
        }

        guard let first = dates.min(), let last = dates.max() else {
            return emptyInterval(referenceDate: referenceDate)
        }
        return DateInterval(
            start: first,
            end: max(first.addingTimeInterval(1), last.addingTimeInterval(1))
        )
    }

    private func emptyInterval(referenceDate: Date) -> DateInterval {
        DateInterval(start: referenceDate, duration: 1)
    }

    private func taskSort(_ lhs: Todo, _ rhs: Todo) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted
        }
        if lhs.priority != rhs.priority {
            return priorityRank(lhs.priority) < priorityRank(rhs.priority)
        }
        return lhs.sortIndex < rhs.sortIndex
    }

    private func priorityRank(_ priority: TodoPriority) -> Int {
        switch priority {
        case .high: 0
        case .medium: 1
        case .low: 2
        }
    }
}
