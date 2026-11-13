#if os(macOS)
import SwiftData
import SwiftUI

struct DashboardTodoColumn: View {
    let title: String
    let systemImage: String
    let todos: [Todo]
    let scrollsRows: Bool
    var isLoading = false
    var showsPriority = false
    let progressText: (Todo) -> String
    let onToggle: (Todo) -> Void
    let onOpen: (Todo) -> Void
    var onOpenSection: (() -> Void)?
    var addControl: AnyView?
    @State private var moveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let onOpenSection {
                    Button(action: onOpenSection) {
                        Label(title, systemImage: systemImage).font(.headline)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("flow.openTasks.\(systemImage)")
                } else {
                    Label(title, systemImage: systemImage).font(.headline)
                }
                Spacer()
                if !isLoading {
                    Text("\(todos.filter { !$0.isCompleted }.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                if let addControl {
                    addControl
                }
            }
            .frame(minHeight: 22)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, minHeight: 70)
            } else if scrollsRows && !todos.isEmpty {
                ScrollView {
                    todoList
                }
            } else {
                todoList
            }
        }
        .alert(String(localized: "移動できません"), isPresented: Binding(
            get: { moveError != nil }, set: { if !$0 { moveError = nil } }
        )) {
            Button(String(localized: "OK"), role: .cancel) { moveError = nil }
        } message: {
            Text(moveError ?? "")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }

    @ViewBuilder
    private var todoList: some View {
        if todos.isEmpty {
            Text(String(localized: "今日の項目はありません"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 70, alignment: .center)
        } else {
            VStack(spacing: 0) {
                ForEach(todos.prefix(6)) { todo in
                    todoRow(todo)
                        .contextMenu {
                            MacTaskContextMenu(todo: todo, onEdit: { onOpen(todo) }, onError: { moveError = $0 })
                        }

                    if todo.id != todos.prefix(6).last?.id {
                        Divider().opacity(0.5)
                    }
                }
            }
        }
    }

    private func todoRow(_ todo: Todo) -> some View {
        HStack(spacing: 10) {
            TodoProgressControl(todo: todo) {
                onToggle(todo)
            }

            Button {
                onOpen(todo)
            } label: {
                HStack(spacing: 8) {
                    Text(todo.area?.symbolName ?? "📥")

                    VStack(alignment: .leading, spacing: 2) {
                        Text(TodoDisplay.taskTitle(for: todo))
                            .font(todoTitleFont(todo))
                            .foregroundStyle(todoTitleColor(todo))
                            .strikethrough(todo.isCompleted)
                            .lineLimit(1)

                        Text(TodoDisplay.flowContextName(for: todo))
                            .font(.caption2)
                            .foregroundStyle(todo.area.map { Color(hex: $0.colorHex) } ?? .accentColor)
                            .lineLimit(1)

                        let detail = todoDetail(todo)
                        if todo.scheduledTimeMinutes != nil || !detail.isEmpty {
                            HStack(spacing: 4) {
                                if let minutes = todo.scheduledTimeMinutes {
                                    TaskTimeLabel(minutes: minutes, reminderEnabled: todo.reminderEnabled)
                                    if !detail.isEmpty { Text(verbatim: "・") }
                                }
                                if !detail.isEmpty { Text(verbatim: detail) }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 9)
    }

    private func todoTitleFont(_ todo: Todo) -> Font {
        todoTitleIsPlaceholder(todo)
            ? .subheadline.weight(.medium).italic()
            : .subheadline.weight(.medium)
    }

    private func todoTitleColor(_ todo: Todo) -> Color {
        if todoTitleIsPlaceholder(todo) {
            return .secondary.opacity(0.7)
        }
        return todo.isCompleted ? .secondary : .primary
    }

    private func todoTitleIsPlaceholder(_ todo: Todo) -> Bool {
        todo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func todoDetail(_ todo: Todo) -> String {
        let tags = todo.hashtags.map { "#\($0)" }.joined(separator: " ")
        var details: [String] = []
        if showsPriority { details.append(priorityLabel(todo)) }
        if todo.measurement != .checkbox { details.append(progressText(todo)) }
        if !tags.isEmpty { details.append(tags) }
        return details.joined(separator: "・")
    }

    private func priorityLabel(_ todo: Todo) -> String {
        if todo.priority == .low, todo.isRoomIfPossible {
            return String(localized: "余裕があれば")
        }
        return todo.priority.displayName
    }
}
#endif
