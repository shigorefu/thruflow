#if os(macOS)
import SwiftUI

struct StatisticsReportCards: View {
    let cards: StatisticsPresentationCards
    let presentationID: StatisticsCardPresentationID
    let showsLoading: Bool
    let reportWidth: CGFloat
    let viewportHeight: CGFloat
    let periodTitle: String
    let today: Date
    let presentationPeriod: StatisticsPeriod
    let usesCustomRange: Bool
    let usesCompactCustomGrid: Bool
    let marksOutsideMonth: Bool
    @Binding var distributionDimension: StatisticsDistributionDimension
    @Binding var trendMode: StatisticsQualityMode
    @Binding var dotsMode: StatisticsMode
    let onSelectHistoryDate: (Date) -> Void

    private var isCompact: Bool { reportWidth >= 610 }
    private var spacing: CGFloat { isCompact ? 10 : 16 }
    private var triplesBottomCards: Bool { reportWidth >= 1100 }
    private var pairsAnalysisCards: Bool { reportWidth >= 700 && viewportHeight >= 650 }
    private var distributionWidth: CGFloat {
        pairsAnalysisCards ? StatisticsReportLayout.distributionWidth(for: reportWidth, spacing: spacing) : reportWidth
    }
    private var calendarWidth: CGFloat {
        triplesBottomCards ? (reportWidth - 2 * spacing) / 3 : reportWidth
    }

    var body: some View {
        StatisticsReportLayout(
            spacing: spacing, triplesBottomCards: triplesBottomCards,
            pairsAnalysisCards: pairsAnalysisCards, pairsBottomMetrics: isCompact
        ) {
            // Stable wrappers preserve slot identity, including partially available reports.
            VStack(spacing: 0) {
                StatisticsCardSlot(
                    value: cards.summary, id: presentationID, placeholderHeight: isCompact ? 106 : 180,
                    showsLoading: showsLoading
                ) { summary in
                    StatisticsSummaryCard(
                        title: periodTitle,
                        summary: summary.summary,
                        previousSummary: summary.previousSummary,
                        availableWidth: reportWidth,
                        compact: isCompact
                    )
                }
            }
            VStack(spacing: 0) { dailyFocusCard }
            VStack(spacing: 0) { distributionCard }
            VStack(spacing: 0) { trendCard }
            VStack(spacing: 0) { calendarCard }
            VStack(spacing: 0) { habitCard }
            VStack(spacing: 0) { estimateAccuracyCard }
        }
    }

    private var dailyFocusCard: some View {
        StatisticsCardSlot(
            value: cards.dailyFocus, id: presentationID, placeholderHeight: isCompact ? 170 : 270,
            showsLoading: showsLoading, fillsRow: true
        ) { points in
            StatisticsDailyFocusCard(
                points: points, compact: isCompact, plotHeight: isCompact ? 90 : 190, expandsPlot: true
            )
        }
    }

    private var distributionCard: some View {
        StatisticsCardSlot(
            value: cards.distribution, id: presentationID, placeholderHeight: isCompact ? 170 : 270,
            showsLoading: showsLoading, fillsRow: pairsAnalysisCards
        ) { distribution in
            StatisticsDistributionOptions(selection: $distributionDimension) { selection, options in
                StatisticsDistributionCard(
                    dimension: selection,
                    options: options,
                    items: selection.wrappedValue.items(in: distribution),
                    totalFocusSeconds: distribution.totalFocusSeconds,
                    availableWidth: distributionWidth,
                    compact: isCompact
                )
            }
        }
        .id("screenshot-statistics-breakdown")
    }

    private var trendCard: some View {
        StatisticsCardSlot(
            value: cards.trend, id: presentationID, placeholderHeight: 330,
            showsLoading: showsLoading, fillsRow: true
        ) { trend in
            StatisticsTrendCard(
                mode: $trendMode, trend: trend, today: today, availableWidth: reportWidth,
                compact: isCompact, expandsPlot: true
            )
        }
        .id("screenshot-statistics-trend")
    }

