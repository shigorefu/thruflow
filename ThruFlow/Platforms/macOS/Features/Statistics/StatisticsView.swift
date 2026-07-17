//
//  StatisticsView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/09.
//

import SwiftData
import SwiftUI

struct StatisticsView: View {
    @Environment(\.calendar) private var calendar

    @Query(sort: \FlowSession.startedAt, order: .reverse) private var sessions: [FlowSession]
    @Query(sort: \Direction.name, order: .forward) private var directions: [Direction]
    @Query(sort: \Todo.updatedAt, order: .reverse) private var todos: [Todo]

    @State private var selectedMode: StatisticsMode = .achievement
    @State private var selectedRange: StatisticsRange = .calendarYear
    @State private var selectedDirectionID: UUID?
    let onSelectHistoryDate: (Date) -> Void

    private var flowBuilder: StatisticsHeatmapBuilder { StatisticsHeatmapBuilder(calendar: calendar) }
    private var achievementBuilder: AchievementHeatmapBuilder { AchievementHeatmapBuilder(calendar: calendar) }

    init(onSelectHistoryDate: @escaping (Date) -> Void = { _ in }) {
        self.onSelectHistoryDate = onSelectHistoryDate
    }

    private var activeDirections: [Direction] {
        directions.filter { !$0.isArchived }
    }

    private var selectedDirection: Direction? {
        guard let selectedDirectionID else { return nil }
        return directions.first { $0.id == selectedDirectionID }
    }

    private var flowResult: StatisticsHeatmapResult {
        flowBuilder.build(
            sessions: sessions,
            filter: StatisticsFilter(range: selectedRange, directionID: selectedDirectionID)
        )
    }

    private var achievementResult: AchievementHeatmapResult {
        achievementBuilder.build(
            todos: todos,
            filter: StatisticsFilter(range: selectedRange, directionID: selectedDirectionID)
        )
    }

    private var flowDaysByDate: [Date: StatisticsDay] {
        Dictionary(uniqueKeysWithValues: flowResult.days.map { ($0.date, $0) })
    }

    private var achievementDaysByDate: [Date: AchievementDay] {
        Dictionary(uniqueKeysWithValues: achievementResult.days.map { ($0.date, $0) })
    }

    var body: some View {
        statisticsContent
    }

    private var statisticsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                controls

