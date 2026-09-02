import SwiftUI
import WidgetKit

struct FlowTimerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: FlowTimerWidgetSnapshotStore.widgetKind,
            provider: FlowTimerWidgetProvider()
        ) { entry in
            FlowTimerWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(flowHex: entry.snapshot?.areaColorHex ?? "#007AFF")
                        .opacity(entry.snapshot == nil ? 0.04 : 0.10)
                }
                .widgetURL(URL(string: "thruflow://flow"))
        }
        .configurationDisplayName(String(localized: "Flowタイマー"))
        .description(String(localized: "実行中のFlowをホーム画面で確認できます。"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct FlowTimerWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: FlowTimerWidgetSnapshot?
}

private struct FlowTimerWidgetProvider: TimelineProvider {
    private let snapshots = FlowTimerWidgetSnapshotStore()

    func placeholder(in context: Context) -> FlowTimerWidgetEntry {
        FlowTimerWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (FlowTimerWidgetEntry) -> Void
    ) {
        completion(
            FlowTimerWidgetEntry(
                date: .now,
                snapshot: context.isPreview ? .placeholder : snapshots.load()
            )
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<FlowTimerWidgetEntry>) -> Void
    ) {
        let entry = FlowTimerWidgetEntry(date: .now, snapshot: snapshots.load())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

private struct FlowTimerWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: FlowTimerWidgetEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            activeContent(snapshot)
        } else {
            emptyContent
        }
    }

    @ViewBuilder
    private func activeContent(_ snapshot: FlowTimerWidgetSnapshot) -> some View {
        switch family {
        case .systemMedium:
            VStack(spacing: 10) {
                HStack(spacing: 16) {
                    identity(snapshot)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 7) {
                        timeLabel(snapshot)
                            .font(.title.monospacedDigit().weight(.bold))

                        Text("\(snapshot.statusTitle) · \(snapshot.modeName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                progress(snapshot)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text(snapshot.taskEmoji)
                        .font(.title2)

                    Spacer(minLength: 4)

                    Text(snapshot.statusTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(snapshot.taskTitle)
                    .font(.headline)
                    .lineLimit(2)

                if !snapshot.areaName.isEmpty {
                    Text(snapshot.areaName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                timeLabel(snapshot)
                    .font(.title2.monospacedDigit().weight(.bold))

                progress(snapshot)
            }
        }
    }

    private func identity(_ snapshot: FlowTimerWidgetSnapshot) -> some View {
        HStack(spacing: 12) {
            Text(snapshot.taskEmoji)
                .font(.title)
                .frame(width: 44, height: 44)
                .background(snapshot.tintColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.taskTitle)
                    .font(.headline)
                    .lineLimit(1)

                if !snapshot.areaName.isEmpty {
                    Text(snapshot.areaName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private func timeLabel(_ snapshot: FlowTimerWidgetSnapshot) -> some View {
        if snapshot.isPaused {
            Text(FlowLiveActivityFormatter.timeText(seconds: snapshot.remainingSeconds))
        } else {
            Text(timerInterval: snapshot.timerRange, countsDown: true, showsHours: false)
                .environment(\.locale, Locale(identifier: "en_US_POSIX"))
        }
    }

    @ViewBuilder
    private func progress(_ snapshot: FlowTimerWidgetSnapshot) -> some View {
        if snapshot.isPaused {
            ProgressView(value: snapshot.progress)
                .tint(snapshot.tintColor)
                .labelsHidden()
        } else {
            ProgressView(
                timerInterval: snapshot.timerRange,
                countsDown: snapshot.progressCountsDown
            )
            .tint(snapshot.tintColor)
            .labelsHidden()
        }
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "waveform.path")
                .font(.title2)
                .foregroundStyle(.tint)

            Spacer()

            Text(String(localized: "Flowを開始"))
                .font(.headline)

            Text(String(localized: "Flowなし"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private extension FlowTimerWidgetSnapshot {
    static let placeholder = FlowTimerWidgetSnapshot(
        sessionID: UUID(),
        taskEmoji: "📚",
        taskTitle: String(localized: "読書"),
        areaName: String(localized: "読書"),
        areaColorHex: "#007AFF",
        modeName: "Focus",
        status: .focus,
        timerKind: .focus,
        timerStartedAt: .now,
        plannedEndAt: .now.addingTimeInterval(25 * 60),
        remainingSeconds: 25 * 60,
        progress: 0,
        updatedAt: .now
    )

    var tintColor: Color {
        Color(flowHex: timerKind == .breakTime ? "#8E8E93" : areaColorHex)
    }
}

private extension Color {
    init(flowHex: String) {
        let normalized = flowHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(normalized, radix: 16) ?? 0x007AFF
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