    private var calendarCard: some View {
        StatisticsCardSlot(
            value: cards.days, id: presentationID, placeholderHeight: 140,
            showsLoading: showsLoading, fillsRow: triplesBottomCards
        ) { days in
            StatisticsDotsCard(
                mode: $dotsMode,
                period: presentationPeriod,
                compact: isCompact,
                availableWidth: calendarWidth,
                usesCompactCustomGrid: usesCompactCustomGrid,
                usesCustomRange: usesCustomRange,
                marksOutsideMonth: marksOutsideMonth,
                flowDays: days.flow,
                achievementDays: days.achievement,
                maximumInteractiveDate: today,
                onSelectDate: onSelectHistoryDate
            )
            .id(presentationPeriod)
        }
        .id("screenshot-statistics-dots")
    }

    private var habitCard: some View {
        StatisticsCardSlot(
            value: cards.habits, id: presentationID, placeholderHeight: isCompact ? 150 : 230,
            showsLoading: showsLoading, fillsRow: isCompact
        ) { summary in
            HabitCompletionCard(summary: summary, compact: isCompact)
        }
    }

    private var estimateAccuracyCard: some View {
        StatisticsCardSlot(
            value: cards.estimateAccuracy, id: presentationID, placeholderHeight: isCompact ? 110 : 150,
            showsLoading: showsLoading, fillsRow: isCompact
        ) { value in
            StatisticsEstimateAccuracyCard(value: value, compact: isCompact)
        }
    }
}

/// Keeps card identity stable while pairing rows only when the viewport has room.
private nonisolated struct StatisticsReportLayout: Layout {
    let spacing: CGFloat
    let triplesBottomCards: Bool
    let pairsAnalysisCards: Bool
    let pairsBottomMetrics: Bool

    private var rows: [[Int]] {
        var rows = [[0]]
        rows += pairsAnalysisCards ? [[1, 2]] : [[1], [2]]
        rows.append([3])
        if triplesBottomCards {
            rows.append([4, 5, 6])
        } else {
            rows.append([4])
            rows += pairsBottomMetrics ? [[5, 6]] : [[5], [6]]
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 610
        let heights = rowHeights(width: width, subviews: subviews)
        return CGSize(width: width, height: totalHeight(heights))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let heights = rowHeights(width: bounds.width, subviews: subviews)
        var y = bounds.minY
        for (index, row) in rows.enumerated() {
            var x = bounds.minX
            for card in row {
                let width = cardWidth(card, in: row, width: bounds.width)
                subviews[card].place(
                    at: CGPoint(x: x, y: y), anchor: .topLeading,
                    proposal: ProposedViewSize(width: width, height: heights[index])
                )
                x += width + spacing
            }
            if heights[index] > 0 { y += heights[index] + spacing }
        }
    }

    private func rowHeights(width: CGFloat, subviews: Subviews) -> [CGFloat] {
        rows.map { row in
            row.map { card in
                subviews[card].sizeThatFits(ProposedViewSize(
                    width: cardWidth(card, in: row, width: width), height: nil
                )).height
            }.max() ?? 0
        }
    }

    private func cardWidth(_ card: Int, in row: [Int], width: CGFloat) -> CGFloat {
        guard row.count > 1 else { return width }
        if row.count == 3 { return max(0, width - 2 * spacing) / 3 }
        let availableWidth = max(0, width - spacing)
        if card == 1 { return availableWidth - Self.distributionWidth(for: width, spacing: spacing) }
        if card == 2 { return Self.distributionWidth(for: width, spacing: spacing) }
        return availableWidth / 2
    }

    static func distributionWidth(for width: CGFloat, spacing: CGFloat) -> CGFloat {
        min(520, max(0, width - spacing) * 0.42)
    }

    private func totalHeight(_ heights: [CGFloat]) -> CGFloat {
        heights.reduce(0, +) + CGFloat(max(0, heights.filter { $0 > 0 }.count - 1)) * spacing
    }
}
#endif
