import SwiftUI
import WidgetKit

struct TasksWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: ProductWidgetSnapshotStore.tasksWidgetKind,
            provider: TasksWidgetProvider()
        ) { entry in
            TasksWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.accentColor.opacity(0.06)
                }
                .widgetURL(URL(string: "thruflow://tasks"))
        }
        .configurationDisplayName(String(localized: "今日のタスク"))
        .description(String(localized: "今日のタスクと進捗をホーム画面で確認できます。"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct TasksWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: TasksWidgetSnapshot?
}

private struct TasksWidgetProvider: TimelineProvider {
    private let snapshots = ProductWidgetSnapshotStore()

    func placeholder(in context: Context) -> TasksWidgetEntry {
        TasksWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (TasksWidgetEntry) -> Void
    ) {
        completion(
            TasksWidgetEntry(
                date: .now,
                snapshot: context.isPreview ? .placeholder : currentSnapshot()
            )
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<TasksWidgetEntry>) -> Void
    ) {
        let now = Date.now
        let entry = TasksWidgetEntry(date: now, snapshot: currentSnapshot(at: now))
        let nextDay = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: now)
        ) ?? now.addingTimeInterval(86_400)
        completion(Timeline(entries: [entry], policy: .after(nextDay)))
    }

    private func currentSnapshot(at date: Date = .now) -> TasksWidgetSnapshot? {
        guard let snapshot = snapshots.loadTasks(),
              Calendar.current.isDate(snapshot.date, inSameDayAs: date) else {
            return nil
        }
        return snapshot
    }
}

private struct TasksWidgetView: View {
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

private extension TasksWidgetSnapshot {
    static let placeholder = TasksWidgetSnapshot(
        generatedAt: .now,
        date: .now,
        items: [
            TaskWidgetItemSnapshot(
                id: UUID(),
                title: String(localized: "発表資料を作る"),
                areaSymbol: "💻",
                areaName: String(localized: "その他"),
                areaColorHex: "#34C759",
                measurement: .focusBlocks,
                plannedAmount: 2,
                actualProgress: 1,
                focusedSeconds: 25 * 60,
                isCompleted: false
            ),
            TaskWidgetItemSnapshot(
                id: UUID(),
                title: String(localized: "読書"),
                areaSymbol: "📚",
                areaName: String(localized: "読書"),
                areaColorHex: "#AF52DE",
                measurement: .checkbox,
                plannedAmount: 1,
                actualProgress: 1,
                focusedSeconds: 0,
                isCompleted: true
            ),
        ]
    )
}
