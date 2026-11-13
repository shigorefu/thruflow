#if os(macOS) || os(iOS)
import Charts
import SwiftUI

struct StatisticsDailyFocusCard: View {
    @Environment(\.locale) private var locale
    let points: [StatisticsDailyFocusPoint]
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 14) {
            Label("日ごとの集中時間", systemImage: "chart.bar.fill")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if points.contains(where: { $0.focusSeconds > 0 }) {
                if points.count > 31 {
                    plot
                        .chartScrollableAxes(.horizontal)
                        .chartXVisibleDomain(length: 31)
                        .chartScrollPosition(initialX: max(0, points.count - 31))
                } else {
                    plot
                }
            } else {
                Text("この期間のデータはありません")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: compact ? 70 : 125)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 12 : 16)
        .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.08))
                .allowsHitTesting(false)
        }
    }

    private var plot: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                BarMark(
                    x: .value(String(localized: "日"), index),
                    y: .value(String(localized: "集中時間"), Double(point.focusSeconds) / 60)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(3)
                .accessibilityLabel(point.date.formatted(.dateTime.locale(locale).month().day()))
                .accessibilityValue(Duration.seconds(point.focusSeconds).formatted(.units(allowed: [.hours, .minutes, .seconds])))
            }
        }
        .chartXScale(domain: -0.5...max(0.5, Double(points.count) - 0.5))
        .chartXAxis {
            AxisMarks(values: axisIndexes) { value in
                AxisValueLabel {
                    if let index = value.as(Int.self), points.indices.contains(index) {
                        let date = points[index].date
                        Text(points.count <= 7
                            ? date.formatted(.dateTime.locale(locale).weekday(.narrow))
                            : date.formatted(.dateTime.locale(locale).month(.defaultDigits).day()))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: compact ? 3 : 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text(String(localized: "\(Int(minutes))分"))
                    }
                }
            }
        }
        .frame(height: compact ? 113 : 190)
    }

    private var axisIndexes: [Int] {
        guard points.count > 7 else { return Array(points.indices) }
        return Array(stride(from: 0, to: points.count, by: points.count > 31 ? 7 : max(2, points.count / 5)))
    }
}
#endif
