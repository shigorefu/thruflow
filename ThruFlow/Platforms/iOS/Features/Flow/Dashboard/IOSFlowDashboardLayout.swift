#if os(iOS)
import SwiftUI

/// One hierarchy for both arrangements keeps card-local selection and presentation
/// state alive while a window or display changes its available width.
nonisolated struct IOSFlowDashboardLayout: Layout {
    var allowsColumns: Bool
    private let spacing: CGFloat = 16
    private let minimumColumnWidth: CGFloat = 360

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = max(0, proposal.width ?? minimumColumnWidth)
        let columns = columnCount(for: width)
        let cellWidth = max(0, (width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        let heights = rowHeights(subviews: subviews, width: cellWidth, columns: columns)
        return CGSize(width: width, height: heights.reduce(0, +) + spacing * CGFloat(max(0, heights.count - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columns = columnCount(for: bounds.width)
        let cellWidth = max(0, (bounds.width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        let heights = rowHeights(subviews: subviews, width: cellWidth, columns: columns)
        var y = bounds.minY
        for (row, height) in heights.enumerated() {
            for column in 0..<columns {
                let index = row * columns + column
                guard index < subviews.count else { break }
                subviews[index].place(
                    at: CGPoint(x: bounds.minX + CGFloat(column) * (cellWidth + spacing), y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: cellWidth, height: height)
                )
            }
            y += height + spacing
        }
    }

    private func columnCount(for width: CGFloat) -> Int {
        allowsColumns && width >= minimumColumnWidth * 2 + spacing ? 2 : 1
    }

    private func rowHeights(subviews: Subviews, width: CGFloat, columns: Int) -> [CGFloat] {
        stride(from: 0, to: subviews.count, by: columns).map { start in
            (start..<min(start + columns, subviews.count)).map {
                subviews[$0].sizeThatFits(ProposedViewSize(width: width, height: nil)).height
            }.max() ?? 0
        }
    }
}
#endif
