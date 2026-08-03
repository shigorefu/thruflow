//
//  StatisticsView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/09.
//

import Charts
import SwiftData
import SwiftUI

struct StatisticsView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext

    let directions: [Direction]
    @Binding private var cachedSnapshot: StatisticsPeriodSnapshot?
    let isVisible: Bool
    let onSelectHistoryDate: (Date) -> Void

    @State private var selectedMode: StatisticsMode = .flow
    @State private var selectedPeriod: StatisticsPeriod = .week
    @State private var selectedDirectionID: UUID?
    @State private var anchorDate = Date.now
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var distributionDimension: StatisticsDistributionDimension = .task
    @State private var isLoading = false
    @State private var csvShareURL: URL?

    init(
        isVisible: Bool = true,
        directions: [Direction],
        cachedSnapshot: Binding<StatisticsPeriodSnapshot?>,
        onSelectHistoryDate: @escaping (Date) -> Void = { _ in }
    ) {
        self.isVisible = isVisible
        self.directions = directions
        _cachedSnapshot = cachedSnapshot
        self.onSelectHistoryDate = onSelectHistoryDate
    }

    private var activeDirections: [Direction] {
        directions
            .filter { !$0.isArchived }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var selectedDirection: Direction? {
        guard let selectedDirectionID else { return nil }
        return directions.first { $0.id == selectedDirectionID }
    }

    private var filter: StatisticsPeriodFilter {
        StatisticsPeriodFilter(
            period: selectedPeriod,
            anchorDate: anchorDate,
            directionID: selectedDirectionID,
            query: searchText
        )
    }

    private var snapshot: StatisticsPeriodSnapshot {
        if let cachedSnapshot, cachedSnapshot.filter == filter {
            return cachedSnapshot
        }
        return StatisticsPeriodBuilder(
            calendar: calendar,
            dayBoundary: dayBoundary
        ).build(flowRecords: [], achievementRecords: [], filter: filter)
    }

    var body: some View {
        workspace
            .navigationTitle(isVisible ? String(localized: "統計") : "")
            .toolbar { statisticsToolbar }
            .task(id: refreshID) {
                await refreshStatisticsWhileVisible()
            }
    }

    private var workspace: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        StatisticsSummaryCard(
                            title: periodTitle,
                            summary: snapshot.summary,
                            previousSummary: snapshot.previousSummary
                        )

                        StatisticsTrendCard(
                            mode: selectedMode,
                            period: selectedPeriod,
                            points: snapshot.trend
                        )

                        StatisticsDistributionCard(
                            dimension: $distributionDimension,
                            items: distributionItems,
                            totalFocusSeconds: snapshot.summary.totalFocusSeconds
                        )

                        StatisticsDotsCard(
                            mode: selectedMode,
                            period: selectedPeriod,
                            flowDays: snapshot.flowDays,
                            achievementDays: snapshot.achievementDays,
                            onSelectDate: onSelectHistoryDate
                        )
                    }
                    .padding(20)
                }
                .overlay(alignment: .topTrailing) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .padding(26)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                statisticsCalendarSidebar
                    .frame(
                        width: MacCalendarSidebarLayout.width(
                            for: periodTitle,
                            in: geometry.size.width,
                            preferredFraction: 0.27,
                            minimum: 285,
                            maximum: 390
                        )
                    )
            }
        }
    }

    @ToolbarContentBuilder
    private var statisticsToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Menu {
                ForEach([StatisticsMode.flow, .achievement]) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        if selectedMode == mode {
                            Label(mode.displayName, systemImage: "checkmark")
                        } else {
                            Text(mode.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedMode.displayName)
                        .font(.callout.weight(.semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel(String(localized: "統計表示"))
        }

        ToolbarItem(placement: .principal) {
            Picker(String(localized: "統計期間"), selection: $selectedPeriod) {
                ForEach(StatisticsPeriod.allCases) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
            .accessibilityLabel(String(localized: "統計期間"))
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                if let csvShareURL {
                    ShareLink(item: csvShareURL) {
                        Label(String(localized: "CSVを書き出す"), systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {} label: {
                        Label(String(localized: "CSVを書き出す"), systemImage: "square.and.arrow.up")
                    }
                    .disabled(true)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .help(String(localized: "その他の操作"))
            .accessibilityLabel(String(localized: "その他の操作"))
        }

        ToolbarItem(placement: .primaryAction) {
            StatisticsDirectionFilterMenu(
                selectedDirectionID: $selectedDirectionID,
                directions: activeDirections,
                selectedDirection: selectedDirection
            )
        }

        ToolbarItem(placement: .primaryAction) {
            MacToolbarSearchControl(
                text: $searchText,
                isPresented: $isSearchPresented
            )
        }
    }

    private var statisticsCalendarSidebar: some View {
        VStack(spacing: 0) {
            StatisticsCalendarNavigationHeader(
                title: periodTitle,
                onPrevious: { movePeriod(by: -1) },
                onToday: moveToToday,
                onNext: { movePeriod(by: 1) }
            )

            Divider()

            ScrollView {
                Group {
                    switch selectedPeriod {
                    case .week:
                        HistoryMiniCalendar(
                            selectedDate: anchorDateBinding,
                            selectionMode: .week,
                            indicatorSource: .statistics(calendarIndicators)
                        )
                    case .month:
                        HistoryYearMonthPicker(selectedDate: anchorDateBinding)
                    case .year:
                        StatisticsYearPicker(selectedDate: anchorDateBinding)
                    }
                }
                .padding(16)
            }

            Spacer(minLength: 0)
        }
        .background(Color.secondary.opacity(0.035))
    }

    private var anchorDateBinding: Binding<Date> {
        Binding(
            get: { anchorDate },
            set: { anchorDate = dayBoundary.day(containing: $0, calendar: calendar) }
        )
    }

    private var calendarIndicators: [StatisticsCalendarIndicator] {
        switch selectedMode {
        case .flow:
            snapshot.flowDays.compactMap { day in
                guard !day.isEmpty else { return nil }
                return StatisticsCalendarIndicator(
                    date: day.date,
                    colorHex: day.mixedColorHex ?? "#34C759"
                )
            }
        case .achievement:
            snapshot.achievementDays.compactMap { day in
                guard !day.isEmpty else { return nil }
                return StatisticsCalendarIndicator(
                    date: day.date,
                    colorHex: day.mixedColorHex ?? "#34C759"
                )
            }
        }
    }

    private var distributionItems: [StatisticsDistributionItem] {
        switch distributionDimension {
        case .task:
            snapshot.taskDistribution
        case .direction:
            snapshot.directionDistribution
        }
    }

    private var periodTitle: String {
        let bounds = snapshot.bounds
        switch selectedPeriod {
        case .week:
            let finalDay = calendar.date(byAdding: .day, value: -1, to: bounds.currentEnd) ?? bounds.currentStart
            let start = bounds.currentStart.formatted(.dateTime.locale(locale).month(.abbreviated).day())
            let end = finalDay.formatted(.dateTime.locale(locale).month(.abbreviated).day())
            return "\(start) – \(end)"
        case .month:
            return bounds.currentStart.formatted(.dateTime.locale(locale).year().month(.wide))
        case .year:
            return bounds.currentStart.formatted(.dateTime.locale(locale).year())
        }
    }

    private var exportFilename: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        switch selectedPeriod {
        case .week:
            formatter.dateFormat = "yyyy-MM-dd"
        case .month:
            formatter.dateFormat = "yyyy-MM"
        case .year:
            formatter.dateFormat = "yyyy"
        }
        return "thruflow-statistics-\(formatter.string(from: snapshot.bounds.currentStart)).csv"
    }

    private var refreshID: StatisticsPeriodRefreshID {
        StatisticsPeriodRefreshID(
            isVisible: isVisible,
            period: selectedPeriod,
            anchorDate: anchorDate,
            directionID: selectedDirectionID,
            query: searchText,
            directionCount: directions.count,
            latestDirectionUpdate: directions.first?.updatedAt
        )
    }

    @MainActor
    private func refreshStatisticsWhileVisible() async {
        while isVisible, !Task.isCancelled {
            await refreshStatisticsCache()
            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                return
            }
        }
    }

    @MainActor
    private func refreshStatisticsCache() async {
        guard isVisible else { return }
        isLoading = cachedSnapshot?.filter != filter
        if isLoading {
            csvShareURL = nil
        }

        do {
            try await Task.sleep(for: .milliseconds(120))
        } catch {
            isLoading = false
            return
        }
        guard !Task.isCancelled, isVisible else {
            isLoading = false
            return
        }

        let requestedFilter = filter
        let loader = StatisticsProjectionActor(modelContainer: modelContext.container)
        do {
            let projection = try await loader.load(
                filter: requestedFilter,
                calendar: calendar,
                dayBoundary: dayBoundary
            )
            guard !Task.isCancelled, requestedFilter == filter, isVisible else {
                isLoading = false
                return
            }
            cachedSnapshot = projection
            prepareCSVShareURL(for: projection)
        } catch {
            // Keep the last valid projection on transient SwiftData/CloudKit reads.
        }
        isLoading = false
    }

    private func movePeriod(by value: Int) {
        anchorDate = selectedPeriod.offset(anchorDate, by: value, calendar: calendar)
    }

    private func moveToToday() {
        anchorDate = dayBoundary.day(containing: .now, calendar: calendar)
    }

    private func prepareCSVShareURL(for projection: StatisticsPeriodSnapshot) {
        let csv = StatisticsCSVExporter().export(rows: projection.csvRows, calendar: calendar)
        csvShareURL = try? StatisticsCSVTemporaryFileWriter().write(
            csv: csv,
            filename: exportFilename
        )
    }

}

private enum StatisticsDistributionDimension: String, CaseIterable, Identifiable {
    case task
    case direction

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .task:
            String(localized: "タスク別")
        case .direction:
            String(localized: "方向別")
        }
    }
}

private struct StatisticsDirectionFilterMenu: View {
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
            Image(systemName: selectedDirectionID == nil
                ? "line.3.horizontal.decrease.circle"
                : "line.3.horizontal.decrease.circle.fill")
        }
        .menuStyle(.borderlessButton)
        .help(filterHelp)
        .accessibilityLabel(String(localized: "方向フィルター"))
        .accessibilityValue(selectedDirection?.name ?? String(localized: "すべて"))
    }

    private var filterHelp: String {
        selectedDirection.map { "\(String(localized: "方向フィルター")): \($0.name)" }
            ?? String(localized: "方向フィルター")
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

private struct StatisticsCalendarNavigationHeader: View {
    let title: String
    let onPrevious: () -> Void
    let onToday: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .layoutPriority(1)

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel(String(localized: "前へ"))

                Button(String(localized: "今日"), action: onToday)
                    .buttonStyle(.borderedProminent)

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel(String(localized: "次へ"))
            }
            .buttonStyle(.borderless)
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

private struct StatisticsSummaryCard: View {
    let title: String
    let summary: StatisticsPeriodSummary
    let previousSummary: StatisticsPeriodSummary

    private let columns = [GridItem(.adaptive(minimum: 128, maximum: 220), spacing: 10)]

    var body: some View {
        StatisticsCard(title: String(localized: "概要"), subtitle: title) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                StatisticsSummaryMetric(
                    title: String(localized: "集中時間"),
                    value: StatisticsFormatting.duration(summary.totalFocusSeconds),
                    previousValue: StatisticsFormatting.duration(previousSummary.totalFocusSeconds),
                    systemImage: "timer"
                )
                StatisticsSummaryMetric(
                    title: String(localized: "Blocks"),
                    value: BlockUnit.displayText(forFocusedSeconds: summary.totalFocusSeconds),
                    previousValue: BlockUnit.displayText(forFocusedSeconds: previousSummary.totalFocusSeconds),
                    systemImage: "square.grid.2x2"
                )
                StatisticsSummaryMetric(
                    title: String(localized: "Flow"),
                    value: "\(summary.flowCount)",
                    previousValue: "\(previousSummary.flowCount)",
                    systemImage: "water.waves"
                )
                StatisticsSummaryMetric(
                    title: String(localized: "完了タスク"),
                    value: "\(summary.completedTaskCount)",
                    previousValue: "\(previousSummary.completedTaskCount)",
                    systemImage: "checkmark.circle"
                )
                StatisticsSummaryMetric(
                    title: String(localized: "活動日"),
                    value: String(localized: "\(summary.activeFlowDayCount)日"),
                    previousValue: String(localized: "\(previousSummary.activeFlowDayCount)日"),
                    systemImage: "calendar"
                )
            }
        }
    }
}

