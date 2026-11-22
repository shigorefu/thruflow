#if os(macOS)
import Charts
import SwiftUI

/// Current-period focus per Area or Project; aggregate comparison remains in StatisticsTrendPlot.
struct StatisticsGroupedTrendPlot: View {
    @Environment(\.locale) private var locale
    let series: [StatisticsGroupedTrendSeries]
    let period: StatisticsPeriod
    let today: Date
    let distinguishesProjects: Bool
    let legendOnRight: Bool
    let expandsPlot: Bool
    @State private var selectedIndex: Int?
    @State private var hoveredSeriesID: String?

    private var points: [StatisticsGroupedTrendPoint] { series.first?.points ?? [] }
    private var selectedPoint: StatisticsGroupedTrendPoint? {
        points.first { $0.index == selectedIndex && $0.date <= today }
    }

    var body: some View {
        if series.isEmpty {
            StatisticsEmptyState(label: String(localized: "この期間の集中記録はありません"))
                .frame(maxWidth: .infinity, minHeight: 280)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                let layout = legendOnRight
                    ? AnyLayout(HStackLayout(alignment: .top, spacing: 16))
                    : AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                layout {
                    chart
                    legend
                        .frame(width: legendOnRight ? 135 : nil, alignment: .leading)
                }
                Group {
                    if let selectedPoint {
                        Text(selectedPoint.date.formatted(period == .year
                            ? .dateTime.locale(locale).year().month()
                            : .dateTime.locale(locale).year().month().day()))
                            .fontWeight(.semibold)
                    } else {
                        Text(String(localized: "グラフにポインタを合わせると、記録の詳細を確認できます。"))
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 26, alignment: .topLeading)
            }
            .onChange(of: series) { _, _ in
                selectedIndex = nil
                hoveredSeriesID = nil
            }
            .onDisappear {
                selectedIndex = nil
                hoveredSeriesID = nil
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(series) { group in
                ForEach(group.points) { point in
                    if point.date <= today {
                        LineMark(
                            x: .value(String(localized: "日"), point.index),
                            y: .value(String(localized: "集中時間"), Double(point.focusSeconds) / 60),
                            series: .value(String(localized: "内訳"), group.id)
                        )
                        .foregroundStyle(displayColor(for: group))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.linear)
                        .accessibilityLabel(group.name + ", " + point.date.formatted(.dateTime.locale(locale).year().month().day()))
                        .accessibilityValue(String(localized: "\(point.focusSeconds / 60)分"))
                        PointMark(
                            x: .value(String(localized: "日"), point.index),
                            y: .value(String(localized: "集中時間"), Double(point.focusSeconds) / 60)
                        )
                        .foregroundStyle(displayColor(for: group))
                        .symbolSize(18)
                        .accessibilityLabel(group.name + ", " + point.date.formatted(.dateTime.locale(locale).year().month().day()))
                        .accessibilityValue(String(localized: "\(point.focusSeconds / 60)分"))
                    }
                }
            }
            if let selectedPoint {
                RuleMark(x: .value(String(localized: "日"), selectedPoint.index))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .accessibilityHidden(true)
            }
        }
        .chartLegend(.hidden)
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
                    if let raw = value.as(Int.self) { Text(String(localized: "\(raw)分")) }
                }
            }
        }
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
        .frame(minWidth: 220, minHeight: 240, idealHeight: 240, maxHeight: expandsPlot ? .infinity : 240)
    }

    private var legend: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(series) { group in
                    HStack(alignment: .top, spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(displayColor(for: group))
                            .frame(width: 14, height: 3)
                            .padding(.top, 5)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text([group.symbol, group.name].compactMap { $0 }.joined(separator: " "))
                                .lineLimit(2)
                                .help(group.name)
                            Text(StatisticsFormatting.duration(displaySeconds(for: group)))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                    .onHover { isHovering in
                        if isHovering {
                            hoveredSeriesID = group.id
                        } else if hoveredSeriesID == group.id {
                            hoveredSeriesID = nil
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.trailing, 3)
        }
        .font(.caption)
        .frame(height: legendOnRight ? 240 : min(180, CGFloat(series.count) * 44))
        .onHover { isHovering in
            if !isHovering { hoveredSeriesID = nil }
        }
    }

    private func displaySeconds(for group: StatisticsGroupedTrendSeries) -> Int {
        guard let selectedPoint else { return group.totalFocusSeconds }
        return group.points.first { $0.index == selectedPoint.index }?.focusSeconds ?? 0
    }

    private func displayColor(for group: StatisticsGroupedTrendSeries) -> Color {
        if let hoveredSeriesID, hoveredSeriesID != group.id { return .gray.opacity(0.45) }
        return color(for: group)
    }

    private func color(for group: StatisticsGroupedTrendSeries) -> Color {
        guard distinguishesProjects, group.id != "project:unassigned" else {
            return Color(hex: group.colorHex ?? "#8E8E93")
        }
        // Swift's Hasher changes between launches; an explicit hash keeps Project colors stable.
        let hash = group.id.utf8.reduce(UInt64(14_695_981_039_346_656_037)) {
            ($0 ^ UInt64($1)) &* 1_099_511_628_211
        }
        return Color(hue: Double(hash % 360) / 360, saturation: 0.68, brightness: 0.82)
    }

    private var axisIndexes: [Int] {
        guard !points.isEmpty else { return [] }
        let step = max(1, Int(ceil(Double(points.count - 1) / 4)))
        var values = Array(stride(from: 0, to: points.count, by: step))
        if let last = points.indices.last, values.last != last {
            if let previous = values.last, last - previous < max(1, step / 2) { values.removeLast() }
            values.append(last)
        }
        return values
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
