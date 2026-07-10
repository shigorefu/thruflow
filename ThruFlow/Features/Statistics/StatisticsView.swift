//
//  StatisticsView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/09.
//

import SwiftData
import SwiftUI

struct StatisticsView: View {
    @Query(sort: \FlowSession.startedAt, order: .reverse) private var sessions: [FlowSession]
    @Query(sort: \Direction.name, order: .forward) private var directions: [Direction]
    @Query(sort: \Todo.updatedAt, order: .reverse) private var todos: [Todo]

    @State private var selectedMode: StatisticsMode = .achievement
    @State private var selectedRange: StatisticsRange = .calendarYear
    @State private var selectedDirectionID: UUID?
    @State private var selectedHistoryDate: Date?

    private let flowBuilder = StatisticsHeatmapBuilder()
    private let achievementBuilder = AchievementHeatmapBuilder()

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

    var body: some View {
        Group {
            if let selectedHistoryDate {
                DayHistoryView(initialDate: selectedHistoryDate) {
                    self.selectedHistoryDate = nil
                }
            } else {
                statisticsContent
            }
        }
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
        .navigationTitle("統計")
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
            Picker("表示", selection: $selectedMode) {
                ForEach(StatisticsMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("統計表示")

            Picker("期間", selection: $selectedRange) {
                ForEach(StatisticsRange.allCases) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("統計期間")
        }
    }

    private var headerTitle: String {
        switch selectedMode {
        case .achievement:
            "\(achievementResult.summary.completedCount) 達成 in \(selectedRange.summaryText)"
        case .flow:
            "\(flowResult.summary.sessionCount) Flow in \(selectedRange.summaryText)"
        }
    }

    private var flowSummaryRow: some View {
        HStack(spacing: 12) {
            StatisticSummaryTile(
                title: "合計",
                value: blocksText(flowResult.summary.totalBlocks),
                subtitle: "\(flowResult.summary.sessionCount) Flow"
            )

            StatisticSummaryTile(
                title: "活動日",
                value: "\(flowResult.summary.activeDayCount)日",
                subtitle: selectedRange.displayName
            )

            StatisticSummaryTile(
                title: "時間",
                value: durationText(flowResult.summary.totalFocusSeconds),
                subtitle: "集中のみ"
            )
        }
    }

    private var achievementSummaryRow: some View {
        HStack(spacing: 12) {
            StatisticSummaryTile(
                title: "達成",
                value: "\(achievementResult.summary.completedCount)",
                subtitle: "完了タスク"
            )

            StatisticSummaryTile(
                title: "達成日",
                value: "\(achievementResult.summary.activeDayCount)日",
                subtitle: selectedRange.displayName
            )

            StatisticSummaryTile(
                title: "方向",
                value: "\(achievementResult.summary.directionCount)",
                subtitle: "完了あり"
            )
        }
    }

    private var flowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Flow")
                    .font(.headline)

                Spacer()

                Text("複数の方向は色を混ぜて表示")
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
                        emptyAccessibilityText: "Flowなし",
                        valueAccessibilityText: BlockUnit.displayText(forFocusedSeconds: day.totalFocusSeconds)
                    )
                },
                intensity: flowOpacity,
                onSelectDate: { selectedHistoryDate = $0 }
            )

            HStack(spacing: 6) {
                Text("少ない")
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(level == 0 ? Color.secondary.opacity(0.14) : Color.accentColor.opacity(Double(level) * 0.18 + 0.16))
                        .frame(width: 12, height: 12)
                }
                Text("多い")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var achievementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("達成")
                    .font(.headline)

                Spacer()

                Text("複数の方向は色を混ぜて表示")
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
                        emptyAccessibilityText: "達成なし",
                        valueAccessibilityText: "\(day.completedCount)達成"
                    )
                },
                intensity: achievementOpacity,
                onSelectDate: { selectedHistoryDate = $0 }
            )

            HStack(spacing: 6) {
                Text("少ない")
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(level == 0 ? Color.secondary.opacity(0.14) : Color.accentColor.opacity(Double(level) * 0.18 + 0.16))
                        .frame(width: 12, height: 12)
                }
                Text("多い")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func blocksText(_ blocks: Double) -> String {
        if blocks < 10 {
            return String(format: "%.1f Blocks", blocks)
        }
        return String(format: "%.0f Blocks", blocks)
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours == 0 {
            return "\(remainingMinutes)分"
        }
        return "\(hours)時間\(remainingMinutes)分"
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
                menuRow(text: "すべて", isSelected: selectedDirectionID == nil)
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
                Text(selectedDirection.map { "\($0.symbolName) \($0.name)" } ?? "すべて")
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
        .accessibilityLabel("方向フィルター")
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
    let emptyAccessibilityText: String
    let valueAccessibilityText: String

    var id: Date { date }

    var isEmpty: Bool {
        value <= 0
    }
}