private struct StatisticsSummaryMetric: View {
    let title: String
    let value: String
    let previousValue: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text("\(String(localized: "前の期間")) · \(previousValue)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.075))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct StatisticsTrendCard: View {
    @Environment(\.locale) private var locale

    let mode: StatisticsMode
    let period: StatisticsPeriod
    let points: [StatisticsTrendPoint]

    var body: some View {
        StatisticsCard(
            title: String(localized: "傾向"),
            subtitle: mode == .flow ? String(localized: "集中時間") : String(localized: "完了タスク")
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    Label(String(localized: "選択した期間"), systemImage: "minus")
                        .foregroundStyle(Color.accentColor)
                    Label(String(localized: "前の期間"), systemImage: "ellipsis")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)

                Chart {
                    ForEach(points) { point in
                        LineMark(
                            x: .value("index", point.index),
                            y: .value("previous", previousValue(point))
                        )
                        .foregroundStyle(Color.secondary.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("index", point.index),
                            y: .value("current", currentValue(point))
                        )
                        .foregroundStyle(Color.accentColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.2))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("index", point.index),
                            y: .value("current", currentValue(point))
                        )
                        .foregroundStyle(Color.accentColor)
                        .symbolSize(24)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: axisIndexes) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let index = value.as(Int.self), points.indices.contains(index) {
                                Text(axisLabel(for: points[index].date))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let raw = value.as(Int.self) {
                                Text(axisValueLabel(raw))
                            }
                        }
                    }
                }
                .frame(height: 220)
                .overlay {
                    if points.allSatisfy({ currentValue($0) == 0 && previousValue($0) == 0 }) {
                        StatisticsEmptyState(label: String(localized: "この期間のデータはありません"))
                    }
                }
            }
        }
    }

    private var axisIndexes: [Int] {
        guard !points.isEmpty else { return [] }
        let stride = max(1, points.count / 6)
        var indexes = Array(Swift.stride(from: 0, to: points.count, by: stride))
        if let last = points.indices.last, indexes.last != last {
            indexes.append(last)
        }
        return indexes
    }

    private func currentValue(_ point: StatisticsTrendPoint) -> Int {
        mode == .flow ? point.focusSeconds / 60 : point.completedTaskCount
    }

    private func previousValue(_ point: StatisticsTrendPoint) -> Int {
        mode == .flow ? point.previousFocusSeconds / 60 : point.previousCompletedTaskCount
    }

    private func axisValueLabel(_ value: Int) -> String {
        mode == .flow ? String(localized: "\(value)分") : "\(value)"
    }

    private func axisLabel(for date: Date) -> String {
        switch period {
        case .week:
            date.formatted(.dateTime.locale(locale).weekday(.narrow))
        case .month:
            date.formatted(.dateTime.locale(locale).day())
        case .year:
            date.formatted(.dateTime.locale(locale).month(.abbreviated))
        }
    }
}

