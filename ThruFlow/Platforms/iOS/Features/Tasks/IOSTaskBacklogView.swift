#if os(iOS)
import SwiftUI

enum IOSBacklogMode: String, Identifiable {
    case overdue
    case unscheduled
    var id: String { rawValue }
}

struct IOSBacklogView: View {
    @Environment(\.dismiss) private var dismiss
    let mode: IOSBacklogMode
    let todos: [Todo]
    let edit: (Todo) -> Void

    var body: some View {
        List(todos) { todo in
            IOSTaskRow(todo: todo) { edit(todo) }
        }
        .overlay {
            if todos.isEmpty {
                ContentUnavailableView(
                    mode == .overdue ? String(localized: "やり残し") : String(localized: "日付なし"),
                    systemImage: mode == .overdue ? "checkmark.circle" : "tray"
                )
            }
        }
        .iosCenteredNavigationTitle(
            mode == .overdue ? String(localized: "やり残し") : String(localized: "日付なし")
        )
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "完了")) { dismiss() }
            }
        }
    }
}
#endif
