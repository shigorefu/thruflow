import Foundation

@MainActor
struct TaskComposerSuggestionBuilder {
    func areas(query: String, areas: [Area], todos: [Todo]) -> [Area] {
        var lastUsed: [UUID: Date] = [:]
        for todo in todos where !todo.isDeleted {
            guard let id = todo.area?.id else { continue }
            lastUsed[id] = max(lastUsed[id] ?? .distantPast, todo.createdAt)
        }
        let matches = areas.filter {
            !$0.isArchived && !DefaultAreas.isTaskInbox($0) &&
                (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))
        }.sorted {
            let lhs = lastUsed[$0.id] ?? .distantPast
            let rhs = lastUsed[$1.id] ?? .distantPast
            if lhs != rhs { return lhs > rhs }
            let order = $0.name.localizedStandardCompare($1.name)
            if order != .orderedSame { return order == .orderedAscending }
            return $0.id.uuidString < $1.id.uuidString
        }
        return Array(matches.prefix(query.isEmpty ? 5 : 6))
    }

    func tags(query: String, todos: [Todo]) -> [String] {
        var seen = Set<String>()
        return Array(todos.filter { !$0.isDeleted }.sorted { $0.createdAt > $1.createdAt }
            .flatMap(\.hashtags).filter {
                (query.isEmpty || $0.localizedCaseInsensitiveContains(query)) &&
                    seen.insert($0.lowercased()).inserted
            }.prefix(5))
    }
}
