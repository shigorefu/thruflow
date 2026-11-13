#if os(macOS)
import SwiftUI

struct StatisticsReportCards: View {
    let cards: StatisticsPresentationCards
    let presentationID: StatisticsCardPresentationID
    let showsLoading: Bool
    let reportWidth: CGFloat
    let periodTitle: String
    let today: Date
    let presentationPeriod: StatisticsPeriod
    let usesCustomRange: Bool
    let usesCompactCustomGrid: Bool
    let marksOutsideMonth: Bool
    @Binding var distributionDimension: StatisticsDistributionDimension
    @Binding var trendMode: StatisticsMode
    @Binding var dotsMode: StatisticsMode
    let onSelectHistoryDate: (Date) -> Void

    private var isCompact: Bool { reportWidth >= 610 }
    private var spacing: CGFloat { isCompact ? 10 : 16 }
    private var equalCardWidth: CGFloat { isCompact ? (reportWidth - spacing) / 2 : reportWidth }
    private var distributionWidth: CGFloat { isCompact ? (reportWidth - spacing) * 0.58 : reportWidth }

    private var pairLayout: AnyLayout {
        isCompact
            ? AnyLayout(HStackLayout(alignment: .top, spacing: spacing))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
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

            if showsLoading || cards.dailyFocus != nil || cards.distribution != nil {
                pairLayout {
                    dailyFocusCard
                    distributionCard
                }
            }

            if showsLoading || cards.trend != nil || cards.days != nil {
                pairLayout {
                    trendCard
                    calendarCard
                }
            }

            StatisticsBottomMetricsCards(
                cards: cards, id: presentationID, showsLoading: showsLoading,
                compact: isCompact, spacing: spacing,
                habitsPlaceholderHeight: isCompact ? 150 : 230,
                estimatePlaceholderHeight: isCompact ? 110 : 150
            )
        }
    }

    private var dailyFocusCard: some View {
        StatisticsCardSlot(
            value: cards.dailyFocus, id: presentationID, placeholderHeight: isCompact ? 170 : 270,
            showsLoading: showsLoading
        ) { points in
            StatisticsDailyFocusCard(points: points, compact: isCompact)
        }
        .frame(width: isCompact ? reportWidth - distributionWidth - spacing : nil)
    }

    private var distributionCard: some View {
        StatisticsCardSlot(
            value: cards.distribution, id: presentationID, placeholderHeight: isCompact ? 170 : 270,
            showsLoading: showsLoading
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
        .frame(width: isCompact ? distributionWidth : nil)
        .id("screenshot-statistics-breakdown")
    }

    private var trendCard: some View {
        StatisticsCardSlot(
            value: cards.trend, id: presentationID, placeholderHeight: isCompact ? 174 : 320,
            showsLoading: showsLoading
        ) { trend in
            StatisticsTrendCard(
                mode: $trendMode, period: trend.period, points: trend.points, today: today, compact: isCompact
            )
        }
        .frame(width: isCompact ? equalCardWidth : nil)
        .id("screenshot-statistics-trend")
    }

    private var calendarCard: some View {
        StatisticsCardSlot(
            value: cards.days, id: presentationID, placeholderHeight: 140, showsLoading: showsLoading
        ) { days in
            StatisticsDotsCard(
                mode: $dotsMode,
                period: presentationPeriod,
                compact: isCompact,
                availableWidth: equalCardWidth,
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
        .frame(width: isCompact ? equalCardWidth : nil)
        .id("screenshot-statistics-dots")
    }
}
#endif