private struct StatisticsDistributionCard: View {
    @Binding var dimension: StatisticsDistributionDimension
    let items: [StatisticsDistributionItem]
    let totalFocusSeconds: Int

    var body: some View {
        StatisticsCard(title: String(localized: "集中時間の内訳")) {
            VStack(alignment: .leading, spacing: 14) {
                Picker(String(localized: "内訳"), selection: $dimension) {
                    ForEach(StatisticsDistributionDimension.allCases) { dimension in
                        Text(dimension.displayName).tag(dimension)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 210)

                if items.isEmpty {
                    StatisticsEmptyState(label: String(localized: "この期間の集中記録はありません"))
                        .frame(maxWidth: .infinity, minHeight: 190)
                } else {
                    HStack(spacing: 28) {
                        Chart(items) { item in
                            SectorMark(
                                angle: .value("focus", item.focusSeconds),
                                innerRadius: .ratio(0.60),
                                angularInset: 1.5
                            )
                            .cornerRadius(3)
                            .foregroundStyle(Color(hex: item.colorHex ?? "#8E8E93"))
                        }
                        .chartLegend(.hidden)
                        .frame(width: 190, height: 190)
                        .overlay {
                            VStack(spacing: 3) {
                                Text(StatisticsFormatting.duration(totalFocusSeconds))
                                    .font(.headline.monospacedDigit())
                                Text(String(localized: "集中時間"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(items) { item in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(hex: item.colorHex ?? "#8E8E93"))
                                        .frame(width: 9, height: 9)
                                    Text([item.symbol, item.name].compactMap { $0 }.joined(separator: " "))
                                        .lineLimit(1)
                                    Spacer(minLength: 8)
                                    Text(StatisticsFormatting.duration(item.focusSeconds))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                .font(.callout)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

private struct StatisticsDotsCard: View {
    @Environment(\.calendar) private var calendar

    let mode: StatisticsMode
    let period: StatisticsPeriod
    let flowDays: [StatisticsDay]
    let achievementDays: [AchievementDay]
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
                completedTaskCount: achievement?.completedCount ?? 0
            )
        }
    }

    var body: some View {
        StatisticsCard(
            title: String(localized: "Dots"),
            subtitle: mode == .flow ? String(localized: "Flow Blocks") : String(localized: "完了タスク")
        ) {
            StatisticsContributionGrid(
                days: contributionDays,
                period: period,
                onSelectDate: onSelectDate
            )
        }
    }
}

private struct StatisticsContributionDay: Identifiable {
    let date: Date
    let value: Int
    let colorHex: String?
    let focusedSeconds: Int
    let flowCount: Int
    let completedTaskCount: Int

    var id: Date { date }
}

private struct StatisticsContributionGrid: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    let days: [StatisticsContributionDay]
    let period: StatisticsPeriod
    let onSelectDate: (Date) -> Void

    private var maxValue: Int {
        max(1, days.map(\.value).max() ?? 1)
    }

    private var paddedDays: [StatisticsContributionDay?] {
        guard let first = days.first else { return [] }
        let weekday = calendar.component(.weekday, from: first.date)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + days.map(Optional.some)
    }

    var body: some View {
        if days.isEmpty {
            StatisticsEmptyState(label: String(localized: "この期間のデータはありません"))
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                switch period {
                case .week:
                    calendarGrid(cellSize: 38, spacing: 8)
                case .month:
                    calendarGrid(cellSize: 24, spacing: 6)
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
                            .frame(width: 12, height: 12)
                    }
                    Text(String(localized: "多い"))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func calendarGrid(cellSize: CGFloat, spacing: CGFloat) -> some View {
        let columns = Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: 7)
        return LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
            ForEach(CalendarWeekdaySymbols.orderedAbbreviated(calendar: calendar), id: \.self) { weekday in
                Text(weekday)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: cellSize)
            }
            ForEach(Array(paddedDays.enumerated()), id: \.offset) { _, day in
                StatisticsContributionCell(
                    day: day,
                    size: cellSize,
                    maxValue: maxValue,
                    onSelectDate: onSelectDate
                )
            }
        }
    }

    private var yearGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: 4) {
                    ForEach(CalendarWeekdaySymbols.orderedAbbreviated(calendar: calendar), id: \.self) { weekday in
                        Text(weekday)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 18, height: 13)
                    }
                }

                LazyHGrid(
                    rows: Array(repeating: GridItem(.fixed(13), spacing: 4), count: 7),
                    spacing: 4
                ) {
                    ForEach(Array(paddedDays.enumerated()), id: \.offset) { _, day in
                        StatisticsContributionCell(
                            day: day,
                            size: 13,
                            maxValue: maxValue,
                            onSelectDate: onSelectDate
                        )
                    }
                }
            }
        }
        .scrollClipDisabled()
    }
}

private struct StatisticsContributionCell: View {
    @Environment(\.locale) private var locale

