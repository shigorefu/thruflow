#if os(macOS) || os(iOS)
import Charts
import SwiftUI

/// Shared chart marks and selection; platform cards retain their native layout.
struct StatisticsTrendPlot: View {
    @Environment(\.locale) private var locale
    let mode: StatisticsMode
    let period: StatisticsPeriod
    let points: [StatisticsTrendPoint]
    let today: Date
    let height: CGFloat
    @State private var selectedIndex: Int?

    private var selectedPoint: StatisticsTrendPoint? {
        points.first { $0.index == selectedIndex && $0.date <= today }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                legend
                legend.font(.caption2)
                VStack(alignment: .leading, spacing: 4) {
                    Label(String(localized: "選択した期間"), systemImage: "minus").foregroundStyle(Color.accentColor)
                    Label(averageLabel, systemImage: "waveform.path").foregroundStyle(Color.orange)
                    Label(String(localized: "前の期間"), systemImage: "ellipsis").foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            Chart {
                ForEach(points) { point in
                    if point.hasComparison && point.comparisonDate <= today {
                        LineMark(x: .value(String(localized: "日"), point.index), y: .value(String(localized: "前の期間"), previousValue(point)),
                                 series: .value(String(localized: "期間"), String(localized: "前の期間")))
                            .foregroundStyle(Color.secondary.opacity(0.55))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .interpolationMethod(.linear)
                    }
                    if point.date <= today {
                        LineMark(x: .value(String(localized: "日"), point.index), y: .value(String(localized: "選択した期間"), currentValue(point)),
                                 series: .value(String(localized: "期間"), String(localized: "選択した期間")))
                            .foregroundStyle(Color.accentColor)
                            .lineStyle(StrokeStyle(lineWidth: 2.2))
                            .interpolationMethod(.linear)
                        PointMark(x: .value(String(localized: "日"), point.index), y: .value(String(localized: "選択した期間"), currentValue(point)))
                            .foregroundStyle(Color.accentColor)
                            .symbolSize(22)
                    }
                }
                ForEach(StatisticsTrendSmoothing.build(points: points, period: period, today: today)) { point in
                    LineMark(x: .value(String(localized: "日"), point.index), y: .value(averageLabel, mode == .flow ? point.focusMinutes : point.completedTasks),
                             series: .value(String(localized: "期間"), averageLabel))
                        .foregroundStyle(Color.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 3, 2, 3]))
                        .interpolationMethod(.linear)
                }
                if let selectedPoint {
                    RuleMark(x: .value(String(localized: "日"), selectedPoint.index))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .accessibilityHidden(true)
                }
            }
            .chartXScale(domain: 0...max(1, points.count - 1), range: .plotDimension(padding: 12))
            .chartYScale(range: .plotDimension(padding: 8))
            .chartXSelection(value: $selectedIndex)
            .chartXAxis {
                AxisMarks(values: axisIndexes) { value in
                    AxisGridLine()
                    AxisValueLabel(anchor: .top) {
                        if let index = value.as(Int.self), points.indices.contains(index) {
                            Text(axisLabel(points[index].date)).fixedSize()
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let raw = value.as(Int.self) {
                            Text(mode == .flow ? String(localized: "\(raw)分") : "\(raw)")
                        }
                    }
                }
            }
            #if os(macOS)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Color.clear.contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                guard let frame = proxy.plotFrame else { return }
                                let plot = geometry[frame]
                                guard plot.contains(location) else { selectedIndex = nil; return }
                                let value: Double? = proxy.value(atX: location.x - plot.minX)
                                selectedIndex = value.map { Int($0.rounded()) }
                            case .ended: selectedIndex = nil
                            }
                        }
                }
            }
            #else
            .chartGesture { proxy in
                SpatialTapGesture().onEnded { value in
                    proxy.selectXValue(at: value.location.x)
                }
            }
            #endif
            .frame(height: height)

            VStack(alignment: .leading, spacing: 4) {
                if let selectedPoint {
                    Text(selectedPoint.date.formatted(period == .year
                        ? .dateTime.locale(locale).year().month()
                        : .dateTime.locale(locale).year().month().day()))
                        .font(.caption.weight(.semibold))
                    HStack(spacing: 16) {
                        Text(String(localized: "集中時間") + ": " + String(localized: "\(selectedPoint.focusSeconds / 60)分"))
                        Text(String(localized: "完了タスク") + ": \(selectedPoint.completedTaskCount)")
                    }
                    .font(.caption)
                } else {
                    #if os(macOS)
                    Text(String(localized: "グラフにポインタを合わせると、記録の詳細を確認できます。"))
                        .font(.caption).foregroundStyle(.secondary)
                    #else
                    Text(String(localized: "グラフをタップすると、記録の詳細を確認できます。"))
                        .font(.caption).foregroundStyle(.secondary)
                    #endif
                }
            }
            .frame(height: 42, alignment: .topLeading)
        }
        .onChange(of: points) { _, _ in selectedIndex = nil }
    }

    private var averageLabel: String {
        period == .year ? String(localized: "3か月平均") : String(localized: "7日平均")
    }

    private var legend: some View {
        HStack(spacing: 12) {
            Label(String(localized: "選択した期間"), systemImage: "minus").foregroundStyle(Color.accentColor)
            Label(averageLabel, systemImage: "waveform.path").foregroundStyle(Color.orange)
            Label(String(localized: "前の期間"), systemImage: "ellipsis").foregroundStyle(.secondary)
        }
    }

    private var axisIndexes: [Int] {
        guard !points.isEmpty else { return [] }
        #if os(macOS)
        let maximumLabels = 7
        #else
        let maximumLabels = 5
        #endif
        let step = max(1, Int(ceil(Double(points.count - 1) / Double(maximumLabels - 1))))
        var values = Array(stride(from: 0, to: points.count, by: step))
        if let last = points.indices.last, values.last != last {
            if let previous = values.last, last - previous < max(1, step / 2) { values.removeLast() }
            values.append(last)
        }
        return values
    }

    private func currentValue(_ point: StatisticsTrendPoint) -> Double {
        mode == .flow ? Double(point.focusSeconds) / 60 : Double(point.completedTaskCount)
    }
    private func previousValue(_ point: StatisticsTrendPoint) -> Double {
        mode == .flow ? Double(point.previousFocusSeconds) / 60 : Double(point.previousCompletedTaskCount)
    }
    private func axisLabel(_ date: Date) -> String {
        switch period {
        case .week: date.formatted(.dateTime.locale(locale).weekday(.narrow))
        case .month: date.formatted(.dateTime.locale(locale).day())
        case .year: date.formatted(.dateTime.locale(locale).month(.abbreviated))
        }
    }
}
#endif
