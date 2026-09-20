import SwiftUI

/// A row's share of today's focus, stacked from the right across all rows.
struct DashboardDistributionBar: View {
    let fraction: Double
    let precedingFraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let end = max(0, 1 - min(max(precedingFraction, 0), 1))
            let width = min(max(fraction, 0), end)
            Capsule()
                .fill(Color.primary.opacity(0.07))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * width)
                        .offset(x: proxy.size.width * (end - width))
                }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}
