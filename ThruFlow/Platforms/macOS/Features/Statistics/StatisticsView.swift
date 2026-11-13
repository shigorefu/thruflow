//
//  StatisticsView.swift
//  ThruFlow
//
//

import Combine
import CoreData
import SwiftData
import SwiftUI

struct StatisticsView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext

    let areas: [Area]
    @Binding private var cache: StatisticsPresentationCache
    @Binding private var filter: StatisticsPeriodFilter
    let onSelectHistoryDate: (Date) -> Void
    private let isVisible: Bool

    @State private var didScrollToScreenshotCard = false
    @State private var customStartDraft = Date.now
    @State private var customEndDraft = Date.now
    @State private var isCustomRangePresented = false
    @State private var isSearchPresented = false
    @State private var distributionDimension: StatisticsDistributionDimension = .task
    @State private var trendMode: StatisticsMode = .flow
    @State private var dotsMode: StatisticsMode = .flow
    @State private var searchDeadline: ContinuousClock.Instant?
    @State private var failedRequest: StatisticsPeriodRefreshID?
    @State private var partialReport: StatisticsPartialPresentation?
    @State private var persistenceRevision = 0
    @State private var isExportPresented = false
    @State private var exportContent: StatisticsCSVContent = .all
    @State private var exportStartDate = Date.now
    @State private var exportEndDate = Date.now
    @State private var exportAreaIDs: Set<UUID> = []
    @State private var exportQuery = ""
    @State private var exportShareURL: URL?
    @State private var preparedExportConfiguration: StatisticsExportConfiguration?
    @State private var isPreparingExport = false

    init(
        areas: [Area],
        cache: Binding<StatisticsPresentationCache>,
        selection: Binding<StatisticsPeriodFilter>,
        isVisible: Bool = true,
        onSelectHistoryDate: @escaping (Date) -> Void = { _ in }
    ) {
        self.areas = areas
        self.isVisible = isVisible
        _cache = cache
        _filter = selection
        self.onSelectHistoryDate = onSelectHistoryDate
    }

    private var activeAreas: [Area] {
        areas
            .filter { !$0.isArchived }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var exportFilter: StatisticsPeriodFilter {
        StatisticsPeriodFilter(
            period: .month,
            anchorDate: exportStartDate,
            customStartDate: exportStartDate,
            customEndDate: exportEndDate,
            areaIDs: exportAreaIDs,
            query: exportQuery
        )
    }

    private var exportConfiguration: StatisticsExportConfiguration {
        StatisticsExportConfiguration(content: exportContent, filter: exportFilter)
    }

    private var currentSnapshot: StatisticsPeriodSnapshot? {
        cache.snapshot(for: filter, calendar: calendar, dayBoundary: dayBoundary)
    }

    private var periodBounds: StatisticsPeriodBounds {
        StatisticsPeriodBuilder(
            calendar: calendar,
            dayBoundary: dayBoundary
        ).bounds(for: filter)
    }

    private var usesCustomRange: Bool {
        filter.usesCustomRange
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
        guard usesCustomRange else { return filter.period }
        if displayedDayCount <= 7 { return .week }
        if displayedDayCount <= 62 { return .month }
        return .year
    }

    private var today: Date {
        dayBoundary.day(containing: .now, calendar: calendar)
    }

    var body: some View {
        let request = refreshID
        return workspace(request: request)
            .toolbar {
                if isVisible {
                    statisticsToolbar
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave).receive(on: RunLoop.main)) { _ in
                guard isVisible else { return }
                persistenceRevision &+= 1
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: RunLoop.main)) { _ in
                guard isVisible else { return }
                persistenceRevision &+= 1
            }
            .task(id: isVisible ? request : nil) {
                guard isVisible else {
                    partialReport = nil
                    return
                }
                await refreshStatisticsWhileVisible(request)
            }
    }

    private func workspace(request: StatisticsPeriodRefreshID) -> some View {
        let snapshot = currentSnapshot
        let cards = snapshot.map { StatisticsPresentationCards(snapshot: $0) }
            ?? (partialReport?.request == request ? partialReport?.cards : nil)
            ?? StatisticsPresentationCards()
        let presentationID = StatisticsCardPresentationID(
            filter: filter,
            calendar: calendar,
            dayBoundary: dayBoundary,
            isVisible: isVisible
        )
        let didFail = snapshot == nil && failedRequest == request
        let reportPadding: CGFloat = 12
        // Screenshot scrolling needs the final heights of the preceding cards.
        let screenshotAnchor: String? = switch (snapshot != nil, ScreenshotMode.initialScreen()) {
        case (true, .statisticsDots): "screenshot-statistics-dots"
        case (true, .statisticsTrend): "screenshot-statistics-trend"
        case (true, .statisticsBreakdown): "screenshot-statistics-breakdown"
        default: nil
        }

        return GeometryReader { geometry in
            let calendarWidth = MacCalendarSidebarLayout.width(
                for: periodTitle,
                in: geometry.size.width,
                preferredFraction: 0.27,
                minimum: 330,
                maximum: 430
            )
            HStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            StatisticsReportCards(
                                cards: cards,
                                presentationID: presentationID,
                                showsLoading: !didFail,
                                reportWidth: max(0, geometry.size.width - calendarWidth - 2 * reportPadding - 1),
                                periodTitle: periodTitle,
                                today: today,
                                presentationPeriod: presentationPeriod,
                                usesCustomRange: usesCustomRange,
                                usesCompactCustomGrid: usesCustomRange && displayedDayCount > 7,
                                marksOutsideMonth: filter.period == .month && !usesCustomRange,
                                distributionDimension: $distributionDimension,
                                trendMode: $trendMode,
                                dotsMode: $dotsMode,
                                onSelectHistoryDate: onSelectHistoryDate
                            )
                            if didFail {
                                ContentUnavailableView(
                                    String(localized: "データを読み込めませんでした。"),
                                    systemImage: "exclamationmark.circle"
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(reportPadding)
                    }
                    .task(id: screenshotAnchor) {
                        guard let screenshotAnchor, !didScrollToScreenshotCard else { return }
                        await Task.yield()
                        guard !Task.isCancelled else { return }
                        proxy.scrollTo(screenshotAnchor, anchor: .top)
                        didScrollToScreenshotCard = true
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                statisticsCalendarSidebar(days: cards.days)
                    .frame(width: calendarWidth)
            }
        }
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
                StatisticsExportPopover(
                    exportContent: $exportContent,
                    exportStartDate: $exportStartDate,
                    exportEndDate: $exportEndDate,
                    exportAreaIDs: $exportAreaIDs,
                    exportQuery: $exportQuery,
                    today: today,
                    activeAreas: activeAreas,
                    isPreparingExport: isPreparingExport,
                    exportShareURL: exportShareURL,
                    preparedExportConfiguration: preparedExportConfiguration,
                    exportConfiguration: exportConfiguration,
                    prepareExportShareURL: prepareExportShareURL
                )
            }
        }

        ToolbarItem(placement: .primaryAction) {
            StatisticsAreaSelectionMenu(
                selectedAreaIDs: $filter.areaIDs,
                areas: activeAreas
            )
        }

        ToolbarItem(placement: .primaryAction) {
            MacToolbarSearchControl(
                text: searchTextBinding,
                isPresented: $isSearchPresented
            )
        }
    }

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { filter.query },
            set: { query in
                guard query != filter.query else { return }
                searchDeadline = ContinuousClock.now.advanced(by: .milliseconds(250))
                filter.query = query
            }
        )
    }

    private func statisticsCalendarSidebar(days: StatisticsPresentationDays?) -> some View {
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
                    switch filter.period {
                    case .week:
                        HistoryMiniCalendar(
                            selectedDate: anchorDateBinding,
                            selectionMode: .week,
                            indicatorSource: .statistics(calendarIndicators(from: days)),
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
            get: { usesCustomRange ? nil : filter.period },
            set: { period in
                guard let period else { return }
                selectPeriod(period)
            }
        )
    }

    private var anchorDateBinding: Binding<Date> {
        Binding(
            get: { filter.anchorDate },
            set: {
                var updatedFilter = filter
                updatedFilter.customStartDate = nil
                updatedFilter.customEndDate = nil
                updatedFilter.anchorDate = StatisticsPeriodBuilder(
                    calendar: calendar,
                    dayBoundary: dayBoundary
                ).anchorDate(forCalendarSelection: $0, maximumDate: today)
                filter = updatedFilter
            }
        )
    }

    private func calendarIndicators(from days: StatisticsPresentationDays?) -> [StatisticsCalendarIndicator] {
        guard let days else { return [] }
        let achievements = Dictionary(
            uniqueKeysWithValues: days.achievement.map { ($0.date, $0) }
        )
        return days.flow.compactMap { day in
            let achievement = achievements[day.date]
            guard !day.isEmpty || achievement?.isEmpty == false else { return nil }
            return StatisticsCalendarIndicator(
                date: day.date,
                colorHex: day.mixedColorHex ?? achievement?.mixedColorHex ?? "#34C759"
            )
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

        switch filter.period {
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
            filter: filter,
            areaCount: areas.count,
            latestAreaUpdate: areas.map(\.updatedAt).max(),
            persistenceRevision: persistenceRevision,
            calendar: calendar,
            dayBoundaryHour: dayBoundary.hour
        )
    }

    @MainActor
    private func refreshStatisticsWhileVisible(_ request: StatisticsPeriodRefreshID) async {
        if let searchDeadline, searchDeadline > ContinuousClock.now {
            do {
                try await Task.sleep(until: searchDeadline, clock: .continuous)
            } catch {
                return
            }
        }
        guard !Task.isCancelled, request == refreshID else { return }

        while !Task.isCancelled {
            await refreshStatisticsCache(request)
            do {
                try await Task.sleep(for: .seconds(30))
            } catch {
                return
            }
        }
    }

    @MainActor
    private func refreshStatisticsCache(_ request: StatisticsPeriodRefreshID) async {
        let requestedBoundary = AppDayBoundary(hour: request.dayBoundaryHour)
        do {
            let updates = StatisticsProjectionActor.presentationUpdates(
                modelContainer: modelContext.container,
                filter: request.filter,
                calendar: request.calendar,
                dayBoundary: requestedBoundary
            )
            for try await update in updates {
                guard !Task.isCancelled, request == refreshID else { return }
                switch update {
                case .report(let projection):
                    cache.store(projection, calendar: request.calendar, dayBoundary: requestedBoundary)
                    partialReport = nil
                    failedRequest = nil
                default:
                    if currentSnapshot == nil {
                        var cards = partialReport?.request == request
                            ? partialReport?.cards ?? StatisticsPresentationCards()
                            : StatisticsPresentationCards()
                        cards.apply(update)
                        partialReport = StatisticsPartialPresentation(request: request, cards: cards)
                        failedRequest = nil
                    }
                }
            }
        } catch {
            guard !Task.isCancelled, !(error is CancellationError), request == refreshID else { return }
            failedRequest = request
            PersistenceIssueCenter.shared.log(error, operation: .dataLoad)
        }
    }

    private func movePeriod(by value: Int) {
        guard value <= 0 || canMoveToNextPeriod else { return }
        if let customStartDate = filter.customStartDate, let customEndDate = filter.customEndDate {
            let start = calendar.startOfDay(for: min(customStartDate, customEndDate))
            let end = calendar.startOfDay(for: max(customStartDate, customEndDate))
            let dayCount = max(
                1,
                (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
            )
            let offset = value * dayCount
            let nextStart = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            var updatedFilter = filter
            updatedFilter.customStartDate = nextStart
            updatedFilter.customEndDate = calendar.date(byAdding: .day, value: offset, to: end) ?? end
            updatedFilter.anchorDate = nextStart
            filter = updatedFilter
            return
        }
        filter.anchorDate = filter.period.offset(filter.anchorDate, by: value, calendar: calendar)
    }

    private func moveToToday() {
        var updatedFilter = filter
        if let customStartDate = filter.customStartDate, let customEndDate = filter.customEndDate {
            let start = calendar.startOfDay(for: min(customStartDate, customEndDate))
            let end = calendar.startOfDay(for: max(customStartDate, customEndDate))
            let distance = calendar.dateComponents([.day], from: start, to: end).day ?? 0
            updatedFilter.customEndDate = today
            updatedFilter.customStartDate = calendar.date(byAdding: .day, value: -distance, to: today) ?? today
        }
        updatedFilter.anchorDate = today
        filter = updatedFilter
    }

    private func selectPeriod(_ period: StatisticsPeriod) {
        var updatedFilter = filter
        if period == .year,
           calendar.component(.year, from: filter.anchorDate) > calendar.component(.year, from: .now) {
            updatedFilter.anchorDate = today
        }
        updatedFilter.customStartDate = nil
        updatedFilter.customEndDate = nil
        updatedFilter.period = period
        filter = updatedFilter
    }

    private var canMoveToNextPeriod: Bool {
        if let customStartDate = filter.customStartDate, let customEndDate = filter.customEndDate {
            let start = calendar.startOfDay(for: min(customStartDate, customEndDate))
            let end = calendar.startOfDay(for: max(customStartDate, customEndDate))
            let dayCount = max(
                1,
                (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
            )
            let nextEnd = calendar.date(byAdding: .day, value: dayCount, to: end) ?? end
            return nextEnd <= today
        }
        let nextStart = filter.period.offset(
            periodBounds.currentStart,
            by: 1,
            calendar: calendar
        )
        return nextStart <= today
    }

    private func prepareCustomRangeDraft() {
        if let customStartDate = filter.customStartDate, let customEndDate = filter.customEndDate {
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
        let requestedEnd = calendar.startOfDay(for: max(customStartDraft, customEndDraft))
        let end = min(requestedEnd, today)
        let start = min(
            calendar.startOfDay(for: min(customStartDraft, customEndDraft)),
            end
        )
        var updatedFilter = filter
        updatedFilter.customStartDate = start
        updatedFilter.customEndDate = end
        updatedFilter.anchorDate = start
        filter = updatedFilter
        isCustomRangePresented = false
    }

    private func prepareExportDraft() {
        exportContent = .all
        exportStartDate = min(periodBounds.currentStart, today)
        exportEndDate = min(calendar.date(
            byAdding: .day,
            value: -1,
            to: periodBounds.currentEnd
        ) ?? periodBounds.currentStart, today)
        exportAreaIDs = filter.areaIDs
        exportQuery = filter.query
        exportShareURL = nil
        preparedExportConfiguration = nil
        isPreparingExport = false
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

private struct StatisticsPartialPresentation {
    let request: StatisticsPeriodRefreshID
    let cards: StatisticsPresentationCards
}

private struct StatisticsPeriodRefreshID: Hashable {
    let filter: StatisticsPeriodFilter
    let areaCount: Int
    let latestAreaUpdate: Date?
    let persistenceRevision: Int
    let calendar: Calendar
    let dayBoundaryHour: Int
}

#Preview {
    StatisticsPreviewHost()
}

private struct StatisticsPreviewHost: View {
    @State private var cache = StatisticsPresentationCache()
    @State private var selection = StatisticsPeriodFilter()

    var body: some View {
        NavigationStack {
            StatisticsView(
                areas: [],
                cache: $cache,
                selection: $selection
            )
        }
        .frame(width: 1180, height: 820)
        .modelContainer(
            for: [Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self],
            inMemory: true
        )
    }
}
