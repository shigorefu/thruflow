#if os(macOS)
import SwiftData
import SwiftUI

struct TodoRow: View {
    @Environment(\.modelContext) private var modelContext

    let todo: Todo
    let summary: String

    @State private var isHovering = false
    @State private var isEditingTitle = false
    @State private var draftTitle = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            TodoProgressControl(todo: todo) {
                if todo.setManuallyCompleted(!todo.isCompleted) {
                    _ = modelContext.saveReporting(.taskUpdate)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                titleEditor

                HStack(spacing: 6) {
                    Text(verbatim: "\(todo.area?.symbolName ?? DefaultAreas.taskInboxSymbol) \(TodoDisplay.flowContextName(for: todo))")
                        .foregroundStyle(checkboxTint)
                        .lineLimit(1)
                    Text("·")

                    if let minutes = todo.scheduledTimeMinutes {
                        TaskTimeLabel(minutes: minutes, reminderEnabled: todo.reminderEnabled)
                        Text("·")
                    }

                    Text(priorityLabel)

                    if todo.measurement != .checkbox {
                        Text("·")
                        Text(summary)
                    }

                    ForEach(todo.hashtags, id: \.self) { hashtag in
                        Text(verbatim: "#\(hashtag)")
                            .foregroundStyle(checkboxTint)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .opacity(todo.isCompleted ? 0.55 : 1)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onAppear {
            draftTitle = todo.title
        }
        .onChange(of: todo.title) { _, newValue in
            guard !isEditingTitle else { return }
            draftTitle = newValue
        }
        .onChange(of: isTitleFocused) { _, isFocused in
            if !isFocused, isEditingTitle {
                commitTitle()
            }
        }
        .onDisappear(perform: commitTitleIfNeeded)
        .listRowInsets(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10))
        .listRowSeparator(.hidden)
        .listRowBackground(rowBackground)
    }

    @ViewBuilder
    private var titleEditor: some View {
        if isEditingTitle {
            TextField(titlePlaceholder, text: $draftTitle)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .strikethrough(todo.isCompleted)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                .focused($isTitleFocused)
                .onSubmit(commitTitle)
                .accessibilityLabel(String(localized: "タスク名"))
        } else {
            Text(TodoDisplay.taskTitle(for: todo))
                .font(titleIsPlaceholder ? .body.weight(.medium).italic() : .body.weight(.medium))
                .strikethrough(todo.isCompleted)
                .foregroundStyle(titleColor)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    beginTitleEdit()
                }
                .accessibilityLabel(String(localized: "タスク名"))
        }
    }

    private func beginTitleEdit() {
        draftTitle = todo.title
        isEditingTitle = true

        Task { @MainActor in
            isTitleFocused = true
        }
    }

    private func commitTitle() {
        let normalizedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if todo.title != normalizedTitle {
            todo.title = normalizedTitle
            todo.updatedAt = .now
        }

        isEditingTitle = false
        isTitleFocused = false
        _ = modelContext.saveReporting(.taskUpdate)
    }

    private func commitTitleIfNeeded() {
        guard isEditingTitle else { return }
        commitTitle()
    }

    private var priorityLabel: String {
        if todo.priority == .low, todo.isRoomIfPossible {
            return String(localized: "余裕があれば")
        }
        return todo.priority.displayName
    }

    private var titlePlaceholder: String {
        TodoDisplay.taskPlaceholder(for: todo)
    }

    private var titleIsPlaceholder: Bool {
        todo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var titleColor: Color {
        if todo.isCompleted {
            return .secondary
        }

        return titleIsPlaceholder ? .secondary.opacity(0.7) : .primary
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(tintColor)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(isHovering ? 0.05 : 0))
            )
            .padding(.vertical, 2)
    }

    private var tintColor: Color {
        guard let area = todo.area, !DefaultAreas.isTaskInbox(area) else {
            return .clear
        }

        return Color(hex: area.colorHex).opacity(0.08)
    }

    private var checkboxTint: Color {
        guard let area = todo.area, !DefaultAreas.isTaskInbox(area) else {
            return Color.secondary.opacity(0.6)
        }

        return Color(hex: area.colorHex)
    }
}
#endif
