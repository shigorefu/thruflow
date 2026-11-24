#if os(macOS)
import SwiftUI

struct TasksBacklogInspector<Row: View>: View {
    let backlogInspectorTitle: String
    let backlogInspectorSystemImage: String
    let inspectorTodos: [Todo]
    let onMoveAllToToday: ([Todo]) -> Void
    let onMoveToToday: (Todo) -> Void
    let onClose: () -> Void
    @ViewBuilder let row: (Todo) -> Row

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Label(backlogInspectorTitle, systemImage: backlogInspectorSystemImage)
                    .font(.headline)

                Text("\(inspectorTodos.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                if !inspectorTodos.isEmpty {
                    Button(String(localized: "すべて今日へ")) {
                        onMoveAllToToday(inspectorTodos)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(String(localized: "「\(backlogInspectorTitle)」パネルを閉じる"))
            }
            .padding(16)

            Divider()

            if inspectorTodos.isEmpty {
                ContentUnavailableView(
                    backlogInspectorTitle,
                    systemImage: backlogInspectorSystemImage
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(inspectorTodos) { todo in
                        unscheduledTodoRow(todo)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func unscheduledTodoRow(_ todo: Todo) -> some View {
        HStack(spacing: 8) {
            row(todo)

            Button {
                onMoveToToday(todo)
            } label: {
                Image(systemName: "calendar.badge.plus")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(String(localized: "今日へ移動"))
            .accessibilityLabel(String(localized: "\(TodoDisplay.taskTitle(for: todo))を今日へ移動"))
        }
    }
}
#endif