    let day: StatisticsContributionDay?
    let size: CGFloat
    let maxValue: Int
    let onSelectDate: (Date) -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            guard let day else { return }
            onSelectDate(day.date)
        } label: {
            RoundedRectangle(cornerRadius: min(4, size * 0.22), style: .continuous)
                .fill(fillColor)
                .overlay {
                    RoundedRectangle(cornerRadius: min(4, size * 0.22), style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06))
                }
                .scaleEffect(isHovered && day != nil ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .disabled(day == nil)
        .frame(width: size, height: size)
        .help(helpText)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering && day != nil
            }
        }
        .accessibilityLabel(helpText)
        .accessibilityHint(String(localized: "この日の履歴を開く"))
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
        return "\(date) · \(StatisticsFormatting.duration(day.focusedSeconds)) · \(day.flowCount) Flow · \(day.completedTaskCount) \(String(localized: "タスク"))"
    }
}

private struct StatisticsYearPicker: View {
    @Environment(\.calendar) private var calendar
    @Binding var selectedDate: Date

    private var selectedYear: Int { calendar.component(.year, from: selectedDate) }
    private var currentYear: Int { calendar.component(.year, from: .now) }
    private var years: [Int] {
        let lower = min(selectedYear - 4, currentYear - 5)
        let upper = max(selectedYear + 4, currentYear + 2)
        return Array((lower...upper).reversed())
    }

    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(years, id: \.self) { year in
                Button {
                    select(year)
                } label: {
                    HStack {
                        Text(String(localized: "\(year)年"))
                            .font(.callout.weight(year == selectedYear ? .semibold : .regular))
                        Spacer()
                        if year == currentYear {
                            Text(String(localized: "今年"))
                                .font(.caption)
                                .foregroundStyle(year == selectedYear ? Color.white.opacity(0.82) : .secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .foregroundStyle(year == selectedYear ? Color.white : Color.primary)
                    .background(year == selectedYear ? Color.accentColor : Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(year == selectedYear ? .isSelected : [])
            }
        }
    }

    private func select(_ year: Int) {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = 1
        components.day = 1
        if let date = components.date {
            selectedDate = calendar.startOfDay(for: date)
        }
    }
}

private struct StatisticsCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.secondary.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07))
        }
    }
}

