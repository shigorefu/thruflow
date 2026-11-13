import Foundation
import Testing
@testable import ThruFlow

@MainActor struct TaskComposerSuggestionTests {
    @Test func quickInputChoicesFilterTypedContinuation() {
        #expect(TaskQuickInputOption.suggestions(for: "[").map(\.token) == ["[]", "[1b]", "[25m]"])
        #expect(TaskQuickInputOption.suggestions(for: "[2").map(\.token) == ["[25m]"])
        #expect(TaskQuickInputOption.suggestions(for: "[1B").map(\.token) == ["[1b]"])
        #expect(TaskQuickInputOption.suggestions(for: "[9").isEmpty)
        #expect(TaskQuickInputOption.suggestions(for: "!l").map(\.token) == ["!low", "!later"])
        #expect(TaskQuickInputOption.suggestions(for: "/to").map(\.token) == ["/today", "/tomorrow"])
        #expect(TaskQuickInputOption.suggestions(for: "@unknown").isEmpty)
    }

    @Test func suggestedTokensRemainRecognizedByParser() {
        let parser = TaskQuickInputParser()
        for prefix in ["[", "!", "/"] {
            for option in TaskQuickInputOption.suggestions(for: prefix) {
                let input = parser.replacingTrailingAutocompleteToken(in: "Read \(prefix)", with: option.token + " ")
                let result = parser.parse(input, areas: [], anchorDate: .now)
                #expect(result.title == "Read")
            }
        }
    }

    @Test func emptyAreaTokenUsesFiveMostRecentlyCreatedTasksWithoutDuplicates() {
        let areas = (0..<8).map { Area(name: "Area \($0)", type: .neutral) }
        let todos = areas.enumerated().map { index, area in
            Todo(title: "Task", area: area, createdAt: Date(timeIntervalSince1970: Double(index)))
        }
        todos[0].updatedAt = .distantFuture // Progress or editing must not change usage order.
        let duplicate = Todo(title: "Again", area: areas[7], createdAt: Date(timeIntervalSince1970: 20))
        let result = TaskComposerSuggestionBuilder().areas(query: "", areas: areas, todos: todos + [duplicate])
        #expect(result.map(\.id) == [7, 6, 5, 4, 3].map { areas[$0].id })
        #expect(TaskComposerSuggestionBuilder().areas(query: "area 1", areas: areas, todos: todos).map(\.id) == [areas[1].id])
    }

    @Test func archivedAreasAndDeletedTasksDoNotDistortFallbackOrder() {
        let a = Area(name: "Alpha", type: .neutral)
        let b = Area(name: "Beta", type: .neutral)
        let c = Area(name: "Archived", type: .neutral)
        c.archive()
        let deleted = Todo(title: "Deleted", area: b)
        deleted.softDelete()
        let result = TaskComposerSuggestionBuilder().areas(query: "", areas: [b, c, a], todos: [deleted])
        #expect(result.map(\.id) == [a.id, b.id])
    }

    @Test func hashtagSuggestionsAreUniqueAndCompleteThroughTheParser() {
        let todo = Todo(title: "Tagged", hashtags: ["Work", "work", "Study"], area: Area(name: "Study", type: .neutral))
        #expect(TaskComposerSuggestionBuilder().tags(query: "", todos: [todo]) == ["Work", "Study"])
        let parser = TaskQuickInputParser()
        #expect(parser.trailingAutocompleteToken(in: "Read #st") == "#st")
        let input = parser.replacingTrailingAutocompleteToken(in: "Read #st", with: "#Study ")
        let result = parser.parse(input, areas: [], anchorDate: .now)
        #expect(result.hashtags == ["Study"])
        #expect(result.title == "Read")
    }
}
