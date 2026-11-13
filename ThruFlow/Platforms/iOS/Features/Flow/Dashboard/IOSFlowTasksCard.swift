#if os(iOS)
import SwiftUI

struct IOSFlowTasksCard: View {
    @Binding var taskFilter: IOSDashboardTaskFilter

    let isLoading: Bool
    let todos: [Todo]
    let onAddTask: () -> Void
    let onOpenTasks: () -> Void
    let onEditTodo: (Todo) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(String(localized: "今日のタスク"), systemImage: "checklist")
                    .font(.headline)
                Spacer()
                Button(action: onAddTask) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "タスクを追加"))
                Button {
                    onOpenTasks()
                } label: {
                    Image(systemName: "arrow.up.right")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "対象タスク"))
            }

            Picker(String(localized: "表示"), selection: $taskFilter) {
                ForEach(IOSDashboardTaskFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 10) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, minHeight: 90)
                } else if todos.isEmpty {
                    ContentUnavailableView(
                        String(localized: "今日の項目はありません"),
                        systemImage: "checkmark.circle"
                    )
                } else {
                    ForEach(todos) { todo in
                        IOSTaskRow(todo: todo, showsContextSubtitle: true) {
                            onEditTodo(todo)
                        }
                        if todo.id != todos.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .productContentFade(on: !isLoading)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
    }
}

enum IOSDashboardTaskFilter: String, CaseIterable, Identifiable {
    case task
    case habit
    case nice

    var id: String { rawValue }

    var title: String {
        switch self {
        case .task: String(localized: "タスク")
        case .habit: String(localized: "習慣一覧")
        case .nice: String(localized: "ナイス")
        }
    }
}
#endif
