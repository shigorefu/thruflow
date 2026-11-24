#if os(macOS) || os(iOS)
import Charts
import SwiftUI

struct StatisticsDailyFocusCard: View {
    @Environment(\.statisticsFillsRow) private var fillsRow
    @Environment(\.locale) private var locale
    let points: [StatisticsDailyFocusPoint]
    let compact: Bool
    var plotHeight: CGFloat? = nil
    var expandsPlot = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 14) {
            Label(String(localized: "日ごとの集中時間"), systemImage: "chart.bar.fill")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if points.contains(where: { $0.focusSeconds > 0 }) {
                if points.count > 31 {
                    plot
                        .chartScrollableAxes(.horizontal)
                        .chartXVisibleDomain(length: 31.0)
                        .chartScrollPosition(initialX: Double(max(0, points.count - 31)))
                } else {
                    plot
                }
            } else {
                Text(String(localized: "この期間のデータはありません"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: compact ? 70 : 125)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: fillsRow ? .infinity : nil, alignment: .topLeading)
        .padding(compact ? 12 : 16)
        .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.08))
                .allowsHitTesting(false)
        }
    }

    private var plot: some View {
        let upperBound = yUpperBound
        return Chart {
            ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                RectangleMark(
                    xStart: .value(String(localized: "日"), Double(index) - 0.35),
                    xEnd: .value(String(localized: "日"), Double(index) + 0.35),
                    yStart: .value(String(localized: "集中時間"), 0.0),
                    yEnd: .value(String(localized: "集中時間"), Double(point.focusSeconds) / 60)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(3)
                .accessibilityLabel(point.date.formatted(.dateTime.locale(locale).month().day()))
                .accessibilityValue(Duration.seconds(point.focusSeconds).formatted(.units(allowed: [.hours, .minutes, .seconds])))
            }
        }
        .chartXScale(domain: -0.5...max(0.5, Double(points.count) - 0.5))
        .chartYScale(domain: 0...upperBound)
        .chartXAxis {
            AxisMarks(values: axisIndexes.map(Double.init)) { value in
                AxisValueLabel {
                    if let index = value.as(Double.self).map({ Int($0) }), points.indices.contains(index) {
                        let date = points[index].date
                        Text(points.count <= 7
                            ? date.formatted(.dateTime.locale(locale).weekday(.narrow))
                            : date.formatted(.dateTime.locale(locale).month(.defaultDigits).day()))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yAxisValues(upperBound: upperBound)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text(String(localized: "\(Int(minutes))分"))
                    }
                }
            }
        }
        .frame(
            minHeight: plotHeight ?? (compact ? 113 : 190),
            idealHeight: plotHeight ?? (compact ? 113 : 190),
            maxHeight: expandsPlot ? .infinity : (plotHeight ?? (compact ? 113 : 190))
        )
    }

    private var yUpperBound: Double {
        let maximumMinutes = points.map { Double($0.focusSeconds) / 60 }.max() ?? 0
        let paddedMaximum = max(2, maximumMinutes + maximumMinutes / 10)
        let quantum = max(1, pow(10, floor(log10(paddedMaximum)) - 1))
        return ceil(paddedMaximum / quantum) * quantum
    }

    private func yAxisValues(upperBound: Double) -> [Double] {
        let intervals = compact ? 2 : 4
        return Array(Set((0...intervals).map {
            (Double($0) * upperBound / Double(intervals)).rounded()
        })).sorted()
    }

    private var axisIndexes: [Int] {
        guard points.count > 7 else { return Array(points.indices) }
        return Array(stride(from: 0, to: points.count, by: points.count > 31 ? 7 : max(2, points.count / 5)))
    }
}
#endif
