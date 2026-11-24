#if os(iOS)
import SwiftUI

struct IOSStatisticsDotsCard: View {
    @Environment(\.calendar) private var calendar

    @Binding var mode: StatisticsMode
    let period: StatisticsPeriod
    let marksOutsideMonth: Bool
    let usesCustomRange: Bool
    let flowDays: [StatisticsDay]
    let achievementDays: [AchievementDay]
    let maximumInteractiveDate: Date
    var compact = false
    let onSelectDay: (IOSStatisticsContributionDay) -> Void

    private var days: [IOSStatisticsContributionDay] {
        let achievementByDate = Dictionary(
            uniqueKeysWithValues: achievementDays.map { ($0.date, $0) }
        )
        return flowDays.map { flowDay in
            let achievement = achievementByDate[flowDay.date]
            return IOSStatisticsContributionDay(
                date: flowDay.date,
                value: mode == .flow ? flowDay.totalFocusSeconds : achievement?.completedCount ?? 0,
                colorHex: mode == .flow ? flowDay.mixedColorHex : achievement?.mixedColorHex,
                focusedSeconds: flowDay.totalFocusSeconds,
                flowCount: flowDay.sessionCount,
                completedTaskCount: achievement?.completedCount ?? 0,
                isSelectable: flowDay.date <= maximumInteractiveDate
            )
        }
    }

    private var maxValue: Int {
        max(1, days.map(\.value).max() ?? 1)
    }

    private var paddedDays: [IOSStatisticsContributionDay?] {
        guard let first = days.first else { return [] }
        if marksOutsideMonth {
            return StatisticsMonthGridPadding(
                dates: days.map(\.date),
                calendar: calendar
            ).padding(days)
        }
        let weekday = calendar.component(.weekday, from: first.date)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + days.map(Optional.some)
    }

    var body: some View {
        IOSStatisticsCard(
            title: String(localized: "Dots"),
            subtitle: mode == .flow ? String(localized: "集中時間") : String(localized: "完了タスク"),
            compact: compact,
            headerAccessory: {
                IOSStatisticsModePicker(selection: $mode)
            }
        ) {
            if days.isEmpty {
                IOSStatisticsEmptyState()
                    .frame(maxWidth: .infinity, minHeight: compact ? 80 : 120)
            } else {
                VStack(alignment: .leading, spacing: compact ? 6 : 12) {
                    if usesCustomRange {
                        customGrid
                    } else {
                        switch period {
                        case .week:
                            weekGrid
                        case .month:
                            monthGrid
                        case .year:
                            IOSStatisticsYearGrid(
                                paddedDays: paddedDays,
                                hidesPlaceholders: usesCustomRange,
                                maxValue: maxValue,
                                onSelectDay: onSelectDay
                            )
                        }

                        HStack(spacing: 5) {
                            Text(String(localized: "少ない"))
                            ForEach(0..<5, id: \.self) { level in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(level == 0
                                        ? Color.secondary.opacity(0.12)
                                        : Color.accentColor.opacity(0.24 + Double(level) * 0.17))
                                    .frame(width: compact ? 9 : 12, height: compact ? 9 : 12)
                            }
                            Text(String(localized: "多い"))
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .id(mode)
        .transition(.opacity.combined(with: .scale(scale: 0.99)))
        .animation(.easeInOut(duration: 0.2), value: mode)
    }

    private var customGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 18, maximum: 18), spacing: 5)], alignment: .leading, spacing: 5) {
            ForEach(days) { day in
                IOSStatisticsContributionCell(day: day, maxValue: maxValue, onSelectDay: onSelectDay)
                    .frame(width: 18, height: 18)
            }
        }
    }

    private var weekGrid: some View {
        HStack(alignment: .top, spacing: compact ? 4 : 6) {
            ForEach(days) { day in
                VStack(spacing: compact ? 3 : 6) {
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    IOSStatisticsContributionCell(
                        day: day,
                        maxValue: maxValue,
                        onSelectDay: onSelectDay
                    )
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: compact ? 24 : .infinity)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let spacing: CGFloat = compact ? 3 : 6
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: 7)
        return LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(CalendarWeekdaySymbols.orderedAbbreviated(calendar: calendar), id: \.self) { weekday in
                Text(weekday)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(paddedDays.enumerated()), id: \.offset) { _, day in
                IOSStatisticsContributionCell(
                    day: day,
                    maxValue: maxValue,
                    marksOutsidePeriod: marksOutsideMonth && day == nil,
                    hidesPlaceholder: usesCustomRange,
                    onSelectDay: onSelectDay
                )
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: compact ? 14 : .infinity)
            }
        }
        .frame(maxWidth: compact ? 7 * 24 + 6 * spacing : .infinity)
    }
}

private struct IOSStatisticsContributionCell: View {
    let day: IOSStatisticsContributionDay?
    let maxValue: Int
    var marksOutsidePeriod = false
    var hidesPlaceholder = false
    let onSelectDay: (IOSStatisticsContributionDay) -> Void

