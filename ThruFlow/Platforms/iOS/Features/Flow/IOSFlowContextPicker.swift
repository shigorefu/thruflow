import SwiftUI

struct IOSFlowContextPicker: View {
    @Environment(\.dismiss) private var dismiss

    let todos: [Todo]
    let directions: [Direction]
    let selectedTodoID: UUID?
    let selectedDirectionID: UUID?
    let select: (Direction, Todo?) -> Void

    var body: some View {
        List {
            if !todos.isEmpty {
                Section(String(localized: "タスク")) {
                    ForEach(todos) { todo in
                        if let direction = todo.direction {
                            Button {
                                select(direction, todo)
                            } label: {
                                row(
                                    emoji: direction.symbolName,
                                    title: TodoDisplay.title(for: todo),
                                    subtitle: direction.name,
                                    isSelected: selectedTodoID == todo.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Section(String(localized: "タスクなし")) {
                ForEach(directions) { direction in
                    Button {
                        select(direction, nil)
                    } label: {
                        row(
                            emoji: direction.symbolName,
                            title: direction.name,
                            subtitle: direction.type.displayName,
                            isSelected: selectedTodoID == nil && selectedDirectionID == direction.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(String(localized: "Flowタスク"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "閉じる")) { dismiss() }
            }
        }
    }

    private func row(emoji: String, title: String, subtitle: String, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Text(emoji).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }
}
