#if os(macOS)
import SwiftData
import SwiftUI

struct HistoryExpandableTaskRow: View {
    let task: DayHistoryTaskSummary
    let flows: [DayHistoryFlow]
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let onToggleCheckbox: (() -> Void)?
    let onEdit: (Todo) -> Void
    let onEditFlow: (DayHistoryFlow) -> Void
    let onAddFlow: (Todo) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HistoryTodoProgressIndicator(
                    task: task,
                    onToggleCheckbox: onToggleCheckbox
                )

                HStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Text(task.areaSymbol)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.body.weight(.medium))
                                .strikethrough(task.todo?.isCompleted == true)
                                .lineLimit(1)
                            Text(String(localized: "\(task.areaName)・集中\(task.flowCount)回"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        if let todo = task.todo { onEdit(todo) }
                    }

                    Spacer(minLength: 8)

                    Text(durationText(task.focusSeconds))
                        .font(.callout.weight(.semibold).monospacedDigit())

                    if let todo = task.todo {
                        Button {
                            onAddFlow(todo)
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help(String(localized: "このタスクに集中記録を追加"))
                        .accessibilityLabel(String(localized: "このタスクに集中記録を追加"))
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onToggleExpansion)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            if isExpanded {
                Divider().padding(.leading, 54)
                if flows.isEmpty {
                    Text(String(localized: "この期間には集中記録がありません"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 56)
                        .padding(.vertical, 10)
                } else {
                    ForEach(flows) { flow in
                        HistoryFlowDisclosureRow(flow: flow) {
                            onEditFlow(flow)
                        }
                    }
                }
            }
        }
        .background(Color.secondary.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        return minutes < 60 ? String(localized: "\(minutes)分") : String(localized: "\(minutes / 60)時間\(minutes % 60)分")
    }
}

struct HistoryTodoProgressIndicator: View {
    let task: DayHistoryTaskSummary
    let onToggleCheckbox: (() -> Void)?

    @ViewBuilder
    var body: some View {
        switch measurement {
        case .checkbox:
            if let onToggleCheckbox {
                Button(action: onToggleCheckbox) {
                    checkbox
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(width: 34, height: 34)
                .accessibilityLabel(isCompleted ? String(localized: "未完了に戻す") : String(localized: "完了にする"))
                .accessibilityValue(progressDescription)
            } else {
                checkbox
                    .frame(width: 34, height: 34)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(localized: "タスク進捗"))
                    .accessibilityValue(progressDescription)
            }
        case .focusBlocks, .minutes:
            progressRing
                .frame(width: 34, height: 34)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "タスク進捗"))
                .accessibilityValue(progressDescription)
        }
    }

    private var checkbox: some View {
        RoundedRectangle(cornerRadius: 5)
            .strokeBorder(tint, lineWidth: 1.6)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(isCompleted ? tint : Color.clear)
            }
            .overlay {
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 20, height: 20)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.22), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if measurement == .minutes {
                Image(systemName: "timer")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(tint)
            } else if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: 22, height: 22)
    }

    private var measurement: TodoMeasurement {
        task.todo?.measurement ?? .checkbox
    }

    private var isCompleted: Bool {
        !task.todos.isEmpty && task.todos.allSatisfy(\.isCompleted)
    }

    private var progress: Double {
        guard !task.todos.isEmpty else { return 0 }
        switch measurement {
        case .checkbox:
            return Double(task.todos.filter(\.isCompleted).count) / Double(task.todos.count)
        case .focusBlocks:
            let target = task.todos.reduce(0) { $0 + max(1, $1.plannedAmount ?? 1) }
            return min(BlockUnit.blocks(forFocusedSeconds: task.focusSeconds) / Double(target), 1)
        case .minutes:
            let target = task.todos.reduce(0) { $0 + max(1, $1.plannedAmount ?? 1) }
            return min(Double(task.focusSeconds) / 60 / Double(target), 1)
        }
    }

    private var tint: Color {
        Color(hex: task.areaColorHex)
    }

    private var progressDescription: String {
        if isCompleted { return String(localized: "完了済み") }
        return "\(Int((progress * 100).rounded()))%"
    }
}
#endif
