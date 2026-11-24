import SwiftUI

/// Presentation scale for the dashboard's ranked duration rows. The donut keeps
/// its independent full-day denominator.
nonisolated struct DashboardDistributionBarScale {
    let maximumFocusSeconds: Int

    init(focusSeconds: [Int]) {
        maximumFocusSeconds = max(focusSeconds.max() ?? 0, 0)
    }

    func fraction(for focusSeconds: Int) -> Double {
        guard maximumFocusSeconds > 0 else { return 0 }
        return min(max(Double(focusSeconds) / Double(maximumFocusSeconds), 0), 1)
    }
}

/// All ranked durations share a zero edge and the longest row's full width.
struct DashboardDistributionBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(Color.primary.opacity(0.08))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * min(max(fraction, 0), 1))
                }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

/// Labels the common left-hand zero edge and the longest duration on the right.
struct DashboardDistributionScale: View {
    let maximum: String

    var body: some View {
        HStack {
            Text(0, format: .number)
            Spacer()
            Text(maximum)
        }
        .font(.caption2)
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
}