                switch selectedMode {
                case .achievement:
                    achievementSummaryRow
                    achievementSection
                case .flow:
                    flowSummaryRow
                    flowSection
                }
            }
            .padding(20)
        }
        .navigationTitle(String(localized: "統計"))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(headerTitle)
                .font(.title2.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 12)

            DirectionFilterMenu(
                selectedDirectionID: $selectedDirectionID,
                directions: activeDirections,
                selectedDirection: selectedDirection
            )
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(String(localized: "表示"), selection: $selectedMode) {
                ForEach(StatisticsMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(String(localized: "統計表示"))

            Picker(String(localized: "期間"), selection: $selectedRange) {
                ForEach(StatisticsRange.allCases) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(String(localized: "統計期間"))
        }
    }

    private var headerTitle: String {
        switch selectedMode {
        case .achievement:
            String(localized: "\(achievementResult.summary.completedCount) 達成 in \(selectedRange.summaryText)")
        case .flow:
            String(localized: "\(flowResult.summary.sessionCount) Flow in \(selectedRange.summaryText)")
        }
    }

    private var flowSummaryRow: some View {
        HStack(spacing: 12) {
            StatisticSummaryTile(
                title: String(localized: "合計"),
                value: blocksText(flowResult.summary.totalBlocks),
                subtitle: String(localized: "\(flowResult.summary.sessionCount) Flow")
            )

            StatisticSummaryTile(
                title: String(localized: "活動日"),
                value: String(localized: "\(flowResult.summary.activeDayCount)日"),
                subtitle: selectedRange.displayName
            )

            StatisticSummaryTile(
                title: String(localized: "時間"),
                value: durationText(flowResult.summary.totalFocusSeconds),
                subtitle: String(localized: "集中のみ")
            )
        }
    }

    private var achievementSummaryRow: some View {
        HStack(spacing: 12) {
            StatisticSummaryTile(
                title: String(localized: "達成"),
                value: "\(achievementResult.summary.completedCount)",
                subtitle: String(localized: "完了タスク")
            )

            StatisticSummaryTile(
                title: String(localized: "達成日"),
                value: String(localized: "\(achievementResult.summary.activeDayCount)日"),
                subtitle: selectedRange.displayName
            )

            StatisticSummaryTile(
                title: String(localized: "方向"),
                value: "\(achievementResult.summary.directionCount)",
                subtitle: String(localized: "完了あり")
            )
        }
    }

    private var flowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "Flow"))
                    .font(.headline)

                Spacer()

                Text(String(localized: "複数の方向は色を混ぜて表示"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ContributionHeatmap(
                days: flowResult.days.map { day in
                    ContributionDay(
                        date: day.date,
                        value: day.totalFocusSeconds,
                        mixedColorHex: day.mixedColorHex,
                        directionCount: day.directionCount,
                        completedTaskCount: achievementDaysByDate[day.date]?.completedCount ?? 0,
                        flowCount: day.sessionCount,
                        flowSeconds: day.totalFocusSeconds,
                        emptyAccessibilityText: String(localized: "Flowなし"),
                        valueAccessibilityText: BlockUnit.displayText(forFocusedSeconds: day.totalFocusSeconds)
                    )
                },
                range: selectedRange,
                intensity: flowOpacity,
                onSelectDate: onSelectHistoryDate
            )

            HStack(spacing: 6) {
                Text(String(localized: "少ない"))
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(level == 0 ? Color.secondary.opacity(0.14) : Color.accentColor.opacity(Double(level) * 0.18 + 0.16))
                        .frame(width: 12, height: 12)
                }
                Text(String(localized: "多い"))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var achievementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "達成"))
                    .font(.headline)

                Spacer()

                Text(String(localized: "複数の方向は色を混ぜて表示"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ContributionHeatmap(
                days: achievementResult.days.map { day in
                    ContributionDay(
                        date: day.date,
                        value: day.completedCount,
                        mixedColorHex: day.mixedColorHex,
                        directionCount: day.directionCount,
                        completedTaskCount: day.completedCount,
                        flowCount: flowDaysByDate[day.date]?.sessionCount ?? 0,
                        flowSeconds: flowDaysByDate[day.date]?.totalFocusSeconds ?? 0,
                        emptyAccessibilityText: String(localized: "達成なし"),
                        valueAccessibilityText: String(localized: "\(day.completedCount)達成")
                    )
                },
                range: selectedRange,
                intensity: achievementOpacity,
                onSelectDate: onSelectHistoryDate
            )

            HStack(spacing: 6) {
                Text(String(localized: "少ない"))
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(level == 0 ? Color.secondary.opacity(0.14) : Color.accentColor.opacity(Double(level) * 0.18 + 0.16))
                        .frame(width: 12, height: 12)
                }
                Text(String(localized: "多い"))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func blocksText(_ blocks: Double) -> String {
        if blocks < 10 {
            return String(format: String(localized: "%.1f Blocks"), blocks)
        }
        return String(format: String(localized: "%.0f Blocks"), blocks)
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours == 0 {
            return String(localized: "\(remainingMinutes)分")
        }
        return String(localized: "\(hours)時間\(remainingMinutes)分")
    }

    private func flowOpacity(_ seconds: Int) -> Double {
        switch seconds {
        case 1..<(12 * 60):
            return 0.35
        case (12 * 60)..<(25 * 60):
            return 0.50
        case (25 * 60)..<(50 * 60):
            return 0.68
        case (50 * 60)..<(100 * 60):
            return 0.84
        default:
            return 1.0
        }
    }

    private func achievementOpacity(_ count: Int) -> Double {
        switch count {
        case 1:
            return 0.40
        case 2:
            return 0.58
        case 3:
            return 0.74
        case 4:
            return 0.88
        default:
            return 1.0
        }
    }
}

private struct DirectionFilterMenu: View {
    @Binding var selectedDirectionID: UUID?

    let directions: [Direction]
    let selectedDirection: Direction?

    var body: some View {
        Menu {
            Button {
                selectedDirectionID = nil
            } label: {
                menuRow(text: String(localized: "すべて"), isSelected: selectedDirectionID == nil)
            }

            if !directions.isEmpty {
                Divider()

                ForEach(directions) { direction in
                    Button {
                        selectedDirectionID = direction.id
                    } label: {
                        menuRow(
                            text: "\(direction.symbolName) \(direction.name)",
                            isSelected: selectedDirectionID == direction.id
                        )
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedDirection.map { "\($0.symbolName) \($0.name)" } ?? String(localized: "すべて"))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .font(.callout.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(0.12))
            .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel(String(localized: "方向フィルター"))
    }

    @ViewBuilder
    private func menuRow(text: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(text, systemImage: "checkmark")
        } else {
            Text(text)
        }
    }
}

private struct StatisticSummaryTile: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ContributionDay: Identifiable {
    let date: Date
    let value: Int
    let mixedColorHex: String?
    let directionCount: Int
    let completedTaskCount: Int
    let flowCount: Int
    let flowSeconds: Int
    let emptyAccessibilityText: String
    let valueAccessibilityText: String

    var id: Date { date }

    var isEmpty: Bool {
        value <= 0
    }
}

private struct ContributionHeatmap: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    let days: [ContributionDay]
    let range: StatisticsRange
    let intensity: (Int) -> Double
    let onSelectDate: (Date) -> Void

    private let monthLabelHeight: CGFloat = 18

    private var layout: ContributionHeatmapLayout {
        ContributionHeatmapLayout(range: range)
    }

    private var rows: [GridItem] {
        Array(repeating: GridItem(.fixed(layout.cellSize), spacing: layout.cellSpacing), count: 7)
    }

    private var paddedDays: [ContributionDay?] {
        guard let first = days.first else { return [] }
        let weekday = calendar.component(.weekday, from: first.date)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leadingDays) + days.map(Optional.some)
    }

    private var columnCount: Int {
        Int(ceil(Double(paddedDays.count) / 7.0))
    }

    private var monthLabels: [MonthLabel] {
        var labels: [MonthLabel] = []
        var seenMonths: Set<String> = []

        for (index, day) in paddedDays.enumerated() {
            guard let day else { continue }

            let components = calendar.dateComponents([.year, .month], from: day.date)
            let key = "\(components.year ?? 0)-\(components.month ?? 0)"
            guard !seenMonths.contains(key) else { continue }

            seenMonths.insert(key)
            labels.append(
                MonthLabel(
                    id: key,
                    title: monthFormatter.string(from: day.date),
                    column: index / 7
                )
            )
        }

        return labels
    }

    var body: some View {
        Group {
            if range == .currentMonth {
                monthGrid
            } else {
                contributionGrid
            }
        }
    }

    private var contributionGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 0) {
                    Color.clear
                        .frame(width: layout.labelColumnWidth, height: monthLabelHeight)

                    ZStack(alignment: .topLeading) {
                        ForEach(monthLabels) { label in
                            Text(label.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)
                                .offset(x: CGFloat(label.column) * columnWidth)
                        }
                    }
                    .frame(width: max(0, CGFloat(columnCount) * columnWidth), height: monthLabelHeight, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 8) {
                    weekdayLabels

                    LazyHGrid(rows: rows, spacing: layout.cellSpacing) {
                        ForEach(Array(paddedDays.enumerated()), id: \.offset) { _, day in
                            ContributionHeatmapCell(
                                day: day,
                                cellSize: layout.cellSize,
                                intensity: intensity,
                                onSelectDate: onSelectDate
                            )
                        }
                    }
                    .accessibilityElement(children: .contain)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private var monthGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthLabels.first?.title ?? "")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.fixed(layout.cellSize), spacing: layout.cellSpacing),
                    count: 7
                ),
                alignment: .leading,
                spacing: layout.cellSpacing
            ) {
                ForEach(Array(monthGridItems.enumerated()), id: \.offset) { _, item in
                    switch item {
                    case let .weekday(label):
                        Text(label)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(width: layout.cellSize, height: 16)
                    case let .day(day):
                        ContributionHeatmapCell(
                            day: day,
                            cellSize: layout.cellSize,
                            intensity: intensity,
                            onSelectDate: onSelectDate
                        )
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var weekdayLabels: some View {
        VStack(alignment: .trailing, spacing: layout.cellSpacing) {
            ForEach(0..<7, id: \.self) { index in
                Text(weekdayLabel(for: index))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: layout.labelColumnWidth, height: layout.cellSize, alignment: .trailing)
            }
        }
    }

    private var columnWidth: CGFloat {
        layout.cellSize + layout.cellSpacing
    }

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter
    }

    private func weekdayLabel(for index: Int) -> String {
        guard [1, 3, 5].contains(index) else { return "" }
        return orderedWeekdaySymbols[index]
    }

    private var monthWeekdayLabels: [String] {
        orderedWeekdaySymbols
    }

    private var orderedWeekdaySymbols: [String] {
        CalendarWeekdaySymbols.orderedAbbreviated(calendar: calendar)
    }

    private var monthGridItems: [MonthGridItem] {
        monthWeekdayLabels.map(MonthGridItem.weekday)
            + paddedDays.map(MonthGridItem.day)
    }
}

