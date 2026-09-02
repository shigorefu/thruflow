//
//  StatisticsView.swift
//  ThruFlow
//
//

import Charts
import SwiftData
import SwiftUI

struct StatisticsView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext

    let areas: [Area]
    @Binding private var cachedSnapshot: StatisticsPeriodSnapshot?
    let isVisible: Bool
    let onSelectHistoryDate: (Date) -> Void

    @State private var selectedPeriod: StatisticsPeriod = .week
    @State private var selectedAreaID: UUID?
    @State private var anchorDate = Date.now
    @State private var customStartDate: Date?
    @State private var customEndDate: Date?
    @State private var customStartDraft = Date.now
    @State private var customEndDraft = Date.now
    @State private var isCustomRangePresented = false
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var distributionDimension: StatisticsDistributionDimension = .task
    @State private var trendMode: StatisticsMode = .flow
    @State private var dotsMode: StatisticsMode = .flow
    @State private var snapshotCache: [StatisticsPeriodFilter: StatisticsPeriodSnapshot] = [:]
    @State private var snapshotCacheOrder: [StatisticsPeriodFilter] = []
    @State private var loadingFilter: StatisticsPeriodFilter?
    @State private var isExportPresented = false
    @State private var exportContent: StatisticsCSVContent = .all
    @State private var exportStartDate = Date.now
    @State private var exportEndDate = Date.now
    @State private var exportAreaID: UUID?
    @State private var exportQuery = ""
    @State private var exportShareURL: URL?
    @State private var preparedExportConfiguration: StatisticsExportConfiguration?
    @State private var isPreparingExport = false

    init(
        isVisible: Bool = true,
        areas: [Area],
        cachedSnapshot: Binding<StatisticsPeriodSnapshot?>,
        onSelectHistoryDate: @escaping (Date) -> Void = { _ in }
    ) {
        self.isVisible = isVisible
        self.areas = areas
        _cachedSnapshot = cachedSnapshot
        self.onSelectHistoryDate = onSelectHistoryDate
    }

    private var activeAreas: [Area] {
        areas
            .filter { !$0.isArchived }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var selectedArea: Area? {
        guard let selectedAreaID else { return nil }
        return areas.first { $0.id == selectedAreaID }
    }

    private var filter: StatisticsPeriodFilter {
        StatisticsPeriodFilter(
            period: selectedPeriod,
            anchorDate: anchorDate,
            customStartDate: customStartDate,
            customEndDate: customEndDate,
            areaID: selectedAreaID,
            query: searchText
        )
    }

    private var exportFilter: StatisticsPeriodFilter {
        StatisticsPeriodFilter(
            period: .month,
            anchorDate: exportStartDate,
            customStartDate: exportStartDate,
            customEndDate: exportEndDate,
            areaID: exportAreaID,
            query: exportQuery
        )
    }

    private var exportConfiguration: StatisticsExportConfiguration {
        StatisticsExportConfiguration(content: exportContent, filter: exportFilter)
    }

    private var currentSnapshot: StatisticsPeriodSnapshot? {
        if let cachedSnapshot, cachedSnapshot.filter == filter {
            return cachedSnapshot
        }
        return snapshotCache[filter]
    }

    private var periodBounds: StatisticsPeriodBounds {
        StatisticsPeriodBuilder(
            calendar: calendar,
            dayBoundary: dayBoundary
        ).bounds(for: filter)
    }

    private var isLoadingCurrentFilter: Bool {
        loadingFilter == filter
    }

    private var usesCustomRange: Bool {
        customStartDate != nil && customEndDate != nil
    }

    private var displayedDayCount: Int {
        max(
            1,
            calendar.dateComponents(
                [.day],
                from: periodBounds.currentStart,
                to: periodBounds.currentEnd
            ).day ?? 1
        )
    }

    private var presentationPeriod: StatisticsPeriod {
        guard usesCustomRange else { return selectedPeriod }
        if displayedDayCount <= 7 { return .week }
        if displayedDayCount <= 62 { return .month }
        return .year
    }

    private var today: Date {
        dayBoundary.day(containing: .now, calendar: calendar)
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
                        if let currentSnapshot {
                            statisticsCards(snapshot: currentSnapshot)
                        } else {
                            StatisticsLoadingCards(period: presentationPeriod)
                        }
                    }
                    .padding(20)
                    .animation(.snappy(duration: 0.34, extraBounce: 0), value: selectedPeriod)
                }
                .overlay(alignment: .topTrailing) {
                    if isLoadingCurrentFilter, currentSnapshot != nil {
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
                            minimum: 330,
                            maximum: 430
                        )
                    )
            }
        }
    }

    @ViewBuilder
    private func statisticsCards(snapshot: StatisticsPeriodSnapshot) -> some View {
        StatisticsSummaryCard(
            title: periodTitle,
            summary: snapshot.summary,
            previousSummary: snapshot.previousSummary
        )

        StatisticsTrendCard(
            mode: $trendMode,
            period: presentationPeriod,
            points: snapshot.trend.filter { $0.date <= today }
        )

        Group {
            switch presentationPeriod {
            case .week:
                StatisticsDistributionCard(
                    dimension: $distributionDimension,
                    items: distributionItems(in: snapshot),
                    totalFocusSeconds: snapshot.summary.totalFocusSeconds
                )

                StatisticsDotsCard(
                    mode: $dotsMode,
                    period: presentationPeriod,
                    usesCompactCustomGrid: usesCustomRange && displayedDayCount > 7,
                    flowDays: snapshot.flowDays,
                    achievementDays: snapshot.achievementDays,
                    maximumInteractiveDate: today,
                    onSelectDate: onSelectHistoryDate
                )
            case .month:
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        StatisticsDistributionCard(
                            dimension: $distributionDimension,
                            items: distributionItems(in: snapshot),
                            totalFocusSeconds: snapshot.summary.totalFocusSeconds,
                            isCompact: true
                        )
                        .frame(
                            minWidth: 350,
                            maxWidth: .infinity,
                            minHeight: 320,
                            maxHeight: 320,
                            alignment: .top
                        )

                        StatisticsDotsCard(
                            mode: $dotsMode,
                            period: presentationPeriod,
                            usesCompactCustomGrid: usesCustomRange && displayedDayCount > 7,
                            flowDays: snapshot.flowDays,
                            achievementDays: snapshot.achievementDays,
                            maximumInteractiveDate: today,
                            onSelectDate: onSelectHistoryDate
                        )
                        .frame(
                            minWidth: 300,
                            maxWidth: .infinity,
                            minHeight: 320,
                            maxHeight: 320,
                            alignment: .top
                        )
                    }

                    VStack(spacing: 16) {
                        StatisticsDistributionCard(
                            dimension: $distributionDimension,
                            items: distributionItems(in: snapshot),
                            totalFocusSeconds: snapshot.summary.totalFocusSeconds
                        )

                        StatisticsDotsCard(
                            mode: $dotsMode,
                            period: presentationPeriod,
                            usesCompactCustomGrid: usesCustomRange && displayedDayCount > 7,
                            flowDays: snapshot.flowDays,
                            achievementDays: snapshot.achievementDays,
                            maximumInteractiveDate: today,
                            onSelectDate: onSelectHistoryDate
                        )
                    }
                }
            case .year:
                StatisticsDistributionCard(
                    dimension: $distributionDimension,
                    items: distributionItems(in: snapshot),
                    totalFocusSeconds: snapshot.summary.totalFocusSeconds
                )

                StatisticsDotsCard(
                    mode: $dotsMode,
                    period: presentationPeriod,
                    usesCompactCustomGrid: usesCustomRange && displayedDayCount > 7,
                    flowDays: snapshot.flowDays,
                    achievementDays: snapshot.achievementDays,
                    maximumInteractiveDate: today,
                    onSelectDate: onSelectHistoryDate
                )
            }
        }
        .id(presentationPeriod)
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.985, anchor: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.975, anchor: .top))
            )
        )
    }

    @ToolbarContentBuilder
    private var statisticsToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                prepareExportDraft()
                isExportPresented = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .help(String(localized: "CSVを書き出す"))
            .accessibilityLabel(String(localized: "CSVを書き出す"))
            .popover(isPresented: $isExportPresented, arrowEdge: .top) {
                statisticsExportPopover
            }
        }

        ToolbarItem(placement: .primaryAction) {
            StatisticsAreaFilterMenu(
                selectedAreaID: $selectedAreaID,
                areas: activeAreas,
                selectedArea: selectedArea
            )
        }

        ToolbarItem(placement: .primaryAction) {
            MacToolbarSearchControl(
                text: $searchText,
                isPresented: $isSearchPresented
            )
        }
    }

    private var statisticsExportPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "CSVを書き出す"))
                .font(.headline)

            Picker(String(localized: "書き出す内容"), selection: $exportContent) {
                ForEach(StatisticsCSVContent.allCases) { content in
                    Text(content.displayName).tag(content)
                }
            }
            .pickerStyle(.segmented)

            DatePicker(
                String(localized: "開始日"),
                selection: $exportStartDate,
                in: ...today,
                displayedComponents: .date
            )
            .datePickerStyle(.field)
            DatePicker(
                String(localized: "終了日"),
                selection: $exportEndDate,
                in: ...today,
                displayedComponents: .date
            )
            .datePickerStyle(.field)

            Picker(String(localized: "方向フィルター"), selection: $exportAreaID) {
                Text(String(localized: "すべて")).tag(nil as UUID?)
                ForEach(activeAreas) { area in
                    Text("\(area.symbolName) \(area.name)")
                        .tag(Optional(area.id))
                }
            }
            .pickerStyle(.menu)

            TextField(String(localized: "検索"), text: $exportQuery)
                .textFieldStyle(.roundedBorder)

            Divider()

            HStack {
                if isPreparingExport {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                if let exportShareURL,
                   preparedExportConfiguration == exportConfiguration {
                    ShareLink(item: exportShareURL) {
                        Label(String(localized: "CSVを書き出す"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {} label: {
                        Label(String(localized: "CSVを書き出す"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
                }
            }
        }
        .padding(16)
        .frame(width: 340)
        .task(id: exportConfiguration) {
            await prepareExportShareURL(for: exportConfiguration)
        }
        .onChange(of: exportStartDate) { _, newValue in
            if exportEndDate < newValue {
                exportEndDate = newValue
            }
        }
    }

    private var statisticsCalendarSidebar: some View {
        VStack(spacing: 0) {
            MacCalendarNavigationHeader(
                title: periodTitle,
                onPrevious: { movePeriod(by: -1) },
                onToday: moveToToday,
                onNext: { movePeriod(by: 1) },
                rangePickerWidth: nil,
                canMoveNext: canMoveToNextPeriod
            ) {
                ZStack {
                    statisticsRangePicker

                    HStack {
                        Spacer()
                        statisticsCustomRangeButton
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Divider()

            ScrollView {
                Group {
                    switch selectedPeriod {
                    case .week:
                        HistoryMiniCalendar(
                            selectedDate: anchorDateBinding,
                            selectionMode: .week,
                            indicatorSource: .statistics(calendarIndicators),
                            maximumDate: today
                        )
                    case .month:
                        HistoryYearMonthPicker(
                            selectedDate: anchorDateBinding,
                            maximumDate: today
                        )
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

    private var statisticsRangePicker: some View {
        Picker(String(localized: "統計期間"), selection: selectedPeriodBinding) {
            ForEach(StatisticsPeriod.allCases) { period in
                Text(period.displayName).tag(Optional(period))
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 120)
        .accessibilityLabel(String(localized: "統計期間"))
    }

    private var statisticsCustomRangeButton: some View {
        Button {
            prepareCustomRangeDraft()
            isCustomRangePresented = true
        } label: {
            Image(systemName: "calendar.badge.clock")
        }
        .buttonStyle(.bordered)
        .tint(usesCustomRange ? Color.accentColor : nil)
        .fixedSize()
        .help(String(localized: "期間を指定"))
        .accessibilityLabel(String(localized: "期間を指定"))
        .popover(isPresented: $isCustomRangePresented, arrowEdge: .top) {
            StatisticsCustomRangePopover(
                startDate: $customStartDraft,
                endDate: $customEndDraft,
                maximumDate: today,
                onCancel: { isCustomRangePresented = false },
                onApply: applyCustomRange
            )
        }
    }

    private var selectedPeriodBinding: Binding<StatisticsPeriod?> {
        Binding(
            get: { usesCustomRange ? nil : selectedPeriod },
            set: { period in
                guard let period else { return }
                selectPeriod(period)
            }
        )
    }

    private var anchorDateBinding: Binding<Date> {
        Binding(
            get: { anchorDate },
            set: {
                customStartDate = nil
                customEndDate = nil
                anchorDate = StatisticsPeriodBuilder(
                    calendar: calendar,
                    dayBoundary: dayBoundary
                ).anchorDate(forCalendarSelection: $0, maximumDate: today)
            }
        )
    }

    private var calendarIndicators: [StatisticsCalendarIndicator] {
        guard let currentSnapshot else { return [] }
        let achievements = Dictionary(
            uniqueKeysWithValues: currentSnapshot.achievementDays.map { ($0.date, $0) }
        )
        return currentSnapshot.flowDays.compactMap { day in
            let achievement = achievements[day.date]
            guard !day.isEmpty || achievement?.isEmpty == false else { return nil }
            return StatisticsCalendarIndicator(
                date: day.date,
                colorHex: day.mixedColorHex ?? achievement?.mixedColorHex ?? "#34C759"
            )
        }
    }

    private func distributionItems(
        in snapshot: StatisticsPeriodSnapshot
    ) -> [StatisticsDistributionItem] {
        switch distributionDimension {
        case .task:
            snapshot.taskDistribution
        case .area:
            snapshot.areaDistribution
        }
    }

    private var periodTitle: String {
        if usesCustomRange {
            let finalDay = calendar.date(
                byAdding: .day,
                value: -1,
                to: periodBounds.currentEnd
            ) ?? periodBounds.currentStart
            let start = periodBounds.currentStart.formatted(
                .dateTime.locale(locale).year().month(.abbreviated).day()
            )
            let end = finalDay.formatted(
                .dateTime.locale(locale).year().month(.abbreviated).day()
            )
            return start == end ? start : "\(start) – \(end)"
        }

        switch selectedPeriod {
        case .week:
            let periodFinalDay = calendar.date(
                byAdding: .day,
                value: -1,
                to: periodBounds.currentEnd
            ) ?? periodBounds.currentStart
            let finalDay = min(periodFinalDay, today)
            let start = periodBounds.currentStart.formatted(
                .dateTime.locale(locale).month(.abbreviated).day()
            )
            let end = finalDay.formatted(.dateTime.locale(locale).month(.abbreviated).day())
            return "\(start) – \(end)"
        case .month:
            return periodBounds.currentStart.formatted(.dateTime.locale(locale).year().month(.wide))
        case .year:
            return periodBounds.currentStart.formatted(.dateTime.locale(locale).year())
        }
    }

    private func exportFilename(
        for projection: StatisticsPeriodSnapshot,
        content: StatisticsCSVContent
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        let prefix = content == .all
            ? "thruflow-statistics"
            : "thruflow-statistics-\(content.rawValue)"
        if projection.filter.usesCustomRange {
            formatter.dateFormat = "yyyy-MM-dd"
            let start = formatter.string(from: projection.bounds.currentStart)
            let finalDay = calendar.date(
                byAdding: .day,
                value: -1,
                to: projection.bounds.currentEnd
            ) ?? projection.bounds.currentStart
            let end = formatter.string(from: finalDay)
            return "\(prefix)-\(start)-\(end).csv"
        }
        switch projection.filter.period {
        case .week:
            formatter.dateFormat = "yyyy-MM-dd"
        case .month:
            formatter.dateFormat = "yyyy-MM"
        case .year:
            formatter.dateFormat = "yyyy"
        }
        return "\(prefix)-\(formatter.string(from: projection.bounds.currentStart)).csv"
    }

    private var refreshID: StatisticsPeriodRefreshID {
        StatisticsPeriodRefreshID(
            isVisible: isVisible,
            period: selectedPeriod,
            anchorDate: anchorDate,
            customStartDate: customStartDate,
            customEndDate: customEndDate,
            areaID: selectedAreaID,
            query: searchText,
            areaCount: areas.count,
            latestAreaUpdate: areas.map(\.updatedAt).max()
        )
    }

    @MainActor
    private func refreshStatisticsWhileVisible() async {
        while isVisible, !Task.isCancelled {
            await refreshStatisticsCache()
            do {
                try await Task.sleep(for: .seconds(30))
            } catch {
                return
            }
        }
    }

    @MainActor
    private func refreshStatisticsCache() async {
        guard isVisible else { return }
        let requestedFilter = filter
        let needsPlaceholder = currentSnapshot == nil
        if needsPlaceholder {
            loadingFilter = requestedFilter
        }
        defer {
            if loadingFilter == requestedFilter {
                loadingFilter = nil
            }
        }

        do {
            try await Task.sleep(for: .milliseconds(needsPlaceholder ? 90 : 0))
        } catch {
            return
        }
        guard !Task.isCancelled, isVisible else {
            return
        }

        let loader = StatisticsProjectionActor(modelContainer: modelContext.container)
        do {
            let projection = try await loader.load(
                filter: requestedFilter,
                calendar: calendar,
                dayBoundary: dayBoundary
            )
            guard !Task.isCancelled, requestedFilter == filter, isVisible else {
                return
            }
            cache(projection)
            if loadingFilter == requestedFilter {
                loadingFilter = nil
            }
        } catch {
            PersistenceIssueCenter.shared.log(error, operation: .dataLoad)
        }
    }

    private func movePeriod(by value: Int) {
        guard value <= 0 || canMoveToNextPeriod else { return }
        if let customStartDate, let customEndDate {
            let start = dayBoundary.day(containing: min(customStartDate, customEndDate), calendar: calendar)
            let end = dayBoundary.day(containing: max(customStartDate, customEndDate), calendar: calendar)
            let dayCount = max(
                1,
                (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
            )
            let offset = value * dayCount
            self.customStartDate = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            self.customEndDate = calendar.date(byAdding: .day, value: offset, to: end) ?? end
            anchorDate = self.customStartDate ?? anchorDate
            return
        }
        anchorDate = selectedPeriod.offset(anchorDate, by: value, calendar: calendar)
    }

    private func moveToToday() {
        withAnimation(.snappy(duration: 0.34, extraBounce: 0)) {
            let today = dayBoundary.day(containing: .now, calendar: calendar)
            if let customStartDate, let customEndDate {
                let start = dayBoundary.day(
                    containing: min(customStartDate, customEndDate),
                    calendar: calendar
                )
                let end = dayBoundary.day(
                    containing: max(customStartDate, customEndDate),
                    calendar: calendar
                )
                let distance = calendar.dateComponents([.day], from: start, to: end).day ?? 0
                self.customEndDate = today
                self.customStartDate = calendar.date(byAdding: .day, value: -distance, to: today) ?? today
            }
            anchorDate = today
        }
    }

    private func selectPeriod(_ period: StatisticsPeriod) {
        withAnimation(.snappy(duration: 0.34, extraBounce: 0)) {
            if period == .year,
               calendar.component(.year, from: anchorDate) > calendar.component(.year, from: .now) {
                anchorDate = dayBoundary.day(containing: .now, calendar: calendar)
            }
            customStartDate = nil
            customEndDate = nil
            selectedPeriod = period
        }
    }

    private var canMoveToNextPeriod: Bool {
        if let customStartDate, let customEndDate {
            let start = dayBoundary.day(
                containing: min(customStartDate, customEndDate),
                calendar: calendar
            )
            let end = dayBoundary.day(
                containing: max(customStartDate, customEndDate),
                calendar: calendar
            )
            let dayCount = max(
                1,
                (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
            )
            let nextEnd = calendar.date(byAdding: .day, value: dayCount, to: end) ?? end
            return nextEnd <= today
        }
        let nextStart = selectedPeriod.offset(
            periodBounds.currentStart,
            by: 1,
            calendar: calendar
        )
        return nextStart <= today
    }

    private func prepareCustomRangeDraft() {
        if let customStartDate, let customEndDate {
            customStartDraft = min(customStartDate, today)
            customEndDraft = min(customEndDate, today)
            return
        }
        customStartDraft = min(periodBounds.currentStart, today)
        customEndDraft = min(calendar.date(
            byAdding: .day,
            value: -1,
            to: periodBounds.currentEnd
        ) ?? periodBounds.currentStart, today)
    }

    private func applyCustomRange() {
        let requestedEnd = dayBoundary.day(
            containing: max(customStartDraft, customEndDraft),
            calendar: calendar
        )
        let end = min(requestedEnd, today)
        let start = min(
            dayBoundary.day(
                containing: min(customStartDraft, customEndDraft),
                calendar: calendar
            ),
            end
        )
        withAnimation(.snappy(duration: 0.34, extraBounce: 0)) {
            customStartDate = start
            customEndDate = end
            anchorDate = start
            isCustomRangePresented = false
        }
    }

    private func prepareExportDraft() {
        exportContent = .all
        exportStartDate = min(periodBounds.currentStart, today)
        exportEndDate = min(calendar.date(
            byAdding: .day,
            value: -1,
            to: periodBounds.currentEnd
        ) ?? periodBounds.currentStart, today)
        exportAreaID = selectedAreaID
        exportQuery = searchText
        exportShareURL = nil
        preparedExportConfiguration = nil
        isPreparingExport = false
    }

    private func cache(_ projection: StatisticsPeriodSnapshot) {
        cachedSnapshot = projection
        snapshotCache[projection.filter] = projection
        snapshotCacheOrder.removeAll { $0 == projection.filter }
        snapshotCacheOrder.append(projection.filter)

        while snapshotCacheOrder.count > 4 {
            let expiredFilter = snapshotCacheOrder.removeFirst()
            snapshotCache[expiredFilter] = nil
        }
    }

    @MainActor
    private func prepareExportShareURL(
        for configuration: StatisticsExportConfiguration
    ) async {
        isPreparingExport = true
        exportShareURL = nil
        preparedExportConfiguration = nil

        let projection: StatisticsPeriodSnapshot
        if configuration.filter == filter, let currentSnapshot {
            projection = currentSnapshot
        } else {
            let loader = StatisticsProjectionActor(modelContainer: modelContext.container)
            do {
                projection = try await loader.load(
                    filter: configuration.filter,
                    calendar: calendar,
                    dayBoundary: dayBoundary
                )
            } catch {
                guard !Task.isCancelled, configuration == exportConfiguration else { return }
                PersistenceIssueCenter.shared.report(error, operation: .export)
                isPreparingExport = false
                return
            }
        }

        guard !Task.isCancelled, configuration == exportConfiguration else { return }
        let exportCalendar = calendar
        let filename = exportFilename(for: projection, content: configuration.content)
        let result: URL?
        do {
            result = try await Task.detached(priority: .utility) {
                let csv = StatisticsCSVExporter().export(
                    rows: projection.csvRows,
                    content: configuration.content,
                    calendar: exportCalendar
                )
                return try StatisticsCSVTemporaryFileWriter().write(
                    csv: csv,
                    filename: filename
                )
            }.value
        } catch {
            PersistenceIssueCenter.shared.report(error, operation: .export)
            result = nil
        }
        guard !Task.isCancelled, configuration == exportConfiguration else { return }
        exportShareURL = result
        preparedExportConfiguration = result == nil ? nil : configuration
        isPreparingExport = false
    }

}

private struct StatisticsCustomRangePopover: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let maximumDate: Date
    let onCancel: () -> Void
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "期間を指定"))
                .font(.headline)

            VStack(spacing: 12) {
                DatePicker(
                    String(localized: "開始日"),
                    selection: $startDate,
                    in: ...maximumDate,
                    displayedComponents: .date
                )
                DatePicker(
                    String(localized: "終了日"),
                    selection: $endDate,
                    in: ...maximumDate,
                    displayedComponents: .date
                )
            }
            .datePickerStyle(.field)

            HStack {
                Spacer()
                Button(String(localized: "キャンセル"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "完了"), action: onApply)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 300)
        .onChange(of: startDate) { _, newValue in
            if endDate < newValue {
                endDate = newValue
            }
        }
    }
}

private enum StatisticsDistributionDimension: String, CaseIterable, Identifiable {
    case task
    case area

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .task:
            String(localized: "タスク別")
        case .area:
            String(localized: "方向別")
        }
    }
}

private struct StatisticsAreaFilterMenu: View {
    @Binding var selectedAreaID: UUID?
    let areas: [Area]
    let selectedArea: Area?

    var body: some View {
        Menu {
            Button {
                selectedAreaID = nil
            } label: {
                menuRow(text: String(localized: "すべて"), isSelected: selectedAreaID == nil)
            }

            if !areas.isEmpty {
                Divider()
                ForEach(areas) { area in
                    Button {
                        selectedAreaID = area.id
                    } label: {
                        menuRow(
                            text: "\(area.symbolName) \(area.name)",
                            isSelected: selectedAreaID == area.id
                        )
                    }
                }
            }
        } label: {
            Image(systemName: ProductSymbol.area)
                .foregroundStyle(selectedAreaID == nil ? Color.primary : Color.accentColor)
        }
        .menuStyle(.borderlessButton)
        .help(filterHelp)
        .accessibilityLabel(String(localized: "方向フィルター"))
        .accessibilityValue(selectedArea?.name ?? String(localized: "すべて"))
    }

    private var filterHelp: String {
        selectedArea.map { "\(String(localized: "方向フィルター")): \($0.name)" }
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
                    title: String(localized: "集中回数"),
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

    @Binding var mode: StatisticsMode
    let period: StatisticsPeriod
    let points: [StatisticsTrendPoint]

    var body: some View {
        StatisticsCard(
            title: String(localized: "傾向"),
            subtitle: mode == .flow ? String(localized: "集中時間") : String(localized: "完了タスク"),
            headerAccessory: {
                StatisticsModePicker(selection: $mode)
            }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    Label(String(localized: "選択した期間"), systemImage: "minus")
                        .foregroundStyle(Color.accentColor)
                    Label(String(localized: "前の期間"), systemImage: "ellipsis")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)

                Group {
                    Chart {
                        ForEach(points) { point in
                            LineMark(
                                x: .value(String(localized: "日"), point.index),
                                y: .value(String(localized: "前の期間"), previousValue(point)),
                                series: .value(String(localized: "期間"), String(localized: "前の期間"))
                            )
                            .foregroundStyle(Color.secondary.opacity(0.55))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .interpolationMethod(.linear)

                            LineMark(
                                x: .value(String(localized: "日"), point.index),
                                y: .value(String(localized: "選択した期間"), currentValue(point)),
                                series: .value(String(localized: "期間"), String(localized: "選択した期間"))
                            )
                            .foregroundStyle(Color.accentColor)
                            .lineStyle(StrokeStyle(lineWidth: 2.2))
                            .interpolationMethod(.linear)

                            PointMark(
                                x: .value(String(localized: "日"), point.index),
                                y: .value(String(localized: "選択した期間"), currentValue(point))
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
                .id(mode)
                .transition(.opacity.combined(with: .scale(scale: 0.99)))
                .animation(.easeInOut(duration: 0.2), value: mode)
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
    var isCompact = false

    @State private var selectedItemID: String?

    private var selectedItem: StatisticsDistributionItem? {
        guard let selectedItemID else { return nil }
        return items.first { $0.id == selectedItemID }
    }

    private var displayedItems: [StatisticsDistributionItem] {
        selectedItem.map { [$0] } ?? items
    }

    var body: some View {
        let chartSize: CGFloat = isCompact ? 150 : 190
        let contentSpacing: CGFloat = isCompact ? 16 : 28

        StatisticsCard(
            title: String(localized: "集中時間の内訳"),
            minimumHeight: isCompact ? 288 : nil,
            headerAccessory: {
                Picker(String(localized: "内訳"), selection: $dimension) {
                    ForEach(StatisticsDistributionDimension.allCases) { dimension in
                        Text(dimension.displayName).tag(dimension)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 210)
                .controlSize(.small)
            }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if items.isEmpty {
                    StatisticsEmptyState(label: String(localized: "この期間の集中記録はありません"))
                        .frame(maxWidth: .infinity, minHeight: 190)
                } else {
                    HStack(spacing: contentSpacing) {
                        Chart(items) { item in
                            SectorMark(
                                angle: .value(String(localized: "集中時間"), item.focusSeconds),
                                innerRadius: .ratio(0.60),
                                outerRadius: .ratio(
                                    selectedItemID == nil || selectedItemID == item.id ? 1 : 0.96
                                ),
                                angularInset: 1.5
                            )
                            .cornerRadius(3)
                            .foregroundStyle(Color(hex: item.colorHex ?? "#8E8E93"))
                            .opacity(selectedItemID == nil || selectedItemID == item.id ? 1 : 0.16)
                        }
                        .chartLegend(.hidden)
                        .chartOverlay { _ in
                            GeometryReader { geometry in
                                Rectangle()
                                    .fill(.clear)
                                    .contentShape(Rectangle())
                                    .gesture(
                                        SpatialTapGesture()
                                            .onEnded { value in
                                                selectItem(
                                                    at: value.location,
                                                    in: geometry.size
                                                )
                                            }
                                    )
                            }
                        }
                        .frame(width: chartSize, height: chartSize)
                        .overlay {
                            VStack(spacing: 3) {
                                Text(StatisticsFormatting.duration(
                                    selectedItem?.focusSeconds ?? totalFocusSeconds
                                ))
                                    .font(.headline.monospacedDigit())
                                Text(selectedItem?.name ?? String(localized: "集中時間"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                if selectedItem != nil {
                                    Button {
                                        clearSelection()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.secondary)
                                    .help(String(localized: "すべて"))
                                }
                            }
                            .frame(maxWidth: chartSize * 0.52)
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(displayedItems) { item in
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
                                .font(isCompact ? .caption : .callout)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .animation(.easeInOut(duration: 0.18), value: selectedItemID)
                }
            }
        }
        .onChange(of: dimension) { _, _ in
            clearSelection()
        }
        .onChange(of: items.map(\.id)) { _, identifiers in
            if let selectedItemID, !identifiers.contains(selectedItemID) {
                clearSelection()
            }
        }
    }

    private func itemID(at angle: Double) -> String? {
        var upperBound = 0.0
        for item in items {
            upperBound += Double(max(0, item.focusSeconds))
            if angle <= upperBound {
                return item.id
            }
        }
        return items.last?.id
    }

    private func selectItem(at location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let deltaX = location.x - center.x
        let deltaY = location.y - center.y
        let outerRadius = min(size.width, size.height) / 2
        let distance = hypot(deltaX, deltaY)

        guard distance >= outerRadius * 0.42, distance <= outerRadius else { return }

        let radians = atan2(deltaX, -deltaY)
        let normalizedRadians = radians >= 0 ? radians : radians + (2 * .pi)
        let total = Double(items.reduce(0) { $0 + max(0, $1.focusSeconds) })
        guard total > 0 else { return }

        selectedItemID = itemID(at: normalizedRadians / (2 * .pi) * total)
    }

    private func clearSelection() {
        selectedItemID = nil
    }
}

private struct StatisticsDotsCard: View {
    @Environment(\.calendar) private var calendar

    @Binding var mode: StatisticsMode
    let period: StatisticsPeriod
    let usesCompactCustomGrid: Bool
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
            minimumHeight: period == .month ? 288 : nil,
            headerAccessory: {
                StatisticsModePicker(selection: $mode)
            }
        ) {
            StatisticsContributionGrid(
                days: contributionDays,
                period: period,
                usesCompactCustomGrid: usesCompactCustomGrid,
                onSelectDate: onSelectDate
            )
            .id(mode)
            .transition(.opacity.combined(with: .scale(scale: 0.99, anchor: .top)))
            .animation(.easeInOut(duration: 0.2), value: mode)
        }
    }
}

private struct StatisticsModePicker: View {
    @Binding var selection: StatisticsMode

    var body: some View {
        Picker(String(localized: "統計表示"), selection: $selection) {
            Text(StatisticsMode.flow.displayName).tag(StatisticsMode.flow)
            Text(StatisticsMode.achievement.displayName).tag(StatisticsMode.achievement)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 126)
        .controlSize(.small)
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
    let usesCompactCustomGrid: Bool
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
                            .frame(width: 12, height: 12)
                    }
                    Text(String(localized: "多い"))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var weekGrid: some View {
        let spacing: CGFloat = 7
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
                    .frame(height: 42)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let spacing: CGFloat = usesCompactCustomGrid ? 5 : 6
        let cellSize: CGFloat = usesCompactCustomGrid ? 18 : 24
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
                    onSelectDate: onSelectDate
                )
                .frame(
                    minWidth: usesCompactCustomGrid ? cellSize : nil,
                    maxWidth: usesCompactCustomGrid ? cellSize : .infinity,
                    minHeight: usesCompactCustomGrid ? cellSize : 32,
                    maxHeight: usesCompactCustomGrid ? cellSize : 32
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var yearGrid: some View {
        let weekdays = CalendarWeekdaySymbols.orderedAbbreviated(calendar: calendar)
        return Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            ForEach(Array(weekdays.enumerated()), id: \.offset) { weekdayIndex, weekday in
                GridRow {
                    Text(weekday)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 18)

                    ForEach(0..<yearWeekCount, id: \.self) { weekIndex in
                        StatisticsContributionCell(
                            day: contributionDay(week: weekIndex, weekday: weekdayIndex),
                            maxValue: maxValue,
                            isInteractive: false,
                            onSelectDate: onSelectDate
                        )
                        .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }

    private var yearWeekCount: Int {
        max(1, Int(ceil(Double(paddedDays.count) / 7)))
    }

    private func contributionDay(week: Int, weekday: Int) -> StatisticsContributionDay? {
        let index = week * 7 + weekday
        guard paddedDays.indices.contains(index) else { return nil }
        return paddedDays[index]
    }
}

private struct StatisticsContributionCell: View {
    @Environment(\.locale) private var locale

    let day: StatisticsContributionDay?
    let maxValue: Int
    let isInteractive: Bool
    let onSelectDate: (Date) -> Void

    @State private var isHovered = false

    init(
        day: StatisticsContributionDay?,
        maxValue: Int,
        isInteractive: Bool = true,
        onSelectDate: @escaping (Date) -> Void
    ) {
        self.day = day
        self.maxValue = maxValue
        self.isInteractive = isInteractive
        self.onSelectDate = onSelectDate
    }

    @ViewBuilder
    var body: some View {
        if isInteractive {
            Button {
                guard let day else { return }
                onSelectDate(day.date)
            } label: {
                cellShape
                    .scaleEffect(isHovered && day != nil ? 1.08 : 1)
            }
            .buttonStyle(.plain)
            .disabled(day == nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .popover(
                isPresented: $isHovered,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: .bottom
            ) {
                if let day {
                    StatisticsContributionPopover(day: day)
                        .allowsHitTesting(false)
                }
            }
            .onHover { hovering in
                isHovered = hovering && day != nil
            }
            .accessibilityLabel(helpText)
            .accessibilityHint(String(localized: "この日の履歴を開く"))
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

private struct StatisticsYearPicker: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Binding var selectedDate: Date

    private var selectedYear: Int { calendar.component(.year, from: selectedDate) }
    private var currentYear: Int { calendar.component(.year, from: .now) }
    private var years: [Int] {
        let lower = min(selectedYear, currentYear - 9)
        return Array((lower...currentYear).reversed())
    }

    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(years, id: \.self) { year in
                Button {
                    select(year)
                } label: {
                    HStack {
                        Text(label(for: year))
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
        guard let date = date(for: year) else { return }
        selectedDate = calendar.startOfDay(for: date)
    }

    private func label(for year: Int) -> String {
        date(for: year)?.formatted(.dateTime.locale(locale).year()) ?? String(year)
    }

    private func date(for year: Int) -> Date? {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = 1
        components.day = 1
        return components.date
    }
}

private struct StatisticsLoadingCards: View {
    let period: StatisticsPeriod

    private let summaryColumns = [
        GridItem(.adaptive(minimum: 128, maximum: 220), spacing: 10)
    ]

    var body: some View {
        StatisticsCard(title: String(localized: "概要")) {
            LazyVGrid(columns: summaryColumns, spacing: 10) {
                ForEach(0..<5, id: \.self) { _ in
                    loadingBlock(height: 106)
                }
            }
        }

        StatisticsCard(
            title: String(localized: "傾向"),
            subtitle: String(localized: "集中時間")
        ) {
            ZStack {
                loadingBlock(height: 220)
                ProgressView()
                    .controlSize(.regular)
            }
        }

        switch period {
        case .week, .year:
            loadingLowerCard(title: String(localized: "集中時間の内訳"))
            loadingLowerCard(title: String(localized: "Dots"))
        case .month:
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    loadingLowerCard(title: String(localized: "集中時間の内訳"))
                        .frame(minWidth: 350, maxWidth: .infinity, minHeight: 320, maxHeight: 320)
                    loadingLowerCard(title: String(localized: "Dots"))
                        .frame(minWidth: 300, maxWidth: .infinity, minHeight: 320, maxHeight: 320)
                }

                VStack(spacing: 16) {
                    loadingLowerCard(title: String(localized: "集中時間の内訳"))
                    loadingLowerCard(title: String(localized: "Dots"))
                }
            }
        }
    }

    private func loadingLowerCard(title: String) -> some View {
        StatisticsCard(title: title) {
            loadingBlock(height: 250)
        }
    }

    private func loadingBlock(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Color.secondary.opacity(0.08))
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .accessibilityHidden(true)
    }
}

private struct StatisticsCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let minimumHeight: CGFloat?
    let headerAccessory: AnyView?
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        minimumHeight: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.minimumHeight = minimumHeight
        self.headerAccessory = nil
        self.content = content()
    }

    init<HeaderAccessory: View>(
        title: String,
        subtitle: String? = nil,
        minimumHeight: CGFloat? = nil,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.minimumHeight = minimumHeight
        self.headerAccessory = AnyView(headerAccessory())
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if let headerAccessory {
                    headerAccessory
                }
            }
            content
        }
        .frame(
            maxWidth: .infinity,
            minHeight: minimumHeight,
            alignment: .topLeading
        )
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

private extension StatisticsCSVContent {
    var displayName: String {
        switch self {
        case .all:
            String(localized: "すべて")
        case .flow:
            String(localized: "集中記録")
        case .task:
            String(localized: "タスク")
        }
    }
}

private struct StatisticsExportConfiguration: Hashable, Sendable {
    let content: StatisticsCSVContent
    let filter: StatisticsPeriodFilter
}

private struct StatisticsCSVTemporaryFileWriter {
    nonisolated init() {}

    nonisolated func write(csv: String, filename: String) throws -> URL {
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
    let customStartDate: Date?
    let customEndDate: Date?
    let areaID: UUID?
    let query: String
    let areaCount: Int
    let latestAreaUpdate: Date?
}

#Preview {
    StatisticsPreviewHost()
}

private struct StatisticsPreviewHost: View {
    @State private var snapshot: StatisticsPeriodSnapshot?

    var body: some View {
        NavigationStack {
            StatisticsView(
                areas: [],
                cachedSnapshot: $snapshot
            )
        }
        .frame(width: 1180, height: 820)
        .modelContainer(
            for: [Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self],
            inMemory: true
        )
    }
}
