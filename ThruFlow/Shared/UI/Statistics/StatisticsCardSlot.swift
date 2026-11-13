#if os(macOS) || os(iOS)
import SwiftUI

struct StatisticsCardPresentationID: Equatable {
    let filter: StatisticsPeriodFilter
    let calendar: Calendar
    let dayBoundary: AppDayBoundary
    let isVisible: Bool
}

struct StatisticsCardSlot<Value, Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealedID: StatisticsCardPresentationID?

    let value: Value?
    let id: StatisticsCardPresentationID
    let placeholderHeight: CGFloat
    var showsLoading = true
    var fillsRow = false
    @ViewBuilder let content: (Value) -> Content

    private struct RevealRequest: Equatable {
        let id: StatisticsCardPresentationID
        let isReady: Bool
    }

    var body: some View {
        let request = RevealRequest(id: id, isReady: value != nil)
        let skipsAnimation = reduceMotion || Self.usesScreenshotAnchor
        let isRevealed = value != nil && (skipsAnimation || revealedID == id)

        Group {
            if request.isReady || showsLoading {
                StatisticsCardRevealLayout(
                    placeholderHeight: placeholderHeight,
                    progress: isRevealed ? 1 : 0,
                    fillsRow: fillsRow
                ) {
                    Group {
                        if let value {
                            content(value)
                        } else {
                            Color.clear
                        }
                    }
                    .opacity(isRevealed ? 1 : 0)
                    .allowsHitTesting(isRevealed)
                    .accessibilityHidden(!isRevealed)
                }
                .clipped()
                .overlay {
                    if !isRevealed {
                        FeatureLoadingIndicator()
                            .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
            }
        }
        .task(id: request) {
            guard id.isVisible, request.isReady else {
                revealedID = nil
                return
            }
            guard !skipsAnimation, revealedID != id else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                revealedID = id
            }
        }
    }

    private static var usesScreenshotAnchor: Bool {
        switch ScreenshotMode.initialScreen() {
        case .statisticsTrend, .statisticsBreakdown, .statisticsDots: true
        default: false
        }
    }
}

/// Animate the height a card occupies; paired cards can fill the height of their row.
private nonisolated struct StatisticsCardRevealLayout: Layout {
    let placeholderHeight: CGFloat
    var progress: CGFloat
    let fillsRow: Bool

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let card = subviews.first else { return .zero }
        let size = card.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        let height = (fillsRow ? proposal.height : nil)
            ?? placeholderHeight + (size.height - placeholderHeight) * progress
        return CGSize(width: proposal.width ?? size.width, height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(
            at: bounds.origin, anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: fillsRow ? bounds.height : nil)
        )
    }
}
#endif
