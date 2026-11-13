#if os(macOS) || os(iOS)
import SwiftUI

struct StatisticsBottomMetricsCards: View {
    let cards: StatisticsPresentationCards
    let id: StatisticsCardPresentationID
    let showsLoading: Bool
    let compact: Bool
    let spacing: CGFloat
    let habitsPlaceholderHeight: CGFloat
    let estimatePlaceholderHeight: CGFloat

    var body: some View {
        if showsLoading || cards.habits != nil || cards.estimateAccuracy != nil {
            let layout = compact
                ? AnyLayout(StatisticsEqualHeightGrid(columns: 2, spacing: spacing))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            layout {
                // The wrappers keep each column in place when only one card is available.
                VStack(spacing: 0) {
                    StatisticsCardSlot(
                        value: cards.habits, id: id, placeholderHeight: habitsPlaceholderHeight,
                        showsLoading: showsLoading, fillsRow: compact
                    ) { summary in
                        HabitCompletionCard(summary: summary, compact: compact)
                    }
                }
                VStack(spacing: 0) {
                    StatisticsCardSlot(
                        value: cards.estimateAccuracy, id: id, placeholderHeight: estimatePlaceholderHeight,
                        showsLoading: showsLoading, fillsRow: compact
                    ) { value in
                        StatisticsEstimateAccuracyCard(value: value, compact: compact)
                    }
                }
            }
        }
    }
}
#endif
