import SwiftUI
import WidgetKit

struct FlowDotsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: ProductWidgetSnapshotStore.dotsWidgetKind,
            provider: FlowDotsWidgetProvider()
        ) { entry in
            FlowDotsWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.accentColor.opacity(0.04)
                }
                .widgetURL(URL(string: "thruflow://statistics"))
        }
        .configurationDisplayName(String(localized: "Flow Dots"))
        .description(String(localized: "Flowの積み重ねを月または180日で確認できます。"))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct FlowDotsWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: DotsWidgetSnapshot
}

private struct FlowDotsWidgetProvider: TimelineProvider {
    private let snapshots = ProductWidgetSnapshotStore()

    func placeholder(in context: Context) -> FlowDotsWidgetEntry {
        FlowDotsWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (FlowDotsWidgetEntry) -> Void
    ) {
        completion(
            FlowDotsWidgetEntry(
                date: .now,
                snapshot: context.isPreview ? .placeholder : snapshots.loadDots() ?? .empty
            )
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<FlowDotsWidgetEntry>) -> Void
    ) {
        let now = Date.now
        let entry = FlowDotsWidgetEntry(
            date: now,
            snapshot: snapshots.loadDots() ?? .empty
        )
        let nextDay = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: now)
        ) ?? now.addingTimeInterval(86_400)
        completion(Timeline(entries: [entry], policy: .after(nextDay)))
    }
}

private struct FlowDotsWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: FlowDotsWidgetEntry

    var body: some View {
        switch family {
        case .systemLarge:
            Days180DotsView(snapshot: entry.snapshot)
        default:
            MonthDotsView(snapshot: entry.snapshot, date: entry.date)
        }
    }
}

private struct MonthDotsView: View {
    let snapshot: DotsWidgetSnapshot
    let date: Date

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(String(localized: "Flow Dots"), systemImage: "circle.grid.3x3.fill")
                    .font(.headline)
                Spacer()
                Text(date.formatted(.dateTime.year().month(.wide)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        VStack(spacing: 2) {
                            Text("\(calendar.component(.day, from: day.date))")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                            DotCell(day: day, maximumSeconds: maximumSeconds)
                                .frame(width: 13, height: 13)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Color.clear
                            .frame(height: 27)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var monthCells: [DotsWidgetDaySnapshot?] {
        let month = calendar.dateInterval(of: .month, for: date)
        let days = snapshot.days.filter { day in
            guard let month else { return false }
            return month.contains(day.date)
        }
        guard let first = days.first else { return [] }
        let weekday = calendar.component(.weekday, from: first.date)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + days.map(Optional.some)
    }

    private var maximumSeconds: Int {
        max(1, monthCells.compactMap { $0?.focusedSeconds }.max() ?? 1)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = max(0, calendar.firstWeekday - 1)
        return Array(symbols[offset...] + symbols[..<offset])
    }
}

private struct Days180DotsView: View {
    let snapshot: DotsWidgetSnapshot

    private let calendar = Calendar.current
    private let rows = Array(repeating: GridItem(.fixed(10), spacing: 3), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(String(localized: "Flow Dots"), systemImage: "circle.grid.3x3.fill")
                    .font(.headline)
                Spacer()
                Text(String(localized: "過去180日"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 7) {
                VStack(spacing: 3) {
                    ForEach(rotatedWeekdaySymbols.indices, id: \.self) { index in
                        Text(index.isMultiple(of: 2) ? rotatedWeekdaySymbols[index] : "")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .frame(width: 12, height: 10)
                    }
                }

                LazyHGrid(rows: rows, spacing: 3) {
                    ForEach(Array(paddedDays.enumerated()), id: \.offset) { _, day in
                        if let day {
                            DotCell(day: day, maximumSeconds: maximumSeconds)
                                .frame(width: 10, height: 10)
                        } else {
                            Color.clear
                                .frame(width: 10, height: 10)
                        }
                    }
                }
            }

            HStack {
                Text(totalFocusText)
                    .font(.title3.monospacedDigit().weight(.semibold))
                Text(String(localized: "集中時間"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                intensityLegend
            }

            Spacer(minLength: 0)
        }
    }

    private var paddedDays: [DotsWidgetDaySnapshot?] {
        guard let first = snapshot.days.first else { return [] }
        let weekday = calendar.component(.weekday, from: first.date)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + snapshot.days.map(Optional.some)
    }

    private var maximumSeconds: Int {
        max(1, snapshot.days.map(\.focusedSeconds).max() ?? 1)
    }

    private var rotatedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = max(0, calendar.firstWeekday - 1)
        return Array(symbols[offset...] + symbols[..<offset])
    }

    private var totalFocusText: String {
        let minutes = snapshot.days.reduce(0) { $0 + $1.focusedSeconds } / 60
        if minutes >= 60 {
            return "\(minutes / 60)\(String(localized: "時間")) \(minutes % 60)\(String(localized: "分"))"
        }
        return "\(minutes)\(String(localized: "分"))"
    }

    private var intensityLegend: some View {
        HStack(spacing: 3) {
            Text(String(localized: "少ない"))
            ForEach(1...4, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.2 + 0.2 * Double(level)))
                    .frame(width: 10, height: 10)
            }
            Text(String(localized: "多い"))
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

private struct DotCell: View {
    let day: DotsWidgetDaySnapshot
    let maximumSeconds: Int

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .accessibilityLabel(
                "\(day.date.formatted(date: .abbreviated, time: .omitted)), \(day.focusedSeconds / 60) \(String(localized: "分"))"
            )
    }

    private var color: Color {
        guard day.focusedSeconds > 0 else {
            return Color.primary.opacity(0.07)
        }
        let intensity = 0.28 + 0.72 * Double(day.focusedSeconds) / Double(maximumSeconds)
        return Color(productHex: day.mixedColorHex ?? "#007AFF").opacity(intensity)
    }
}

private extension DotsWidgetSnapshot {
    static let empty = DotsWidgetSnapshot(generatedAt: .now, days: [])

    static var placeholder: DotsWidgetSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let colors = ["#007AFF", "#34C759", "#AF52DE"]
        let days = (0..<180).compactMap { offset -> DotsWidgetDaySnapshot? in
            guard let date = calendar.date(byAdding: .day, value: offset - 179, to: today) else {
                return nil
            }
            let active = offset % 5 != 0 && offset % 7 != 0
            return DotsWidgetDaySnapshot(
                date: date,
                focusedSeconds: active ? ((offset % 4) + 1) * 12 * 60 : 0,
                mixedColorHex: active ? colors[offset % colors.count] : nil
            )
        }
        return DotsWidgetSnapshot(generatedAt: .now, days: days)
    }
}
