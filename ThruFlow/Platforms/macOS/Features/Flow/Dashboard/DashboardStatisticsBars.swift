#if os(macOS)
import SwiftData
import SwiftUI

struct DashboardStatisticsBars: View {
    let days: [DashboardStatisticsDay]

    var body: some View {
        GeometryReader { proxy in
            let maximum = max(days.map(\.focusSeconds).max() ?? 0, 1)

            HStack(alignment: .bottom, spacing: 7) {
                ForEach(days) { day in
                    let minimumHeight: CGFloat = day.focusSeconds > 0 ? 4 : 2
                    let availableHeight = max(proxy.size.height - 23, 0)
                    let proportionalHeight = availableHeight * CGFloat(day.focusSeconds) / CGFloat(maximum)
                    let barHeight = max(minimumHeight, proportionalHeight)

                    VStack(spacing: 5) {
                        Spacer(minLength: 0)
                        Capsule()
                            .fill(Color(hex: day.colorHex))
                            .frame(width: 7, height: barHeight)
                        Text(dayLabel(day.date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(dayAccessibilityLabel(day))
                }
            }
        }
    }

    private func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.day())
    }

    private func dayAccessibilityLabel(_ day: DashboardStatisticsDay) -> String {
        let minutes = day.focusSeconds / 60
        return String(localized: "\(day.date.formatted(date: .abbreviated, time: .omitted))、\(minutes)分")
    }
}
#endif
