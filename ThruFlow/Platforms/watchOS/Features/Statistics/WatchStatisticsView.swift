#if os(watchOS)
import Foundation
import SwiftData
import SwiftUI

struct WatchStatisticsView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query private var todos: [Todo]
    @Query private var sessions: [FlowSession]
    @Query private var flowBreaks: [FlowBreak]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let snapshot = FlowDashboardBuilder(
                calendar: calendar,
                dayBoundary: dayBoundary
            ).build(
                date: timeline.date,
                sessions: sessions,
                breaks: flowBreaks,
                activeSessionID: activeFlowStore.activeSession?.id,
                activeFocusSeconds: activeFlowStore.actualFocusSeconds(now: timeline.date)
            )

            ScrollView {
                VStack(spacing: 10) {
                    Gauge(value: completionProgress) {
                        Text(String(localized: "達成状況"))
                    } currentValueLabel: {
                        Text(completionProgress, format: .percent.precision(.fractionLength(0)))
                            .font(.headline)
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(.green)
                    .frame(height: 105)

                    statisticRow(
                        String(localized: "集中時間"),
                        value: focusText(snapshot.totalFocusSeconds),
                        systemImage: "timer"
                    )
                    statisticRow(
                        String(localized: "ブロック"),
                        value: blockText(snapshot.blocks),
                        systemImage: "square.stack.3d.up"
                    )
                    statisticRow(
                        String(localized: "集中回数"),
                        value: "\(snapshot.flowCount)",
                        systemImage: "waveform.path"
                    )
                    statisticRow(
                        String(localized: "完了タスク"),
                        value: "\(todayTodos.filter(\.isCompleted).count)/\(todayTodos.count)",
                        systemImage: "checkmark.circle"
                    )
                }
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle(String(localized: "統計"))
    }

    private var todayTodos: [Todo] {
        todos.filter {
            TodayTodoFilter(
                calendar: calendar,
                dayBoundary: dayBoundary
            ).includes($0)
        }
    }

    private var completionProgress: Double {
        guard !todayTodos.isEmpty else { return 0 }
        return Double(todayTodos.filter(\.isCompleted).count) / Double(todayTodos.count)
    }

    private func statisticRow(
        _ title: String,
        value: String,
        systemImage: String
    ) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.caption)
        .padding(8)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private func focusText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return minutes >= 60
            ? "\(minutes / 60):\(String(format: "%02d", minutes % 60))"
            : "\(minutes)\(String(localized: "分"))"
    }

    private func blockText(_ blocks: Double) -> String {
        blocks.formatted(
            .number.precision(.fractionLength(blocks.rounded() == blocks ? 0 : 1))
        )
    }
}
#endif
