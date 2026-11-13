import Foundation

struct TaskTitleSuggestion: Equatable, Identifiable {
    let id: String
    let title: String
    let usageCount: Int
    let lastUsedAt: Date
}

/// Builds local task-title autocomplete suggestions without reusing Todo identity.
struct TaskTitleSuggestionBuilder {
    func suggestions(
        query: String,
        todos: [Todo],
        excludingTodoID: UUID? = nil,
        limit: Int = 5
    ) -> [TaskTitleSuggestion] {
        let displayQuery = normalizedDisplayTitle(query)
        let normalizedQuery = searchKey(displayQuery)
        guard !normalizedQuery.isEmpty, limit > 0 else { return [] }

        var candidates: [String: Candidate] = [:]

        for todo in todos where !todo.isDeleted && todo.id != excludingTodoID {
            let displayTitle = normalizedDisplayTitle(todo.title)
            let key = searchKey(displayTitle)
            guard !key.isEmpty,
                  key != normalizedQuery,
                  key.contains(normalizedQuery) else {
                continue
            }

            let usedAt = max(todo.completedAt ?? .distantPast, todo.updatedAt)
            if var candidate = candidates[key] {
                candidate.usageCount += 1
                if usedAt > candidate.lastUsedAt {
                    candidate.title = displayTitle
                    candidate.lastUsedAt = usedAt
                }
                candidates[key] = candidate
            } else {
                candidates[key] = Candidate(
                    title: displayTitle,
                    usageCount: 1,
                    lastUsedAt: usedAt
                )
            }
        }

        return candidates
            .map { key, candidate in
                TaskTitleSuggestion(
                    id: key,
                    title: candidate.title,
                    usageCount: candidate.usageCount,
                    lastUsedAt: candidate.lastUsedAt
                )
            }
            .sorted { lhs, rhs in
                let lhsPrefix = searchKey(lhs.title).hasPrefix(normalizedQuery)
                let rhsPrefix = searchKey(rhs.title).hasPrefix(normalizedQuery)
                if lhsPrefix != rhsPrefix { return lhsPrefix }
                if lhs.usageCount != rhs.usageCount { return lhs.usageCount > rhs.usageCount }
                if lhs.lastUsedAt != rhs.lastUsedAt { return lhs.lastUsedAt > rhs.lastUsedAt }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }

    private func normalizedDisplayTitle(_ value: String) -> String {
        value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func searchKey(_ value: String) -> String {
        normalizedDisplayTitle(value).folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private struct Candidate {
        var title: String
        var usageCount: Int
        var lastUsedAt: Date
    }
}
