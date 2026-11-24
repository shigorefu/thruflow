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
    var fillsRow = false

    private var showsHabits: Bool { showsLoading || cards.habits != nil }
    private var showsEstimate: Bool { showsLoading || cards.estimateAccuracy != nil }

    var body: some View {
        if showsHabits || showsEstimate {
            VStack(alignment: .leading, spacing: spacing) {
                if showsHabits {
                    StatisticsCardSlot(
                        value: cards.habits, id: id, placeholderHeight: habitsPlaceholderHeight,
                        showsLoading: showsLoading
                    ) { summary in
                        HabitCompletionCard(summary: summary, compact: compact, embedded: true)
                    }
                }
                if showsHabits && showsEstimate {
                    Divider()
                }
                if showsEstimate {
                    StatisticsCardSlot(
                        value: cards.estimateAccuracy, id: id, placeholderHeight: estimatePlaceholderHeight,
                        showsLoading: showsLoading
                    ) { value in
                        StatisticsEstimateAccuracyCard(value: value, compact: compact, embedded: true)
                    }
                }
            }
            .padding(compact ? 12 : 16)
            .frame(maxWidth: .infinity, maxHeight: fillsRow ? .infinity : nil, alignment: .topLeading)
            .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.primary.opacity(0.08))
                    .allowsHitTesting(false)
            }
        }
    }
}
#endif
