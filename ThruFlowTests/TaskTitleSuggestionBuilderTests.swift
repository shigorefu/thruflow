import Foundation
import Testing
@testable import ThruFlow

struct TaskTitleSuggestionBuilderTests {
    private let builder = TaskTitleSuggestionBuilder()

    @Test func ranksPrefixMatchesBeforeSubstringMatches() {
        let area = Area(name: "日本語", type: .neutral)
        let recentSubstring = Todo(
            title: "毎日日本語",
            area: area,
            updatedAt: Date(timeIntervalSince1970: 300)
        )
        let olderPrefix = Todo(
            title: "日本へ行く",
            area: area,
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        let suggestions = builder.suggestions(
            query: "日",
            todos: [recentSubstring, olderPrefix]
        )

        #expect(suggestions.map { $0.title } == ["日本へ行く", "毎日日本語"])
    }

    @Test func deduplicatesTitlesAndRanksFrequentUseFirst() {
        let area = Area(name: "学習", type: .neutral)
        let japaneseOlder = Todo(
            title: "日本語",
            area: area,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let japaneseNewer = Todo(
            title: "  日本語  ",
            area: area,
            updatedAt: Date(timeIntervalSince1970: 300)
        )
        let japanTrip = Todo(
            title: "日本へ",
            area: area,
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
        let area = Area(name: "学習", type: .neutral)
        let current = Todo(title: "日本語会話", area: area)
        let exact = Todo(title: "日", area: area)
        let empty = Todo(title: "   ", area: area)
        let deleted = Todo(title: "日本史", area: area, deletedAt: .now)
        let match = Todo(title: "日本へ", area: area)

        let suggestions = builder.suggestions(
            query: "日",
            todos: [current, exact, empty, deleted, match],
            excludingTodoID: current.id
        )

        #expect(suggestions.map { $0.title } == ["日本へ"])
    }

    @Test func matchesCaseWidthAndDiacriticsAndHonorsLimit() {
        let area = Area(name: "Language", type: .neutral)
        let todos = [
            Todo(title: "Résumé practice", area: area),
            Todo(title: "RESUME review", area: area),
            Todo(title: "Resume notes", area: area),
        ]

        let suggestions = builder.suggestions(query: "resume", todos: todos, limit: 2)

        #expect(suggestions.count == 2)
        #expect(suggestions.allSatisfy { $0.title.lowercased().contains("r") })
    }
}