private struct ContributionHeatmap: View {
    let days: [ContributionDay]
    let intensity: (Int) -> Double
    let onSelectDate: (Date) -> Void

    private let cellSize: CGFloat = 13
    private let cellSpacing: CGFloat = 4
    private let labelColumnWidth: CGFloat = 28
    private let monthLabelHeight: CGFloat = 18
    private let rows = Array(repeating: GridItem(.fixed(13), spacing: 4), count: 7)
    private let calendar = Calendar.current

    private var paddedDays: [ContributionDay?] {
        guard let first = days.first else { return [] }
        let weekday = calendar.component(.weekday, from: first.date)
        return Array(repeating: nil, count: max(0, weekday - 1)) + days.map(Optional.some)
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
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 0) {
                    Color.clear
                        .frame(width: labelColumnWidth, height: monthLabelHeight)

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

                    LazyHGrid(rows: rows, spacing: cellSpacing) {
                        ForEach(Array(paddedDays.enumerated()), id: \.offset) { _, day in
                            ContributionHeatmapCell(
                                day: day,
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
    }

    private var weekdayLabels: some View {
        VStack(alignment: .trailing, spacing: cellSpacing) {
            ForEach(0..<7, id: \.self) { index in
                Text(weekdayLabel(for: index))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: labelColumnWidth, height: cellSize, alignment: .trailing)
            }
        }
    }

    private var columnWidth: CGFloat {
        cellSize + cellSpacing
    }

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "MMM"
        return formatter
    }

    private func weekdayLabel(for index: Int) -> String {
        switch index {
        case 1:
            "月"
        case 3:
            "水"
        case 5:
            "金"
        default:
            ""
        }
    }
}

private struct MonthLabel: Identifiable {
    let id: String
    let title: String
    let column: Int
}

private struct ContributionHeatmapCell: View {
    let day: ContributionDay?
    let intensity: (Int) -> Double
    let onSelectDate: (Date) -> Void

    var body: some View {
        Button {
            guard let day else { return }
            onSelectDate(day.date)
        } label: {
            RoundedRectangle(cornerRadius: 3)
                .fill(fillColor)
                .frame(width: 13, height: 13)
                .overlay {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.primary.opacity(0.05))
                }
        }
        .buttonStyle(.plain)
        .disabled(day == nil)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(day == nil ? "" : "この日の履歴を開く")
    }

    private var fillColor: Color {
        guard let day, !day.isEmpty else {
            return Color.secondary.opacity(0.14)
        }

        let baseColor = Color(hex: day.mixedColorHex ?? "#34C759")
        return baseColor.opacity(intensity(day.value))
    }

    private var accessibilityLabel: String {
        guard let day else { return "空白" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium

        if day.isEmpty {
            return "\(formatter.string(from: day.date)) \(day.emptyAccessibilityText)"
        }

        return "\(formatter.string(from: day.date)) \(day.valueAccessibilityText) \(day.directionCount)方向"
    }
}

#Preview {
    NavigationStack {
        StatisticsView()
    }
    .modelContainer(for: [Direction.self, Todo.self, FlowSession.self], inMemory: true)
}
