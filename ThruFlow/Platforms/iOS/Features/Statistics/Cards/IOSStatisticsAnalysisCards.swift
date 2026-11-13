#if os(iOS)
import SwiftUI

struct IOSStatisticsAnalysisCards: View {
    let cards: StatisticsPresentationCards
    let id: StatisticsCardPresentationID
    let showsLoading: Bool
    let periodTitle: String
    let today: Date
    let presentationPeriod: StatisticsPeriod
    let marksOutsideMonth: Bool
    let usesCustomRange: Bool
    let compact: Bool
    @Binding var trendMode: StatisticsMode
    @Binding var distributionDimension: IOSStatisticsDistributionDimension
    @Binding var dotsMode: StatisticsMode
    let onSelectDay: (IOSStatisticsContributionDay) -> Void

    var body: some View {
        IOSStatisticsReportLayout(compact: compact) {
            VStack(spacing: 0) { overview }
            VStack(spacing: 0) { dailyFocus }
            VStack(spacing: 0) { distribution }
            VStack(spacing: 0) { trend }
            VStack(spacing: 0) { dots }
            VStack(spacing: 0) {
                StatisticsBottomMetricsCards(
                    cards: cards, id: id, showsLoading: showsLoading,
                    compact: compact, spacing: compact ? 6 : 16,
                    habitsPlaceholderHeight: 180, estimatePlaceholderHeight: compact ? 105 : 165
                )
            }
        }
    }

    private var overview: some View {
        StatisticsCardSlot(
            value: cards.summary,
            id: id,
            placeholderHeight: compact ? 100 : 200,
            showsLoading: showsLoading
        ) { summary in
            IOSStatisticsSummaryCard(
                title: periodTitle,
                summary: summary.summary,
                previousSummary: summary.previousSummary,
                compact: compact
            )
        }
    }

    private var dailyFocus: some View {
        StatisticsCardSlot(
            value: cards.dailyFocus,
            id: id,
            placeholderHeight: compact ? 140 : 230,
            showsLoading: showsLoading
        ) { points in
            StatisticsDailyFocusCard(points: points, compact: compact)
        }
    }

    private var trend: some View {
        StatisticsCardSlot(
            value: cards.trend,
            id: id,
            placeholderHeight: compact ? 175 : 340,
            showsLoading: showsLoading
        ) { trend in
            IOSStatisticsTrendCard(
                mode: $trendMode,
                period: trend.period,
                points: trend.points,
                today: today,
                compact: compact
            )
        }
        .id("screenshot-statistics-trend")
    }

    private var distribution: some View {
        StatisticsCardSlot(
            value: cards.distribution,
            id: id,
            placeholderHeight: compact ? 180 : 280,
            showsLoading: showsLoading
        ) { distribution in
            IOSStatisticsDistributionCard(
                dimension: $distributionDimension,
                items: items(in: distribution),
                totalFocusSeconds: distribution.totalFocusSeconds,
                compact: compact
            )
        }
        .id("screenshot-statistics-breakdown")
    }

    private var dots: some View {
        StatisticsCardSlot(
            value: cards.days,
            id: id,
            placeholderHeight: 160,
            showsLoading: showsLoading
        ) { days in
            IOSStatisticsDotsCard(
                mode: $dotsMode,
                period: presentationPeriod,
                marksOutsideMonth: marksOutsideMonth,
                usesCustomRange: usesCustomRange,
                flowDays: days.flow,
                achievementDays: days.achievement,
                maximumInteractiveDate: today,
                compact: compact,
                onSelectDay: onSelectDay
            )
        }
        .id("screenshot-statistics-dots")
    }

    private func items(in distribution: StatisticsPresentationDistribution) -> [StatisticsDistributionItem] {
        switch distributionDimension {
        case .task: distribution.task
        case .area: distribution.area
        case .project: distribution.project
        }
    }
}

/// Keeps each card's identity while rearranging the report on wider displays.
private nonisolated struct IOSStatisticsReportLayout: Layout {
    let compact: Bool
    private var spacing: CGFloat { compact ? 6 : 16 }

    private enum Card: Int {
        case overview, dailyFocus, distribution, trend, dots, bottomMetrics
    }

    private var rows: [[Card]] {
        if compact {
            return [[.overview], [.dailyFocus, .distribution], [.trend, .dots], [.bottomMetrics]]
        }
        return [[.overview], [.dailyFocus], [.distribution], [.trend], [.dots], [.bottomMetrics]]
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let heights = rows.map { rowHeight($0, width: width, subviews: subviews) }.filter { $0 > 0 }
        let height = heights.reduce(0, +) + CGFloat(max(0, heights.count - 1)) * spacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for card in row {
                let proposal = cardProposal(card, in: row, width: bounds.width)
                subviews[card.rawValue].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: proposal)
                x += (proposal.width ?? 0) + spacing
            }
            let height = rowHeight(row, width: bounds.width, subviews: subviews)
            if height > 0 { y += height + spacing }
        }
    }

    private func rowHeight(_ row: [Card], width: CGFloat, subviews: Subviews) -> CGFloat {
        row.map { subviews[$0.rawValue].sizeThatFits(cardProposal($0, in: row, width: width)).height }.max() ?? 0
    }

    private func cardProposal(_ card: Card, in row: [Card], width: CGFloat) -> ProposedViewSize {
        if row.count == 1 { return ProposedViewSize(width: width, height: nil) }
        let fraction: CGFloat
        switch card {
        case .distribution: fraction = 0.60
        case .dailyFocus: fraction = 0.40
        default: fraction = 1 / 2
        }
        return ProposedViewSize(width: max(0, width - spacing) * fraction, height: nil)
    }
}
#endif