private enum MonthGridItem {
    case weekday(String)
    case day(ContributionDay?)
}

private struct ContributionHeatmapLayout {
    let cellSize: CGFloat
    let cellSpacing: CGFloat
    let labelColumnWidth: CGFloat

    init(range: StatisticsRange) {
        switch range {
        case .currentMonth:
            cellSize = 24
            cellSpacing = 6
            labelColumnWidth = 28
        case .days180:
            cellSize = 16
            cellSpacing = 5
            labelColumnWidth = 28
        case .calendarYear:
            cellSize = 13
            cellSpacing = 4
            labelColumnWidth = 28
        }
    }
}

private struct MonthLabel: Identifiable {
    let id: String
    let title: String
    let column: Int
}

private struct ContributionHeatmapCell: View {
    @Environment(\.locale) private var locale

    let day: ContributionDay?
    let cellSize: CGFloat
    let intensity: (Int) -> Double
    let onSelectDate: (Date) -> Void

    @State private var isHovered = false

    var body: some View {
        ZStack {
            Button {
                guard let day else { return }
                onSelectDate(day.date)
            } label: {
                RoundedRectangle(cornerRadius: min(4, cellSize * 0.22))
                    .fill(fillColor)
                    .frame(width: cellSize, height: cellSize)
                    .overlay {
                        RoundedRectangle(cornerRadius: min(4, cellSize * 0.22))
                            .strokeBorder(Color.primary.opacity(0.06))
                    }
                    .scaleEffect(isHovered && day != nil ? 1.08 : 1)
            }
            .buttonStyle(.plain)
            .disabled(day == nil)

            if isHovered, let day {
                ContributionHoverCard(day: day)
                    .offset(y: -(cellSize / 2 + 36))
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(10)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .zIndex(isHovered ? 10 : 0)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering && day != nil
            }
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(day == nil ? "" : String(localized: "この日の履歴を開く"))
    }

    private var fillColor: Color {
        guard let day, !day.isEmpty else {
            return Color.secondary.opacity(0.14)
        }

        let baseColor = Color(hex: day.mixedColorHex ?? "#34C759")
        return baseColor.opacity(intensity(day.value))
    }

    private var accessibilityLabel: String {
        guard let day else { return String(localized: "空白") }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium

        if day.isEmpty {
            return String(localized: "\(formatter.string(from: day.date)) \(day.emptyAccessibilityText) タスク\(day.completedTaskCount)件 Flow\(day.flowCount)件")
        }

        return String(localized: "\(formatter.string(from: day.date)) \(day.valueAccessibilityText) \(day.directionCount)方向 タスク\(day.completedTaskCount)件 Flow\(day.flowCount)件")
    }
}

private struct ContributionHoverCard: View {
    @Environment(\.locale) private var locale

    let day: ContributionDay

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateText)
                .font(.caption.weight(.semibold))

            Text(String(localized: "タスク \(day.completedTaskCount) ・ Flow \(day.flowCount)"))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.78))

            if day.flowSeconds > 0 {
                Text("\(BlockUnit.displayText(forFocusedSeconds: day.flowSeconds)) ・ \(durationText)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
        .fixedSize()
        .accessibilityHidden(true)
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MdE")
        return formatter.string(from: day.date)
    }

    private var durationText: String {
        let minutes = max(0, day.flowSeconds) / 60
        if minutes < 60 {
            return String(localized: "\(minutes)分")
        }
        return String(localized: "\(minutes / 60)時間\(minutes % 60)分")
    }
}

#Preview {
    NavigationStack {
        StatisticsView()
    }
    .modelContainer(for: [Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self], inMemory: true)
}
