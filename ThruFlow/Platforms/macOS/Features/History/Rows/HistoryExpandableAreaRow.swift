#if os(macOS)
import SwiftData
import SwiftUI

struct HistoryExpandableAreaRow: View {
    @Environment(\.locale) private var locale

    let area: DayHistoryAreaSummary
    let tasks: [DayHistoryTaskSummary]
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let onToggleCheckbox: (DayHistoryTaskSummary) -> Void
    let onEditTask: (Todo) -> Void
    let areaOnlyFlows: [DayHistoryFlow]
    let onEditFlow: (DayHistoryFlow) -> Void
    let onAddTask: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(area.symbol)
                    .font(.title2)
                    .frame(width: 34, height: 34)
                    .background(Color(hex: area.colorHex).opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 3) {
                    Text(area.name)
                        .font(.body.weight(.medium))
                    Text(String(localized: "タスク\(area.taskCount)件・集中\(area.flowCount)回"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(durationText(area.focusSeconds))
                    .font(.callout.weight(.semibold).monospacedDigit())

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(12)
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggleExpansion)

            if isExpanded {
                Divider().padding(.leading, 54)
                if tasks.isEmpty && areaOnlyFlows.isEmpty {
                    Text(String(localized: "この期間のタスクはありません"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 56)
                        .padding(.vertical, 10)
                } else {
                    ForEach(tasks) { task in
                        HStack(spacing: 10) {
                            if task.todo != nil {
                                HistoryTodoProgressIndicator(
                                    task: task,
                                    onToggleCheckbox: task.todos.count == 1 ? { onToggleCheckbox(task) } : nil
                                )
                            }
                            Text(task.areaSymbol)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .strikethrough(task.todo?.isCompleted == true)
                                    .lineLimit(1)
                                Text(taskSubtitle(task))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                if let todo = task.todo { onEditTask(todo) }
                            }
                            Spacer()
                            Text(durationText(task.focusSeconds))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.trailing, 12)
                        .padding(.vertical, 4)
                    }
                }

                ForEach(areaOnlyFlows) { flow in
                    HistoryFlowDisclosureRow(flow: flow) {
                        onEditFlow(flow)
                    }
                }

                Button(action: onAddTask) {
                    Label(String(localized: "タスクを追加"), systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 46)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel(String(localized: "\(area.name)にタスクを追加"))
            }
        }
        .background(Color.secondary.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        return minutes < 60 ? String(localized: "\(minutes)分") : String(localized: "\(minutes / 60)時間\(minutes % 60)分")
    }

    private func taskSubtitle(_ task: DayHistoryTaskSummary) -> String {
        let flowCount = String(localized: "集中\(task.flowCount)回")
        guard let scheduledDate = task.todo?.scheduledDate else { return flowCount }
        let date = scheduledDate.formatted(
            .dateTime.locale(locale).month().day().weekday(.abbreviated)
        )
        return "\(date)・\(flowCount)"
    }
}
#endif
