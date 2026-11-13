#if os(macOS)
import SwiftUI

struct StatisticsDotsCard: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var mode: StatisticsMode
    let period: StatisticsPeriod
    let compact: Bool
    let availableWidth: CGFloat
    let usesCompactCustomGrid: Bool
    let usesCustomRange: Bool
    let marksOutsideMonth: Bool
    let flowDays: [StatisticsDay]
    let achievementDays: [AchievementDay]
    let maximumInteractiveDate: Date
    let onSelectDate: (Date) -> Void

    private var contributionDays: [StatisticsContributionDay] {
        let achievementByDate = Dictionary(uniqueKeysWithValues: achievementDays.map { ($0.date, $0) })
        return flowDays.map { flowDay in
            let achievement = achievementByDate[flowDay.date]
            return StatisticsContributionDay(
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

    var body: some View {
        StatisticsCard(
            title: String(localized: "Dots"),
            subtitle: mode == .flow ? String(localized: "集中時間") : String(localized: "完了タスク"),
            minimumHeight: period == .month && !usesCustomRange && !compact ? 288 : nil,
            compact: compact,
            headerAccessory: {
                StatisticsModePicker(selection: $mode, width: compact ? 108 : 180)
            }
        ) {
            StatisticsContributionGrid(
                days: contributionDays,
                period: period,
                compact: compact,
                availableWidth: max(0, availableWidth - (compact ? 20 : 32)),
                usesCompactCustomGrid: usesCompactCustomGrid,
                usesCustomRange: usesCustomRange,
                marksOutsideMonth: marksOutsideMonth,
                onSelectDate: onSelectDate
            )
            .id(mode)
            .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.99, anchor: .top)))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: mode)
        }
    }
}

struct StatisticsModePicker: View {
    @Binding var selection: StatisticsMode
    var width: CGFloat = 180

    var body: some View {
        Picker(String(localized: "統計表示"), selection: $selection) {
            Text(StatisticsMode.flow.displayName).tag(StatisticsMode.flow)
            Text(StatisticsMode.achievement.displayName).tag(StatisticsMode.achievement)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.small)
        .frame(width: width)
        .accessibilityLabel(String(localized: "統計表示"))
    }
}

private struct StatisticsContributionDay: Identifiable {
    let date: Date
    let value: Int
    let colorHex: String?
    let focusedSeconds: Int
    let flowCount: Int
    let completedTaskCount: Int
    let isSelectable: Bool

    var id: Date { date }
}

