import SwiftUI

/// All durations share a zero edge and the same full-day focus total.
struct DashboardDistributionBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(Color.primary.opacity(0.08))
                .overlay(alignment: .trailing) {
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * min(max(fraction, 0), 1))
                }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

/// Labels the full width of the common right-to-left baseline.
struct DashboardDistributionScale: View {
    let total: String

    var body: some View {
        HStack {
            Text(total)
            Spacer()
            Text(0, format: .number)
        }
        .font(.caption2)
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
}