    var body: some View {
        Button {
            if let day, day.isSelectable {
                onSelectDay(day)
            }
        } label: {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(IOSStatisticsDotColor.fill(for: day, maxValue: maxValue))
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.055))
                }
                .overlay {
                    if marksOutsidePeriod {
                        GeometryReader { geometry in
                            Path { path in
                                path.move(to: CGPoint(x: 4, y: geometry.size.height - 4))
                                path.addLine(to: CGPoint(x: geometry.size.width - 4, y: 4))
                            }
                            .stroke(
                                Color.secondary.opacity(0.42),
                                style: StrokeStyle(lineWidth: 1, lineCap: .round)
                            )
                        }
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(day?.isSelectable != true)
        .opacity(hidesPlaceholder && day == nil ? 0 : 1)
        .accessibilityHidden(hidesPlaceholder && day == nil)
        .accessibilityLabel(day?.accessibilityLabel ?? "")
        .accessibilityHint(String(localized: "選択"))
    }
}

private struct IOSStatisticsYearGrid: View {
    let paddedDays: [IOSStatisticsContributionDay?]
    let hidesPlaceholders: Bool
    let maxValue: Int
    let onSelectDay: (IOSStatisticsContributionDay) -> Void

    var body: some View {
        GeometryReader { geometry in
            let layout = layout(for: geometry.size)
            Canvas { context, _ in
                for (index, day) in paddedDays.enumerated() {
                    if hidesPlaceholders && day == nil { continue }
                    let rect = layout.rect(for: index)
                    let path = Path(
                        roundedRect: rect,
                        cornerRadius: min(2, layout.cellSize * 0.28)
                    )
                    context.fill(
                        path,
                        with: .color(IOSStatisticsDotColor.fill(for: day, maxValue: maxValue))
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard let index = paddedDays.indices.first(where: { layout.rect(for: $0).contains(location) }),
                      let day = paddedDays[index], day.isSelectable else { return }
                onSelectDay(day)
            }
        }
        .frame(height: 58)
        .accessibilityLabel(String(localized: "Dots"))
        .accessibilityChildren {
            ForEach(paddedDays.compactMap { $0 }.filter(\.isSelectable)) { day in
                Button(day.accessibilityLabel) { onSelectDay(day) }
            }
        }
    }

    private func layout(for size: CGSize) -> IOSStatisticsYearGridLayout {
        IOSStatisticsYearGridLayout(
            size: size,
            weekCount: max(1, Int(ceil(Double(paddedDays.count) / 7)))
        )
    }
}

private struct IOSStatisticsYearGridLayout {
    let cellSize: CGFloat
    let spacing: CGFloat
    let origin: CGPoint
    let weekCount: Int

    init(size: CGSize, weekCount: Int) {
        self.weekCount = weekCount
        spacing = 1.2
        let horizontal = (size.width - CGFloat(max(0, weekCount - 1)) * spacing) / CGFloat(weekCount)
        let vertical = (size.height - 6 * spacing) / 7
        cellSize = max(1, min(horizontal, vertical))
        let contentWidth = CGFloat(weekCount) * cellSize + CGFloat(max(0, weekCount - 1)) * spacing
        let contentHeight = 7 * cellSize + 6 * spacing
        origin = CGPoint(
            x: max(0, (size.width - contentWidth) / 2),
            y: max(0, (size.height - contentHeight) / 2)
        )
    }

    func rect(for index: Int) -> CGRect {
        let week = index / 7
        let weekday = index % 7
        return CGRect(
            x: origin.x + CGFloat(week) * (cellSize + spacing),
            y: origin.y + CGFloat(weekday) * (cellSize + spacing),
            width: cellSize,
            height: cellSize
        )
    }

}

private enum IOSStatisticsDotColor {
    static func fill(
        for day: IOSStatisticsContributionDay?,
        maxValue: Int
    ) -> Color {
        guard let day, day.value > 0 else {
            return Color.secondary.opacity(0.12)
        }
        let fraction = Double(day.value) / Double(max(1, maxValue))
        let level = max(1, min(4, Int(ceil(fraction * 4))))
        return Color(hex: day.colorHex ?? "#34C759")
            .opacity(0.28 + Double(level) * 0.16)
    }
}

struct IOSStatisticsContributionDay: Identifiable {
    let date: Date
    let value: Int
    let colorHex: String?
    let focusedSeconds: Int
    let flowCount: Int
    let completedTaskCount: Int
    let isSelectable: Bool

    var id: Date { date }

    var accessibilityLabel: String {
        let formattedDate = date.formatted(date: .abbreviated, time: .omitted)
        let duration = IOSStatisticsFormatting.duration(focusedSeconds)
        return String(
            localized: "\(formattedDate)：集中時間\(duration)、集中\(flowCount)回、完了タスク\(completedTaskCount)件"
        )
    }
}
#endif
