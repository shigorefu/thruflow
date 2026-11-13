#if os(macOS) || os(iOS)
import SwiftUI

/// Measures cards at their column width, then gives each card the height of its row.
nonisolated struct StatisticsEqualHeightGrid: Layout {
    let columns: Int
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? idealWidth(subviews)
        let heights = rowHeights(at: columnWidth(for: width), subviews: subviews)
        return CGSize(width: width, height: heights.reduce(0, +) + CGFloat(max(0, heights.count - 1)) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = columnWidth(for: bounds.width)
        let heights = rowHeights(at: width, subviews: subviews)
        var y = bounds.minY
        for (row, height) in heights.enumerated() {
            for column in 0..<min(columns, subviews.count - row * columns) {
                subviews[row * columns + column].place(
                    at: CGPoint(x: bounds.minX + CGFloat(column) * (width + spacing), y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: width, height: height)
                )
            }
            y += height + spacing
        }
    }

    private func columnWidth(for width: CGFloat) -> CGFloat {
        max(0, width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
    }

    private func idealWidth(_ subviews: Subviews) -> CGFloat {
        let width = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        return width * CGFloat(columns) + CGFloat(columns - 1) * spacing
    }

    private func rowHeights(at width: CGFloat, subviews: Subviews) -> [CGFloat] {
        stride(from: 0, to: subviews.count, by: columns).map { start in
            (start..<min(start + columns, subviews.count)).map {
                subviews[$0].sizeThatFits(ProposedViewSize(width: width, height: nil)).height
            }.max() ?? 0
        }
    }
}
#endif