private struct StatisticsEmptyState: View {
    let label: String

    var body: some View {
        ContentUnavailableView(
            label,
            systemImage: "chart.xyaxis.line",
            description: Text(String(localized: "期間やフィルターを変更してください"))
        )
        .controlSize(.small)
    }
}

private enum StatisticsFormatting {
    static func duration(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours == 0 {
            return String(localized: "\(remainingMinutes)分")
        }
        return String(localized: "\(hours)時間\(remainingMinutes)分")
    }
}

private struct StatisticsCSVTemporaryFileWriter {
    func write(csv: String, filename: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ThruFlow Statistics", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let url = directory.appendingPathComponent(filename)
        try Data(csv.utf8).write(to: url, options: .atomic)
        return url
    }
}

private struct StatisticsPeriodRefreshID: Hashable {
    let isVisible: Bool
    let period: StatisticsPeriod
    let anchorDate: Date
    let directionID: UUID?
    let query: String
    let directionCount: Int
    let latestDirectionUpdate: Date?
}

#Preview {
    StatisticsPreviewHost()
}

private struct StatisticsPreviewHost: View {
    @State private var snapshot: StatisticsPeriodSnapshot?

    var body: some View {
        NavigationStack {
            StatisticsView(
                directions: [],
                cachedSnapshot: $snapshot
            )
        }
        .frame(width: 1180, height: 820)
        .modelContainer(
            for: [Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self],
            inMemory: true
        )
    }
}
