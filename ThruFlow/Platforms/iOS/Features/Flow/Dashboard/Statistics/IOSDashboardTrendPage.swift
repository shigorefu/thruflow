#if os(iOS)
import SwiftUI

struct IOSDashboardTrendPage: View {
    let snapshot: FlowDashboardSnapshot
    let records: IOSFlowRecentRecords
    let todos: [Todo]
    let calendar: Calendar
    let dayBoundary: AppDayBoundary

    private var statisticsBuilder: DashboardStatisticsBuilder {
        DashboardStatisticsBuilder(calendar: calendar, dayBoundary: dayBoundary)
    }

    var body: some View {
        let days = statisticsBuilder.days(
            count: 7,
            endingOn: snapshot.date,
            sessions: records.sessions,
            breaks: records.breaks
        )
        let comparison = statisticsBuilder.comparison(
            on: snapshot.date,
            sessions: records.sessions,
            breaks: records.breaks,
            todos: todos
        )

        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "7日"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            IOSDashboardStatisticsBars(days: days)
                .frame(height: 112)

            Divider()

            comparisonRow(
                String(localized: "集中時間"),
                value: signedMinutes(comparison.focusSecondsDelta),
                systemImage: "timer"
            )
            comparisonRow(
                String(localized: "完了タスク"),
                value: signedCount(comparison.completedTaskDelta),
                systemImage: "checkmark.circle"
            )
            comparisonRow(
                String(localized: "ブロック"),
                value: signedBlocks(comparison.blocksDelta),
                systemImage: "square.stack.3d.up"
            )
            comparisonRow(
                String(localized: "伸びた方向"),
                value: growthText(comparison.growingArea),
                systemImage: "arrow.up.right"
            )
        }
    }

    private func comparisonRow(_ title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.caption)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    private func signedMinutes(_ seconds: Int) -> String {
        signedValue(Int((Double(seconds) / 60).rounded()), suffix: String(localized: "分"))
    }

    private func signedCount(_ count: Int) -> String {
        signedValue(count, suffix: "")
    }

    private func signedBlocks(_ blocks: Double) -> String {
        let sign = blocks > 0 ? "+" : ""
        let value = abs(blocks) < 0.001 ? 0 : blocks
        let text = value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
        return "\(sign)\(text)"
    }

    private func signedValue(_ value: Int, suffix: String) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(value)\(suffix)"
    }

    private func growthText(_ growth: DashboardStatisticsAreaGrowth?) -> String {
        guard let growth else { return String(localized: "変化なし") }
        let minutes = max(1, growth.focusSecondsDelta / 60)
        return "\(growth.symbol) \(growth.name) +\(minutes)\(String(localized: "分"))"
    }
}

private struct IOSDashboardStatisticsBars: View {
    let days: [DashboardStatisticsDay]

    var body: some View {
        GeometryReader { proxy in
            let maximum = max(days.map(\.focusSeconds).max() ?? 0, 1)

            HStack(alignment: .bottom, spacing: 7) {
                ForEach(days) { day in
                    let minimumHeight: CGFloat = day.focusSeconds > 0 ? 4 : 2
                    let availableHeight = max(proxy.size.height - 23, 0)
                    let proportionalHeight = availableHeight
                        * CGFloat(day.focusSeconds)
                        / CGFloat(maximum)
                    let barHeight = max(minimumHeight, proportionalHeight)

                    VStack(spacing: 5) {
                        Spacer(minLength: 0)
                        Capsule()
                            .fill(Color(hex: day.colorHex))
                            .frame(width: 7, height: barHeight)
                        Text(day.date.formatted(.dateTime.day()))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(dayAccessibilityLabel(day))
                }
            }
        }
    }

    private func dayAccessibilityLabel(_ day: DashboardStatisticsDay) -> String {
        "\(day.date.formatted(date: .abbreviated, time: .omitted)), \(day.focusSeconds / 60)\(String(localized: "分"))"
    }
}
#endif
