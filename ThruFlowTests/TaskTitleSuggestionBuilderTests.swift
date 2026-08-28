import Foundation
import Testing
@testable import ThruFlow

struct TaskTitleSuggestionBuilderTests {
    private let builder = TaskTitleSuggestionBuilder()

    @Test func ranksPrefixMatchesBeforeSubstringMatches() {
        let direction = Direction(name: "日本語", type: .neutral)
        let recentSubstring = Todo(
            title: "毎日日本語",
            direction: direction,
            updatedAt: Date(timeIntervalSince1970: 300)
        )
        let olderPrefix = Todo(
            title: "日本へ行く",
            direction: direction,
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        let suggestions = builder.suggestions(
            query: "日",
            todos: [recentSubstring, olderPrefix]
        )

        #expect(suggestions.map { $0.title } == ["日本へ行く", "毎日日本語"])
    }

    @Test func deduplicatesTitlesAndRanksFrequentUseFirst() {
        let direction = Direction(name: "学習", type: .neutral)
        let japaneseOlder = Todo(
            title: "日本語",
            direction: direction,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let japaneseNewer = Todo(
            title: "  日本語  ",
            direction: direction,
            updatedAt: Date(timeIntervalSince1970: 300)
        )
        let japanTrip = Todo(
            title: "日本へ",
            direction: direction,
            updatedAt: Date(timeIntervalSince1970: 400)
        )

        let suggestions = builder.suggestions(
            query: "日",
            todos: [japanTrip, japaneseOlder, japaneseNewer]
        )

        #expect(suggestions.map { $0.title } == ["日本語", "日本へ"])
        #expect(suggestions.first?.usageCount == 2)
    }

    @Test func ignoresDeletedEmptyExactAndExcludedTasks() {
        let direction = Direction(name: "学習", type: .neutral)
        let current = Todo(title: "日本語会話", direction: direction)
        let exact = Todo(title: "日", direction: direction)
        let empty = Todo(title: "   ", direction: direction)
        let deleted = Todo(title: "日本史", direction: direction, deletedAt: .now)
        let match = Todo(title: "日本へ", direction: direction)

        let suggestions = builder.suggestions(
            query: "日",
            todos: [current, exact, empty, deleted, match],
            excludingTodoID: current.id
        )

        #expect(suggestions.map { $0.title } == ["日本へ"])
    }

    @Test func matchesCaseWidthAndDiacriticsAndHonorsLimit() {
        let direction = Direction(name: "Language", type: .neutral)
        let todos = [
            Todo(title: "Résumé practice", direction: direction),
            Todo(title: "RESUME review", direction: direction),
            Todo(title: "Resume notes", direction: direction),
        ]

        let suggestions = builder.suggestions(query: "resume", todos: todos, limit: 2)

        #expect(suggestions.count == 2)
        #expect(suggestions.allSatisfy { $0.title.lowercased().contains("r") })
    }
}
