#if os(iOS)
import SwiftUI

struct IOSStatisticsSummaryCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let summary: StatisticsPeriodSummary
    let previousSummary: StatisticsPeriodSummary
    var compact = false

    var body: some View {
        IOSStatisticsAnalysisCard(
            title: String(localized: "概要"),
            subtitle: compact ? nil : title,
            systemImage: "chart.bar.xaxis",
            compact: compact,
            accessory: { EmptyView() }
        ) {
            if compact {
                StatisticsEqualHeightGrid(columns: 5, spacing: 6) {
                    focusMetric
                    secondaryMetrics
                }
            } else {
                focusMetric
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) { secondaryMetrics }
                } else {
                    ViewThatFits(in: .horizontal) {
                        StatisticsEqualHeightGrid(columns: 4, spacing: 10) {
                            secondaryMetrics
                        }
                        .frame(minWidth: 534)
                        StatisticsEqualHeightGrid(columns: 2, spacing: 10) {
                            secondaryMetrics
                        }
                    }
                }
            }
        }
    }

    private var focusMetric: some View {
        IOSStatisticsMetric(
            title: String(localized: "集中時間"),
            value: IOSStatisticsFormatting.duration(summary.totalFocusSeconds),
            previousValue: IOSStatisticsFormatting.duration(previousSummary.totalFocusSeconds),
            systemImage: "timer",
            tint: .accentColor,
            isPrimary: true,
            compact: compact
        )
    }

    @ViewBuilder
    private var secondaryMetrics: some View {
        IOSStatisticsMetric(
            title: String(localized: "Blocks"),
            value: BlockUnit.displayText(forFocusedSeconds: summary.totalFocusSeconds),
            previousValue: BlockUnit.displayText(forFocusedSeconds: previousSummary.totalFocusSeconds),
            systemImage: "square.grid.2x2",
            tint: .indigo,
            compact: compact
        )
        IOSStatisticsMetric(
            title: String(localized: "集中回数"),
            value: "\(summary.flowCount)",
            previousValue: "\(previousSummary.flowCount)",
            systemImage: "water.waves",
            tint: .blue,
            compact: compact
        )
        IOSStatisticsMetric(
            title: String(localized: "完了タスク"),
            value: "\(summary.completedTaskCount)",
            previousValue: "\(previousSummary.completedTaskCount)",
            systemImage: "checkmark.circle",
            tint: .teal,
            compact: compact
        )
        IOSStatisticsMetric(
            title: String(localized: "活動日"),
            value: String(localized: "\(summary.activeFlowDayCount)日"),
            previousValue: String(localized: "\(previousSummary.activeFlowDayCount)日"),
            systemImage: "calendar",
            tint: .orange,
            compact: compact
        )
    }
}

private struct IOSStatisticsMetric: View {
    let title: String
    let value: String
    let previousValue: String
    let systemImage: String
    let tint: Color
    var isPrimary = false
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 8) {
            Label {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            Text(value)
                .font(compact ? .headline : isPrimary ? .largeTitle.bold() : .title2.weight(.semibold))
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            Text("\(String(localized: "前の期間")) · \(previousValue)")
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 45 : 82, maxHeight: .infinity, alignment: .leading)
        .padding(compact ? 4 : isPrimary ? 16 : 12)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: isPrimary ? [tint.opacity(0.17), tint.opacity(0.045)] : [
                            Color.primary.opacity(0.045),
                            Color.primary.opacity(0.025)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .accessibilityElement(children: .combine)
    }
}
#endif
