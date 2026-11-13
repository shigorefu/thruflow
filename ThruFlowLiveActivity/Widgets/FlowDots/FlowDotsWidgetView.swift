import Foundation
import SwiftUI
import WidgetKit

struct FlowDotsWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: FlowDotsWidgetEntry

    var body: some View {
        FlowDotsGrid(
            snapshot: entry.snapshot,
            endDate: entry.date,
            dayCount: dayCount,
            rowCount: rowCount,
            spacing: spacing
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Flow Dots"))
    }

    private var dayCount: Int {
        switch family {
        case .systemSmall:
            30
        case .systemLarge:
            90
        default:
            60
        }
    }

    private var spacing: CGFloat {
        switch family {
        case .systemSmall:
            5
        case .systemLarge:
            6
        default:
            5
        }
    }

    private var rowCount: Int {
        switch family {
        case .systemMedium:
            5
        case .systemLarge:
            10
        default:
            6
        }
    }
}

private struct FlowDotsGrid: View {
    let snapshot: DotsWidgetSnapshot
    let endDate: Date
    let dayCount: Int
    let rowCount: Int
    let spacing: CGFloat

    private let calendar = Calendar.current

    var body: some View {
        GeometryReader { proxy in
            let days = visibleDays
            let maximumSeconds = max(1, days.map(\.focusedSeconds).max() ?? 1)
            let metrics = GridMetrics(
                size: proxy.size,
                columnCount: max(1, dayCount / rowCount),
                rowCount: rowCount,
                spacing: spacing
            )

            HStack(spacing: spacing) {
                ForEach(0..<metrics.columnCount, id: \.self) { column in
                    VStack(spacing: spacing) {
                        ForEach(0..<metrics.rowCount, id: \.self) { row in
                            let day = days[column * metrics.rowCount + row]
                            DotCell(
                                day: day,
                                maximumSeconds: maximumSeconds,
                                cornerRadius: metrics.cornerRadius
                            )
                            .frame(
                                width: metrics.cellWidth,
                                height: metrics.cellHeight
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var visibleDays: [DotsWidgetDaySnapshot] {
        let normalizedEndDate = calendar.startOfDay(
            for: snapshot.days.last?.date ?? endDate
        )
        let daysByDate = Dictionary(
            snapshot.days.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { _, latest in latest }
        )

        return (0..<dayCount).compactMap { index in
            guard let date = calendar.date(
                byAdding: .day,
                value: index - dayCount + 1,
                to: normalizedEndDate
            ) else {
                return nil
            }
            return daysByDate[date] ?? DotsWidgetDaySnapshot(
                date: date,
                focusedSeconds: 0,
                mixedColorHex: nil
            )
        }
    }
}

private struct GridMetrics {
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let cornerRadius: CGFloat
    let columnCount: Int
    let rowCount: Int

    init(size: CGSize, columnCount: Int, rowCount: Int, spacing: CGFloat) {
        self.columnCount = columnCount
        self.rowCount = rowCount
        cellWidth = max(
            1,
            (size.width - spacing * CGFloat(max(0, columnCount - 1))) /
                CGFloat(columnCount)
        )
        cellHeight = max(
            1,
            (size.height - spacing * CGFloat(max(0, rowCount - 1))) /
                CGFloat(rowCount)
        )
        cornerRadius = min(6, min(cellWidth, cellHeight) * 0.2)
    }
}

private struct DotCell: View {
    let day: DotsWidgetDaySnapshot
    let maximumSeconds: Int
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(color)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.04), lineWidth: 0.5)
            }
            .accessibilityLabel(
                "\(day.date.formatted(date: .abbreviated, time: .omitted)), \(day.focusedSeconds / 60) \(String(localized: "分"))"
            )
    }

    private var color: Color {
        guard day.focusedSeconds > 0 else {
            return Color.primary.opacity(0.07)
        }
        let ratio = Double(day.focusedSeconds) / Double(maximumSeconds)
        let intensity: Double
        switch ratio {
        case ..<0.25:
            intensity = 0.36
        case ..<0.5:
            intensity = 0.56
        case ..<0.75:
            intensity = 0.76
        default:
            intensity = 1
        }
        return Color(productHex: day.mixedColorHex ?? "#007AFF").opacity(intensity)
    }
}
