#if os(macOS)
import SwiftUI

struct StatisticsSummaryCard: View {
    let title: String
    let summary: StatisticsPeriodSummary
    let previousSummary: StatisticsPeriodSummary
    let availableWidth: CGFloat
    let compact: Bool

    private var columnCount: Int {
        if compact { return 5 }
        return availableWidth >= 350 ? 2 : 1
    }

    var body: some View {
        let spacing: CGFloat = compact ? 6 : 10
        return StatisticsAnalysisCard(
            title: String(localized: "概要"), subtitle: title, systemImage: "square.grid.2x2", compact: compact
        ) {
            EmptyView()
        } content: {
            if !compact { focusMetric }
            StatisticsEqualHeightGrid(columns: columnCount, spacing: spacing) {
                if compact { focusMetric }
                StatisticsSummaryMetric(
                    title: String(localized: "Blocks"),
                    value: BlockUnit.displayText(forFocusedSeconds: summary.totalFocusSeconds),
                    previousValue: BlockUnit.displayText(forFocusedSeconds: previousSummary.totalFocusSeconds),
                    systemImage: "square.grid.2x2",
                    tint: .indigo,
                    compact: compact
                )
                StatisticsSummaryMetric(
                    title: String(localized: "集中回数"),
                    value: "\(summary.flowCount)",
                    previousValue: "\(previousSummary.flowCount)",
                    systemImage: "water.waves",
                    tint: .teal,
                    compact: compact
                )
                StatisticsSummaryMetric(
                    title: String(localized: "完了タスク"),
                    value: "\(summary.completedTaskCount)",
                    previousValue: "\(previousSummary.completedTaskCount)",
                    systemImage: "checkmark.circle",
                    tint: .green,
                    compact: compact
                )
                StatisticsSummaryMetric(
                    title: String(localized: "活動日"),
                    value: String(localized: "\(summary.activeFlowDayCount)日"),
                    previousValue: String(localized: "\(previousSummary.activeFlowDayCount)日"),
                    systemImage: "calendar",
                    tint: .orange,
                    compact: compact
                )
            }
        }
    }

    private var focusMetric: some View {
        StatisticsSummaryMetric(
            title: String(localized: "集中時間"),
            value: StatisticsFormatting.duration(summary.totalFocusSeconds),
            previousValue: StatisticsFormatting.duration(previousSummary.totalFocusSeconds),
            systemImage: "timer",
            tint: .accentColor,
            compact: compact,
            isPrimary: true
        )
    }
}

private struct StatisticsSummaryMetric: View {
    let title: String
    let value: String
    let previousValue: String
    let systemImage: String
    let tint: Color
    let compact: Bool
    var isPrimary = false

    private var valueFont: Font {
        if compact { return isPrimary ? .title2.bold() : .title3.weight(.semibold) }
        return isPrimary ? .largeTitle.bold() : .title3.weight(.semibold)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 6) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text(title)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption.weight(.semibold))

            Text(value)
                .font(valueFont)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.66)

            Text("\(String(localized: "前の期間")) · \(previousValue)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 5 : 10)
        .frame(minHeight: compact ? 58 : 80, maxHeight: .infinity, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isPrimary ? AnyShapeStyle(LinearGradient(
                colors: [tint.opacity(0.19), tint.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )) : AnyShapeStyle(Color.primary.opacity(0.035)),
            in: RoundedRectangle(cornerRadius: 11)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(isPrimary ? tint.opacity(0.25) : Color.primary.opacity(0.055))
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .combine)
    }
}
#endif
