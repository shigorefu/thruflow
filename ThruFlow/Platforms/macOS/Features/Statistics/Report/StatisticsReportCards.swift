#if os(macOS)
import SwiftUI

struct StatisticsReportCards: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let snapshot: StatisticsPeriodSnapshot
    let today: Date
    let presentationPeriod: StatisticsPeriod
    let usesCustomRange: Bool
    let usesCompactCustomGrid: Bool
    let marksOutsideMonth: Bool
    @Binding var distributionDimension: StatisticsDistributionDimension
    @Binding var trendMode: StatisticsMode
    @Binding var dotsMode: StatisticsMode
    let onSelectHistoryDate: (Date) -> Void

    @ViewBuilder
    var body: some View {
        let habits = HabitCompletionCard(summary: snapshot.habitCompletion)
        let items = distributionItems

        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                habits.frame(minWidth: 230, idealWidth: 250, maxWidth: 280)

                StatisticsDistributionCard(
                    dimension: $distributionDimension,
                    items: items,
                    totalFocusSeconds: snapshot.summary.totalFocusSeconds,
                    isCompact: true
                )
                .frame(minWidth: 350, maxWidth: .infinity, alignment: .top)
            }

            VStack(alignment: .leading, spacing: 16) {
                habits

                StatisticsDistributionCard(
                    dimension: $distributionDimension,
                    items: items,
                    totalFocusSeconds: snapshot.summary.totalFocusSeconds
                )
            }
        }

        StatisticsTrendCard(
            mode: $trendMode,
            period: snapshot.trendPeriod,
            points: snapshot.trend,
            today: today
        )

        StatisticsDotsCard(
            mode: $dotsMode,
            period: presentationPeriod,
            usesCompactCustomGrid: usesCompactCustomGrid,
            usesCustomRange: usesCustomRange,
            marksOutsideMonth: marksOutsideMonth,
            flowDays: snapshot.flowDays,
            achievementDays: snapshot.achievementDays,
            maximumInteractiveDate: today,
            onSelectDate: onSelectHistoryDate
        )
        .id(presentationPeriod)
        .id("screenshot-statistics-dots")
        .transition(reduceMotion ? .identity : .opacity)
    }

    private var distributionItems: [StatisticsDistributionItem] {
        switch distributionDimension {
        case .task:
            snapshot.taskDistribution
        case .area:
            snapshot.areaDistribution
        case .project:
            snapshot.projectDistribution
        }
    }
}
#endif
