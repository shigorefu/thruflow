#if os(macOS)
import SwiftUI

struct TasksDayList<Row: View>: View {
    @Environment(\.calendar) private var calendar

    let selectedDate: Date
    let selectedTodos: [Todo]
    let overdueTodos: [Todo]
    let groupOrder: [AreaType]
    let revealsRows: Bool
    let rowRevealDeadline: ContinuousClock.Instant?
    let onMoveAllToToday: ([Todo]) -> Void
    let onMoveTodos: (AreaType, IndexSet, Int, [Todo]) -> Void
    let onMoveGroups: (IndexSet, Int, [TasksTodoGroup]) -> Void
    @ViewBuilder let row: (Todo) -> Row

    var body: some View {
        let selectedGroups = TasksTodoGroup.groups(for: selectedTodos, order: groupOrder)
        let showsOverdueSection = calendar.isDateInToday(selectedDate) && !overdueTodos.isEmpty

        let visibleRows = (showsOverdueSection ? overdueTodos : []) + selectedGroups.flatMap(\.todos)
        let revealIndices = Dictionary(uniqueKeysWithValues: visibleRows.prefix(5).enumerated().map {
            ($0.element.id, $0.offset)
        })

        return List {
            if showsOverdueSection {
                Section {
                    ForEach(overdueTodos) { todo in
                        row(todo)
                            .featureRowReveal(
                                index: revealIndices[todo.id] ?? 5,
                                enabled: revealsRows,
                                eligibleUntil: rowRevealDeadline
                            )
                    }
                } header: {
                    TasksOverdueHeader(
                        count: overdueTodos.count,
                        onMoveAllToToday: { onMoveAllToToday(overdueTodos) }
                    )
                }
                .listSectionSeparator(.hidden)
            }

            if selectedGroups.isEmpty {
                if !showsOverdueSection {
                    EmptyRow(text: String(localized: "この日のタスクはありません。"))
                        .listRowSeparator(.hidden)
                }
            } else {
                ForEach(selectedGroups) { group in
                    Section {
                        ForEach(group.todos) { todo in
                            row(todo)
                                .featureRowReveal(
                                    index: revealIndices[todo.id] ?? 5,
                                    enabled: revealsRows,
                                    eligibleUntil: rowRevealDeadline
                                )
                        }
                        .onMove { source, destination in
                            onMoveTodos(
                                group.type,
                                source,
                                destination,
                                selectedTodos
                            )
                        }
                    } header: {
                        TasksSectionHeader(group: group)
                    }
                    .listSectionSeparator(.hidden)
                }
                .onMove { source, destination in
                    onMoveGroups(
                        source,
                        destination,
                        selectedGroups
                    )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

private struct EmptyRow: View {
    let text: String

    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
    }
}
#endif