private struct StatisticsContributionGrid: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    let days: [StatisticsContributionDay]
    let period: StatisticsPeriod
    let compact: Bool
    let availableWidth: CGFloat
    let usesCompactCustomGrid: Bool
    let usesCustomRange: Bool
    let marksOutsideMonth: Bool
    let onSelectDate: (Date) -> Void

    private var maxValue: Int {
        max(1, days.map(\.value).max() ?? 1)
    }

    private var paddedDays: [StatisticsContributionDay?] {
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
        if days.isEmpty {
            StatisticsEmptyState(label: String(localized: "この期間のデータはありません"))
                .frame(maxWidth: .infinity, minHeight: compact ? 56 : 120)
        } else {
            VStack(alignment: .leading, spacing: compact ? 5 : 10) {
                if usesCustomRange {
                    customGrid
                } else {
                    switch period {
                    case .week:
                        weekGrid
                    case .month:
                        monthGrid
                    case .year:
                        yearGrid
                    }

                    HStack(spacing: 6) {
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

    private var customGrid: some View {
        let size: CGFloat = compact ? 14 : 18
        let spacing: CGFloat = compact ? 4 : 5
        return LazyVGrid(
            columns: [GridItem(.adaptive(minimum: size, maximum: size), spacing: spacing)],
            alignment: .leading,
            spacing: spacing
        ) {
            ForEach(days) { day in
                StatisticsContributionCell(day: day, maxValue: maxValue,
                    isInteractive: day.isSelectable, onSelectDate: onSelectDate)
                    .frame(width: size, height: size)
            }
        }
    }

    private var weekGrid: some View {
        let spacing: CGFloat = compact ? 4 : 7
        return HStack(alignment: .top, spacing: spacing) {
            ForEach(days) { day in
                VStack(spacing: spacing) {
                    Text(day.date.formatted(.dateTime.locale(locale).weekday(.narrow)))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)

                    StatisticsContributionCell(
                        day: day,
                        maxValue: maxValue,
                        isInteractive: day.isSelectable,
                        onSelectDate: onSelectDate
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: compact ? 22 : 42)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let spacing: CGFloat = compact ? 4 : (usesCompactCustomGrid ? 5 : 6)
        let cellSize: CGFloat = compact ? 16 : (usesCompactCustomGrid ? 18 : 24)
        let cellHeight: CGFloat = compact ? 16 : (usesCompactCustomGrid ? cellSize : 32)
        let column = usesCompactCustomGrid
            ? GridItem(.fixed(cellSize), spacing: spacing)
            : GridItem(.flexible(minimum: cellSize), spacing: spacing)
        let columns = Array(repeating: column, count: 7)
        return LazyVGrid(columns: columns, alignment: .center, spacing: spacing) {
            ForEach(CalendarWeekdaySymbols.orderedAbbreviated(calendar: calendar), id: \.self) { weekday in
                Text(weekday)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(
                        minWidth: usesCompactCustomGrid ? cellSize : nil,
                        maxWidth: usesCompactCustomGrid ? cellSize : .infinity
                    )
            }
            ForEach(Array(paddedDays.enumerated()), id: \.offset) { _, day in
                StatisticsContributionCell(
                    day: day,
                    maxValue: maxValue,
                    isInteractive: day?.isSelectable == true,
                    marksOutsidePeriod: marksOutsideMonth && day == nil,
                    hidesPlaceholder: usesCompactCustomGrid,
                    onSelectDate: onSelectDate
                )
                .frame(
                    minWidth: usesCompactCustomGrid ? cellSize : nil,
                    maxWidth: usesCompactCustomGrid ? cellSize : .infinity,
                    minHeight: cellHeight,
                    maxHeight: cellHeight
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var yearGrid: some View {
        let yearDays = paddedDays
        let weekCount = max(1, (yearDays.count + 6) / 7)
        let spacing: CGFloat = compact ? 1 : 2
        let weekdayWidth: CGFloat = 18
        let minimumCellSize: CGFloat = 5
        let maximumCellSize: CGFloat = compact ? 12 : 16
        let minimumWidth = weekdayWidth + CGFloat(weekCount) * (minimumCellSize + spacing)
        let fittedSize = (availableWidth - weekdayWidth) / CGFloat(weekCount) - spacing
        let grid = yearGrid(
            days: yearDays,
            weekCount: weekCount,
            cellSize: min(maximumCellSize, max(minimumCellSize, fittedSize)),
            weekdayWidth: weekdayWidth,
            spacing: spacing
        )
        return Group {
            if availableWidth < minimumWidth {
                ScrollView(.horizontal) { grid }
            } else {
                grid
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func yearGrid(
        days: [StatisticsContributionDay?],
        weekCount: Int,
        cellSize: CGFloat,
        weekdayWidth: CGFloat,
        spacing: CGFloat
    ) -> some View {
        let weekdays = CalendarWeekdaySymbols.orderedAbbreviated(calendar: calendar)
        let maximum = maxValue
        return Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
            ForEach(Array(weekdays.enumerated()), id: \.offset) { weekdayIndex, weekday in
                GridRow {
                    Text(weekday)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: weekdayWidth)

                    ForEach(0..<weekCount, id: \.self) { weekIndex in
                        let index = weekIndex * 7 + weekdayIndex
                        let day = days.indices.contains(index) ? days[index] : nil
                        StatisticsContributionCell(
                            day: day,
                            maxValue: maximum,
                            isInteractive: day?.isSelectable == true,
                            hidesPlaceholder: usesCompactCustomGrid,
                            onSelectDate: onSelectDate
                        )
                        .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
    }

}

private struct StatisticsContributionCell: View {
    @Environment(\.locale) private var locale

    let day: StatisticsContributionDay?
    let maxValue: Int
    let isInteractive: Bool
    let marksOutsidePeriod: Bool
    let hidesPlaceholder: Bool
    let onSelectDate: (Date) -> Void

    @State private var isHovered = false
    @State private var isDetailPresented = false

    init(
        day: StatisticsContributionDay?,
        maxValue: Int,
        isInteractive: Bool = true,
        marksOutsidePeriod: Bool = false,
        hidesPlaceholder: Bool = false,
        onSelectDate: @escaping (Date) -> Void
    ) {
        self.day = day
        self.maxValue = maxValue
        self.isInteractive = isInteractive
        self.marksOutsidePeriod = marksOutsidePeriod
        self.hidesPlaceholder = hidesPlaceholder
        self.onSelectDate = onSelectDate
    }

    @ViewBuilder
    var body: some View {
        renderedCell
            .opacity(hidesPlaceholder && day == nil ? 0 : 1)
            .accessibilityHidden(hidesPlaceholder && day == nil)
    }

    @ViewBuilder
    private var renderedCell: some View {
        if isInteractive {
            Button {
                guard day?.isSelectable == true else { return }
                isDetailPresented = true
            } label: {
                cellShape
                    .scaleEffect(isHovered && day != nil ? 1.08 : 1)
            }
            .buttonStyle(.plain)
            .disabled(day == nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .popover(
                isPresented: $isDetailPresented,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: .bottom
            ) {
                if let day {
                    StatisticsContributionPopover(day: day) {
                        isDetailPresented = false
                        onSelectDate(day.date)
                    }
                }
            }
            .onHover { hovering in
                isHovered = hovering && day != nil
            }
            .accessibilityLabel(helpText)
            .accessibilityHint(String(localized: "この日の記録"))
        } else {
            cellShape
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
        }
    }

    private var cellShape: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(fillColor)
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
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

    private var fillColor: Color {
        guard let day, day.value > 0 else { return Color.secondary.opacity(0.12) }
        let fraction = Double(day.value) / Double(maxValue)
        let level = max(1, min(4, Int(ceil(fraction * 4))))
        return Color(hex: day.colorHex ?? "#34C759").opacity(0.28 + Double(level) * 0.16)
    }

    private var helpText: String {
        guard let day else { return "" }
        let date = day.date.formatted(.dateTime.locale(locale).year().month().day())
        let duration = StatisticsFormatting.duration(day.focusedSeconds)
        return String(
            localized: "\(date)：集中時間\(duration)、集中\(day.flowCount)回、完了タスク\(day.completedTaskCount)件"
        )
    }
}

private struct StatisticsContributionPopover: View {
    @Environment(\.locale) private var locale

    let day: StatisticsContributionDay
    let onOpenHistory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(day.date.formatted(.dateTime.locale(locale).year().month(.wide).day()))
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 7) {
                metricRow(
                    String(localized: "集中時間"),
                    value: StatisticsFormatting.duration(day.focusedSeconds)
                )
                metricRow(String(localized: "集中回数"), value: "\(day.flowCount)")
                metricRow(String(localized: "完了タスク"), value: "\(day.completedTaskCount)")
            }
            Button(action: onOpenHistory) {
                Label(String(localized: "履歴"), systemImage: "clock.arrow.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .frame(minWidth: 210)
    }

    private func metricRow(_ title: String, value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.callout)
    }
}
#endif
