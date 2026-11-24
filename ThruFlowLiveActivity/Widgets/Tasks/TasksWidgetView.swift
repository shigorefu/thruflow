import Foundation
import SwiftUI
import WidgetKit

struct TasksWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: TasksWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if let snapshot = entry.snapshot, !snapshot.items.isEmpty {
                VStack(spacing: family == .systemSmall ? 8 : 9) {
                    ForEach(Array(snapshot.items.prefix(maximumRows))) { item in
                        TaskWidgetRow(item: item, compact: family == .systemSmall)
                    }
                }
            } else {
                emptyState
            }

            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label(String(localized: "今日のタスク"), systemImage: "checklist")
                .font(.headline)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let snapshot = entry.snapshot {
                Text("\(snapshot.completedCount)/\(snapshot.items.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: "checkmark.circle")
                .font(.title2)
                .foregroundStyle(.tint)

            Text(String(localized: "今日の項目はありません"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var maximumRows: Int {
        switch family {
        case .systemSmall: 2
        case .systemMedium: 3
        default: 7
        }
    }
}

private struct TaskWidgetRow: View {
    let item: TaskWidgetItemSnapshot
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 7 : 9) {
            TaskWidgetProgress(item: item)
                .frame(width: 22, height: 22)

            if !compact {
                Text(item.areaSymbol)
                    .font(.body)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(compact ? .caption : .subheadline)
                    .fontWeight(.semibold)
                    .strikethrough(item.isCompleted)
                    .lineLimit(1)

                if !compact {
                    Text(progressText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressText: String {
        switch item.measurement {
        case .checkbox:
            return item.areaName
        case .focusBlocks:
            let blocks = Double(item.focusedSeconds) / 1_500
            return "\(blocks.formatted(.number.precision(.fractionLength(0...1)))) / \(item.plannedAmount) Block"
        case .minutes:
            return "\(item.actualProgress) / \(item.plannedAmount) \(String(localized: "分"))"
        }
    }
}

private struct TaskWidgetProgress: View {
    let item: TaskWidgetItemSnapshot

    var body: some View {
        switch item.measurement {
        case .checkbox:
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(item.tintColor, lineWidth: 2)
                .overlay {
                    if item.isCompleted {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(item.tintColor)
                        Image(systemName: "checkmark")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                    }
                }
        case .focusBlocks:
            Circle()
                .stroke(item.tintColor.opacity(0.25), lineWidth: 3)
                .overlay {
                    Circle()
                        .trim(from: 0, to: item.progress)
                        .stroke(
                            item.tintColor,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
        case .minutes:
            Circle()
                .stroke(item.tintColor.opacity(0.30), lineWidth: 2)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(item.tintColor)
                        .frame(height: 22 * item.progress)
                }
                .clipShape(Circle())
        }
    }
}

private extension TaskWidgetItemSnapshot {
    var tintColor: Color {
        Color(productHex: areaColorHex)
    }
}
