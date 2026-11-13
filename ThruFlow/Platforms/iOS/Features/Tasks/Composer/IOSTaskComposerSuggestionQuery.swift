#if os(iOS)
import SwiftData
import SwiftUI

struct IOSTaskComposerSuggestionQuery: View {
    @Query(sort: \Todo.updatedAt, order: .reverse) private var todos: [Todo]
    let onUpdate: ([Todo]) -> Void

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task(id: todos.map { Revision(id: $0.id, updatedAt: $0.updatedAt) }) {
                guard !Task.isCancelled else { return }
                onUpdate(todos)
            }
    }

    private struct Revision: Hashable {
        let id: UUID
        let updatedAt: Date
    }
}
#endif
