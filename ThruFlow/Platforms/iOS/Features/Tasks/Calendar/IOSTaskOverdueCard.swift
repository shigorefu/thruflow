#if os(iOS)
import SwiftUI

struct IOSTaskOverdueCard: View {
    let todos: [Todo]
    let revealsInitialRows: Bool
    let onMoveToToday: ([Todo]) -> Void
    let onEditTodo: (Todo) -> Void

    @ViewBuilder
    var body: some View {
        if !todos.isEmpty {
            LazyVStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(.red)
                        .frame(width: 7, height: 7)

                    Text(String(localized: "やり残し"))
                        .font(.caption.weight(.semibold))

                    Text("\(todos.count)")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.14), in: Capsule())

                    Spacer(minLength: 0)

                    Button(String(localized: "すべて今日へ")) {
                        onMoveToToday(todos)
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }

                IOSTaskCalendarRows(
                    todos: todos,
                    firstRowIndex: 0,
                    revealsInitialRows: revealsInitialRows,
                    onEditTodo: onEditTodo
                )
            }
            .padding(14)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
#endif
