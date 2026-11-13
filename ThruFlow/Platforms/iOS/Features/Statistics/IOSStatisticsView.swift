import Combine
import CoreData
import SwiftData
import SwiftUI

struct IOSStatisticsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext

    @Binding private var cache: StatisticsPresentationCache
    @Binding private var filter: StatisticsPeriodFilter
    let isVisible: Bool
    let onOpenHistoryDate: (Date) -> Void

    @State private var didScrollToScreenshotDots = false
    @State private var anchorDateDraft = Date.now
    @State private var customStartDraft = Date.now
    @State private var customEndDraft = Date.now
    @State private var searchText: String
    @State private var searchDebounceDeadline: ContinuousClock.Instant?
    @State private var trendMode: StatisticsMode = .flow
    @State private var dotsMode: StatisticsMode = .flow
    @State private var distributionDimension: IOSStatisticsDistributionDimension = .task
    @State private var persistenceRevision = 0
    @State private var failedRequest: IOSStatisticsPeriodRefreshID?
    @State private var reportReveal = 0
    @State private var stagedReportRequest: IOSStatisticsPeriodRefreshID?
    @State private var partialSummary: IOSStatisticsPartialSummary?
    @State private var loadsAreas = false
    @State private var areas: [Area] = []
    @State private var selectedContributionDay: IOSStatisticsContributionDay?
    @State private var isAnchorPickerPresented = false
    @State private var isCustomRangePresented = false
    @State private var isExportPresented = false
    @State private var exportContent: StatisticsCSVContent = .all
    @State private var exportStartDate = Date.now
    @State private var exportEndDate = Date.now
    @State private var exportAreaIDs: Set<UUID> = []
    @State private var exportQuery = ""
    @State private var exportShareURL: URL?
    @State private var preparedExportConfiguration: IOSStatisticsExportConfiguration?
    @State private var isPreparingExport = false

    init(
        isVisible: Bool = true,
        cache: Binding<StatisticsPresentationCache>,
        selection: Binding<StatisticsPeriodFilter>,
        onOpenHistoryDate: @escaping (Date) -> Void = { _ in }
    ) {
        self.isVisible = isVisible
        _cache = cache
        _filter = selection
        _searchText = State(initialValue: selection.wrappedValue.query)
        self.onOpenHistoryDate = onOpenHistoryDate
    }

    private var activeAreas: [Area] {
        areas
            .filter { !$0.isArchived }
            .sorted {
                if $0.sortIndex != $1.sortIndex {
                    return $0.sortIndex < $1.sortIndex
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    private var selectedPeriod: StatisticsPeriod { filter.period }
    private var anchorDate: Date { filter.anchorDate }
    private var customStartDate: Date? { filter.customStartDate }
    private var customEndDate: Date? { filter.customEndDate }

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
        guard usesCustomRange else { return selectedPeriod }
        if displayedDayCount <= 7 { return .week }
        if displayedDayCount <= 62 { return .month }
        return .year
    }

    private var today: Date {
        dayBoundary.day(containing: .now, calendar: calendar)
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

    private var exportConfiguration: IOSStatisticsExportConfiguration {
        IOSStatisticsExportConfiguration(content: exportContent, filter: exportFilter)
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            statisticsScreen.searchToolbarBehavior(.minimize)
        } else {
            statisticsScreen
        }
    }

    private var statisticsScreen: some View {
        let request = refreshID
        let report = currentSnapshot
        let visibleReport = stagedReportRequest == request ? nil : report
        let summary = report.map {
            StatisticsPresentationSummary(summary: $0.summary, previousSummary: $0.previousSummary)
        } ?? (partialSummary?.request == request ? partialSummary?.value : nil)
        return ScrollViewReader { proxy in
            statisticsContent(summary: summary, report: visibleReport, request: request)
                .task(id: visibleReport?.filter) {
                    guard isVisible, ScreenshotMode.initialScreen() == .statisticsDots,
                          visibleReport != nil, !didScrollToScreenshotDots else { return }
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    proxy.scrollTo("screenshot-statistics-dots", anchor: .top)
                    didScrollToScreenshotDots = true
                }
        }
        .background {
            if isVisible, loadsAreas {
                IOSStatisticsAreaQuery { areas = $0 }
            }
        }
        .background(Color.primary.opacity(0.025).ignoresSafeArea())
        .iosCenteredNavigationTitle(String(localized: "統計"))
        .searchable(text: $searchText, placement: .toolbar, prompt: Text(String(localized: "検索")))
        .onChange(of: searchText) { _, query in
            guard query != filter.query else { return }
            searchDebounceDeadline = ContinuousClock().now + .milliseconds(250)
            filter.query = query
        }
        .toolbar { statisticsToolbar }
        .sheet(isPresented: $isAnchorPickerPresented) {
            IOSStatisticsAnchorSheet(
                date: $anchorDateDraft,
                maximumDate: today,
                onApply: applyAnchorDate
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isCustomRangePresented) {
            IOSStatisticsCustomRangeSheet(
                startDate: $customStartDraft,
                endDate: $customEndDraft,
                maximumDate: today,
                onApply: applyCustomRange
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $isExportPresented) {
            IOSStatisticsExportSheet(
                exportContent: $exportContent,
                exportStartDate: $exportStartDate,
                exportEndDate: $exportEndDate,
                exportAreaIDs: $exportAreaIDs,
                exportQuery: $exportQuery,
                maximumDate: today,
                activeAreas: activeAreas,
                exportConfiguration: exportConfiguration,
                exportShareURL: preparedExportConfiguration == exportConfiguration ? exportShareURL : nil,
                isPreparingExport: isPreparingExport,
                onClose: { isExportPresented = false },
                onPrepareExport: prepareExportShareURL
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedContributionDay) { day in
            IOSStatisticsDaySheet(day: day) {
                selectedContributionDay = nil
                DispatchQueue.main.async {
                    onOpenHistoryDate(day.date)
                }
            }
            .presentationDetents([.height(260)])
        }
        .task(id: request) {
            await refreshStatisticsWhileVisible()
        }
        .task(id: isVisible) {
            guard isVisible else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            loadsAreas = true
        }
        .task(id: isVisible ? stagedReportRequest : nil) {
            guard isVisible, stagedReportRequest == request else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            stagedReportRequest = nil
            reportReveal &+= 1
        }
        .onChange(of: isVisible) { _, visible in
            if !visible {
                searchDebounceDeadline = nil
                failedRequest = nil
                partialSummary = nil
                stagedReportRequest = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave).receive(on: RunLoop.main)) { _ in
            if isVisible { persistenceRevision &+= 1 }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: RunLoop.main)) { _ in
            if isVisible { persistenceRevision &+= 1 }
        }
    }

    private func statisticsContent(
        summary: StatisticsPresentationSummary?,
        report: StatisticsPeriodSnapshot?,
        request: IOSStatisticsPeriodRefreshID
    ) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                IOSStatisticsPeriodNavigationCard(
                    selection: selectedPeriodBinding,
                    usesCustomRange: usesCustomRange,
                    periodTitle: periodTitle,
                    canMoveToNextPeriod: canMoveToNextPeriod,
                    onCustomRange: {
                        prepareCustomRangeDraft()
                        isCustomRangePresented = true
                    },
                    onAnchorPicker: {
                        anchorDateDraft = anchorDate
                        isAnchorPickerPresented = true
                    },
                    onToday: moveToToday,
                    onMovePeriod: movePeriod
                )

                if let summary {
                    summaryCard(summary)
                }
                if let report {
                    chartCards(report)
                } else if failedRequest == request {
                    ContentUnavailableView(
                        String(localized: "データを読み込めませんでした。"),
                        systemImage: "exclamationmark.triangle"
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    FeatureLoadingIndicator()
                        .frame(minHeight: summary == nil ? 210 : 120)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: reportReveal)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 1_000)
            .frame(maxWidth: .infinity)
        }
    }

    private func summaryCard(_ value: StatisticsPresentationSummary) -> some View {
        IOSStatisticsSummaryCard(
            title: periodTitle,
            summary: value.summary,
            previousSummary: value.previousSummary
        )
    }

    @ViewBuilder
    private func chartCards(_ currentSnapshot: StatisticsPeriodSnapshot) -> some View {
        HabitCompletionCard(summary: currentSnapshot.habitCompletion)
        IOSStatisticsTrendCard(
            mode: $trendMode,
            period: currentSnapshot.trendPeriod,
            points: currentSnapshot.trend,
            today: today
        )
        IOSStatisticsDistributionCard(
            dimension: $distributionDimension,
            items: distributionItems(in: currentSnapshot),
            totalFocusSeconds: currentSnapshot.summary.totalFocusSeconds
        )
        IOSStatisticsDotsCard(
            mode: $dotsMode,
            period: presentationPeriod,
            marksOutsideMonth: selectedPeriod == .month && !usesCustomRange,
            usesCustomRange: usesCustomRange,
            flowDays: currentSnapshot.flowDays,
            achievementDays: currentSnapshot.achievementDays,
            maximumInteractiveDate: today,
            onSelectDay: { selectedContributionDay = $0 }
        )
        .id("screenshot-statistics-dots")
    }

    @ToolbarContentBuilder
    private var statisticsToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 8) {
                Button {
                    prepareExportDraft()
                    isExportPresented = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(String(localized: "CSVを書き出す"))

                StatisticsAreaSelectionMenu(
                    selectedAreaIDs: $filter.areaIDs,
                    areas: activeAreas
                )
            }
            .fixedSize()
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

    private func distributionItems(
        in snapshot: StatisticsPeriodSnapshot
    ) -> [StatisticsDistributionItem] {
        switch distributionDimension {
        case .task:
            snapshot.taskDistribution
        case .area:
            snapshot.areaDistribution
        case .project:
            snapshot.projectDistribution
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
            let end = finalDay.formatted(
                .dateTime.locale(locale).month(.abbreviated).day()
            )
            return "\(start) – \(end)"
        case .month:
            return periodBounds.currentStart.formatted(
                .dateTime.locale(locale).year().month(.wide)
            )
        case .year:
            return periodBounds.currentStart.formatted(.dateTime.locale(locale).year())
        }
    }

    private var refreshID: IOSStatisticsPeriodRefreshID {
        IOSStatisticsPeriodRefreshID(
            isVisible: isVisible,
            filter: filter,
            persistenceRevision: persistenceRevision,
            calendar: calendar,
            dayBoundaryHour: dayBoundary.hour
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
        guard isVisible, !Task.isCancelled else { return }
        let request = refreshID
        let requestedFilter = filter
        let requestedCalendar = calendar
        let requestedBoundary = dayBoundary

        do {
            if currentSnapshot == nil {
                await Task.yield()
                guard !Task.isCancelled else { return }
            }
            if let searchDebounceDeadline {
                try await Task.sleep(until: searchDebounceDeadline, clock: .continuous)
            }
            guard !Task.isCancelled, request == refreshID else { return }

            let updates = StatisticsProjectionActor.presentationUpdates(
                modelContainer: modelContext.container,
                filter: requestedFilter,
                calendar: requestedCalendar,
                dayBoundary: requestedBoundary
            )
            for try await update in updates {
                guard !Task.isCancelled, request == refreshID else { return }
                switch update {
                case .summary(let summary):
                    if currentSnapshot == nil {
                        partialSummary = IOSStatisticsPartialSummary(request: request, value: summary)
                    }
                case .report(let projection):
                    if currentSnapshot == nil { stagedReportRequest = request }
                    cache.store(projection, calendar: requestedCalendar, dayBoundary: requestedBoundary)
                    partialSummary = nil
                    failedRequest = nil
                }
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, request == refreshID else { return }
            failedRequest = request
            partialSummary = nil
            PersistenceIssueCenter.shared.log(error, operation: .dataLoad)
        }
    }

    private func movePeriod(by value: Int) {
        guard value <= 0 || canMoveToNextPeriod else { return }
        if let customStartDate, let customEndDate {
            let start = calendar.startOfDay(for: min(customStartDate, customEndDate))
            let end = calendar.startOfDay(for: max(customStartDate, customEndDate))
            let dayCount = max(
                1,
                (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
            )
            let offset = value * dayCount
            filter.customStartDate = calendar.date(
                byAdding: .day,
                value: offset,
                to: start
            ) ?? start
            filter.customEndDate = calendar.date(
                byAdding: .day,
                value: offset,
                to: end
            ) ?? end
            filter.anchorDate = filter.customStartDate ?? anchorDate
        } else {
            filter.anchorDate = selectedPeriod.offset(anchorDate, by: value, calendar: calendar)
        }
    }

    private func moveToToday() {
        let today = dayBoundary.day(containing: .now, calendar: calendar)
        if let customStartDate, let customEndDate {
            let start = calendar.startOfDay(for: min(customStartDate, customEndDate))
            let end = calendar.startOfDay(for: max(customStartDate, customEndDate))
            let distance = calendar.dateComponents([.day], from: start, to: end).day ?? 0
            filter.customEndDate = today
            filter.customStartDate = calendar.date(
                byAdding: .day,
                value: -distance,
                to: today
            ) ?? today
        }
        filter.anchorDate = today
    }

    private func selectPeriod(_ period: StatisticsPeriod) {
        if period == .year,
           calendar.component(.year, from: anchorDate) > calendar.component(.year, from: .now) {
            filter.anchorDate = dayBoundary.day(containing: .now, calendar: calendar)
        }
        filter.customStartDate = nil
        filter.customEndDate = nil
        filter.period = period
    }

    private var canMoveToNextPeriod: Bool {
        if let customStartDate, let customEndDate {
            let start = calendar.startOfDay(for: min(customStartDate, customEndDate))
            let end = calendar.startOfDay(for: max(customStartDate, customEndDate))
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

    private func applyAnchorDate() {
        filter.customStartDate = nil
        filter.customEndDate = nil
        filter.anchorDate = StatisticsPeriodBuilder(
            calendar: calendar,
            dayBoundary: dayBoundary
        ).anchorDate(forCalendarSelection: anchorDateDraft, maximumDate: today)
        isAnchorPickerPresented = false
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
        let requestedEnd = calendar.startOfDay(for: max(customStartDraft, customEndDraft))
        let end = min(requestedEnd, today)
        let start = min(
            calendar.startOfDay(for: min(customStartDraft, customEndDraft)),
            end
        )
        filter.customStartDate = start
        filter.customEndDate = end
        filter.anchorDate = start
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
        for configuration: IOSStatisticsExportConfiguration
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
                return try IOSStatisticsCSVTemporaryFileWriter().write(
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

    private func exportFilename(
        for projection: StatisticsPeriodSnapshot,
        content: StatisticsCSVContent
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let prefix = content == .all
            ? "thruflow-statistics"
            : "thruflow-statistics-\(content.rawValue)"
        let start = formatter.string(from: projection.bounds.currentStart)
        let finalDay = calendar.date(
            byAdding: .day,
            value: -1,
            to: projection.bounds.currentEnd
        ) ?? projection.bounds.currentStart
        let end = formatter.string(from: finalDay)
        return "\(prefix)-\(start)-\(end).csv"
    }
}

private struct IOSStatisticsPartialSummary {
    let request: IOSStatisticsPeriodRefreshID
    let value: StatisticsPresentationSummary
}

private struct IOSStatisticsPeriodRefreshID: Hashable {
    let isVisible: Bool
    let filter: StatisticsPeriodFilter
    let persistenceRevision: Int
    let calendar: Calendar
    let dayBoundaryHour: Int
}
