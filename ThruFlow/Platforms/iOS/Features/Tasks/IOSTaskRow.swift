#if os(iOS)
import SwiftData
import SwiftUI

struct IOSTaskRow: View {
    @Environment(\.modelContext) private var modelContext

    let todo: Todo
    var showsContextSubtitle = false
    let edit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TodoProgressControl(todo: todo) {
                if todo.setManuallyCompleted(!todo.isCompleted) {
                    _ = modelContext.saveReporting(.taskUpdate)
                }
            }

            Text(todo.area?.symbolName ?? DefaultAreas.taskInboxSymbol)
                .font(.title3)
                .accessibilityLabel(todo.area?.name ?? String(localized: "その他"))

            VStack(alignment: .leading, spacing: 3) {
                Text(TodoDisplay.taskTitle(for: todo))
                    .font(.body.weight(.medium))
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)

                if showsContextSubtitle {
                    Text(TodoDisplay.flowContextName(for: todo))
                        .font(.caption)
                        .foregroundStyle(todo.area.map { Color(hex: $0.colorHex) } ?? .accentColor)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(todo.priority.displayName)
                        if todo.measurement != .checkbox {
                            Text(verbatim: "・")
                            Text(progressText)
                        }
                        if let minutes = todo.scheduledTimeMinutes {
                            Text(verbatim: "・")
                            TaskTimeLabel(minutes: minutes, reminderEnabled: todo.reminderEnabled)
                        }
                        if let firstTag = todo.hashtags.first {
                            Text(verbatim: "・")
                            Text(verbatim: "#\(firstTag)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                } else {
                    HStack(spacing: 10) {
                        Text(TodoDisplay.flowContextName(for: todo))
                            .foregroundStyle(todo.area.map { Color(hex: $0.colorHex) } ?? .secondary)

                        HStack(spacing: 5) {
                            Text(todo.priority.displayName)
                            if todo.measurement != .checkbox {
                                Text(progressText)
                            }
                            if let minutes = todo.scheduledTimeMinutes {
                                TaskTimeLabel(minutes: minutes, reminderEnabled: todo.reminderEnabled)
                            }
                            if let firstTag = todo.hashtags.first {
                                Text("#\(firstTag)")
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: edit)
    }

    private var progressText: String {
        TodoProgressCalculator().summary(
            measurement: todo.measurement,
            plannedAmount: todo.plannedAmount,
            actualProgress: todo.actualProgress,
            focusDurationSeconds: todo.recordedFocusSeconds
        )
    }
}
#endif
