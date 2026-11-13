#if os(iOS)
import SwiftUI

struct IOSStatisticsSummaryCard: View {
    let title: String
    let summary: StatisticsPeriodSummary
    let previousSummary: StatisticsPeriodSummary

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        IOSStatisticsCard(title: String(localized: "概要"), subtitle: title) {
            LazyVGrid(columns: columns, spacing: 10) {
                IOSStatisticsMetric(
                    title: String(localized: "集中時間"),
                    value: IOSStatisticsFormatting.duration(summary.totalFocusSeconds),
                    previousValue: IOSStatisticsFormatting.duration(previousSummary.totalFocusSeconds),
                    systemImage: "timer"
                )
                IOSStatisticsMetric(
                    title: String(localized: "Blocks"),
                    value: BlockUnit.displayText(forFocusedSeconds: summary.totalFocusSeconds),
                    previousValue: BlockUnit.displayText(forFocusedSeconds: previousSummary.totalFocusSeconds),
                    systemImage: "square.grid.2x2"
                )
                IOSStatisticsMetric(
                    title: String(localized: "集中回数"),
                    value: "\(summary.flowCount)",
                    previousValue: "\(previousSummary.flowCount)",
                    systemImage: "water.waves"
                )
                IOSStatisticsMetric(
                    title: String(localized: "完了タスク"),
                    value: "\(summary.completedTaskCount)",
                    previousValue: "\(previousSummary.completedTaskCount)",
                    systemImage: "checkmark.circle"
                )
                IOSStatisticsMetric(
                    title: String(localized: "活動日"),
                    value: String(localized: "\(summary.activeFlowDayCount)日"),
                    previousValue: String(localized: "\(previousSummary.activeFlowDayCount)日"),
                    systemImage: "calendar"
                )
            }
        }
    }
}

private struct IOSStatisticsMetric: View {
    let title: String
    let value: String
    let previousValue: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(String(localized: "前の期間")) · \(previousValue)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.075))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
#endif
