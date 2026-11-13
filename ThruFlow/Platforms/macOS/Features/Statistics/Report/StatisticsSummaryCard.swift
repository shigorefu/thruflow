#if os(macOS)
import SwiftUI

struct StatisticsSummaryCard: View {
    let title: String
    let summary: StatisticsPeriodSummary
    let previousSummary: StatisticsPeriodSummary

    private let columns = [GridItem(.adaptive(minimum: 128, maximum: 220), spacing: 10)]

    var body: some View {
        StatisticsCard(title: String(localized: "概要"), subtitle: title) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                StatisticsSummaryMetric(
                    title: String(localized: "集中時間"),
                    value: StatisticsFormatting.duration(summary.totalFocusSeconds),
                    previousValue: StatisticsFormatting.duration(previousSummary.totalFocusSeconds),
                    systemImage: "timer"
                )
                StatisticsSummaryMetric(
                    title: String(localized: "Blocks"),
                    value: BlockUnit.displayText(forFocusedSeconds: summary.totalFocusSeconds),
                    previousValue: BlockUnit.displayText(forFocusedSeconds: previousSummary.totalFocusSeconds),
                    systemImage: "square.grid.2x2"
                )
                StatisticsSummaryMetric(
                    title: String(localized: "集中回数"),
                    value: "\(summary.flowCount)",
                    previousValue: "\(previousSummary.flowCount)",
                    systemImage: "water.waves"
                )
                StatisticsSummaryMetric(
                    title: String(localized: "完了タスク"),
                    value: "\(summary.completedTaskCount)",
                    previousValue: "\(previousSummary.completedTaskCount)",
                    systemImage: "checkmark.circle"
                )
                StatisticsSummaryMetric(
                    title: String(localized: "活動日"),
                    value: String(localized: "\(summary.activeFlowDayCount)日"),
                    previousValue: String(localized: "\(previousSummary.activeFlowDayCount)日"),
                    systemImage: "calendar"
                )
            }
        }
    }
}

private struct StatisticsSummaryMetric: View {
    let title: String
    let value: String
    let previousValue: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text("\(String(localized: "前の期間")) · \(previousValue)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.075))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
#endif
