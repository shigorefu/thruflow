import Charts
import SwiftData
import SwiftUI

struct IOSStatisticsView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Direction.updatedAt, order: .reverse) private var directions: [Direction]

    @Binding private var cachedSnapshot: StatisticsPeriodSnapshot?
    let isVisible: Bool
    let onOpenHistoryDate: (Date) -> Void

    @State private var selectedPeriod: StatisticsPeriod = .week
    @State private var selectedDirectionID: UUID?
    @State private var anchorDate = Date.now
    @State private var anchorDateDraft = Date.now
    @State private var customStartDate: Date?
    @State private var customEndDate: Date?
    @State private var customStartDraft = Date.now
    @State private var customEndDraft = Date.now
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var trendMode: StatisticsMode = .flow
    @State private var dotsMode: StatisticsMode = .flow
    @State private var distributionDimension: IOSStatisticsDistributionDimension = .task
    @State private var snapshotCache: [StatisticsPeriodFilter: StatisticsPeriodSnapshot] = [:]
    @State private var snapshotCacheOrder: [StatisticsPeriodFilter] = []
    @State private var loadingFilter: StatisticsPeriodFilter?
    @State private var selectedContributionDay: IOSStatisticsContributionDay?
    @State private var isAnchorPickerPresented = false
    @State private var isCustomRangePresented = false
    @State private var isExportPresented = false
    @State private var exportContent: StatisticsCSVContent = .all
    @State private var exportStartDate = Date.now
    @State private var exportEndDate = Date.now
    @State private var exportDirectionID: UUID?
    @State private var exportQuery = ""
    @State private var exportShareURL: URL?
    @State private var preparedExportConfiguration: IOSStatisticsExportConfiguration?
    @State private var isPreparingExport = false

    init(
        isVisible: Bool = true,
        cachedSnapshot: Binding<StatisticsPeriodSnapshot?>,
        onOpenHistoryDate: @escaping (Date) -> Void = { _ in }
    ) {
        self.isVisible = isVisible
        _cachedSnapshot = cachedSnapshot
        self.onOpenHistoryDate = onOpenHistoryDate
    }

    private var activeDirections: [Direction] {
        directions
            .filter { !$0.isArchived }
            .sorted {
                if $0.sortIndex != $1.sortIndex {
                    return $0.sortIndex < $1.sortIndex
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    private var filter: StatisticsPeriodFilter {
        StatisticsPeriodFilter(
            period: selectedPeriod,
            anchorDate: anchorDate,
            customStartDate: customStartDate,
            customEndDate: customEndDate,
            directionID: selectedDirectionID,
            query: searchText
        )
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

    private var exportFilter: StatisticsPeriodFilter {
        StatisticsPeriodFilter(
            period: .month,
            anchorDate: exportStartDate,
            customStartDate: exportStartDate,
            customEndDate: exportEndDate,
            directionID: exportDirectionID,
            query: exportQuery
        )
    }

    private var exportConfiguration: IOSStatisticsExportConfiguration {
        IOSStatisticsExportConfiguration(content: exportContent, filter: exportFilter)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                periodNavigationCard

                if let currentSnapshot {
                    IOSStatisticsSummaryCard(
                        title: periodTitle,
                        summary: currentSnapshot.summary,
                        previousSummary: currentSnapshot.previousSummary
                    )
                    IOSStatisticsTrendCard(
                        mode: $trendMode,
                        period: presentationPeriod,
                        points: currentSnapshot.trend.filter { $0.date <= today }
                    )
                    IOSStatisticsDistributionCard(
                        dimension: $distributionDimension,
                        items: distributionItems(in: currentSnapshot),
                        totalFocusSeconds: currentSnapshot.summary.totalFocusSeconds
                    )
                    IOSStatisticsDotsCard(
                        mode: $dotsMode,
                        period: presentationPeriod,
                        flowDays: currentSnapshot.flowDays.filter { $0.date <= today },
                        achievementDays: currentSnapshot.achievementDays.filter { $0.date <= today },
                        onSelectDay: { selectedContributionDay = $0 }
                    )
                } else {
                    IOSStatisticsLoadingCards()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .animation(.snappy(duration: 0.32, extraBounce: 0), value: presentationPeriod)
        }
        .background(Color.primary.opacity(0.025).ignoresSafeArea())
        .iosCenteredNavigationTitle(String(localized: "統計"))
        .iosToolbarSearch(
            text: $searchText,
            isPresented: $isSearchPresented,
            prompt: String(localized: "検索")
        )
        .toolbar { statisticsToolbar }
        .overlay(alignment: .topTrailing) {
            if loadingFilter == filter, currentSnapshot != nil {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 20)
                    .padding(.top, 8)
            }
        }
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
            statisticsExportSheet
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
        .task(id: refreshID) {
            await refreshStatisticsWhileVisible()
        }
    }

    private var periodNavigationCard: some View {
        IOSStatisticsCard {
            VStack(spacing: 14) {
                ZStack {
                    Picker(String(localized: "統計期間"), selection: selectedPeriodBinding) {
                        ForEach(StatisticsPeriod.allCases) { period in
                            Text(period.displayName).tag(Optional(period))
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 210)

                    HStack {
                        Spacer()
                        Button {
                            prepareCustomRangeDraft()
                            isCustomRangePresented = true
                        } label: {
                            Image(systemName: "calendar.badge.clock")
                        }
                        .buttonStyle(.bordered)
                        .tint(usesCustomRange ? Color.accentColor : nil)
                        .accessibilityLabel(String(localized: "期間を指定"))
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        movePeriod(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "前へ"))

                    Button {
                        anchorDateDraft = anchorDate
                        isAnchorPickerPresented = true
                    } label: {
                        Text(periodTitle)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "期間を指定"))

                    Button(String(localized: "今日"), action: moveToToday)
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    Button {
                        movePeriod(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                    .disabled(!canMoveToNextPeriod)
                    .accessibilityLabel(String(localized: "次へ"))
                }
            }
        }
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

                Menu {
                    Button {
                        selectedDirectionID = nil
                    } label: {
                        directionMenuLabel(
                            String(localized: "すべて"),
                            isSelected: selectedDirectionID == nil
                        )
                    }
                    if !activeDirections.isEmpty {
                        Divider()
                        ForEach(activeDirections) { direction in
                            Button {
                                selectedDirectionID = direction.id
                            } label: {
                                directionMenuLabel(
                                    "\(direction.symbolName) \(direction.name)",
                                    isSelected: selectedDirectionID == direction.id
                                )
                            }
                        }
                    }
                } label: {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .foregroundStyle(
                            selectedDirectionID == nil ? Color.primary : Color.accentColor
                        )
                }
                .accessibilityLabel(String(localized: "方向フィルター"))
            }
            .fixedSize()
        }
    }

    @ViewBuilder
    private func directionMenuLabel(_ title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    private var statisticsExportSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(String(localized: "書き出す内容"), selection: $exportContent) {
                        ForEach(StatisticsCSVContent.allCases) { content in
                            Text(content.iosDisplayName).tag(content)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    DatePicker(
                        String(localized: "開始日"),
                        selection: $exportStartDate,
                        in: ...today,
                        displayedComponents: .date
                    )
                    DatePicker(
                        String(localized: "終了日"),
                        selection: $exportEndDate,
                        in: ...today,
                        displayedComponents: .date
                    )
                }

                Section {
                    Picker(String(localized: "方向フィルター"), selection: $exportDirectionID) {
                        Text(String(localized: "すべて")).tag(nil as UUID?)
                        ForEach(activeDirections) { direction in
                            Text("\(direction.symbolName) \(direction.name)")
                                .tag(Optional(direction.id))
                        }
                    }

                    TextField(String(localized: "検索"), text: $exportQuery)
                }

                Section {
                    HStack {
                        if isPreparingExport {
                            ProgressView()
                        }
                        Spacer()
                        if let exportShareURL,
                           preparedExportConfiguration == exportConfiguration {
                            ShareLink(item: exportShareURL) {
                                Label(
                                    String(localized: "CSVを書き出す"),
                                    systemImage: "square.and.arrow.up"
                                )
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Label(
                                String(localized: "CSVを書き出す"),
                                systemImage: "square.and.arrow.up"
                            )
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .iosCenteredNavigationTitle(String(localized: "CSVを書き出す"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "閉じる")) {
                        isExportPresented = false
                    }
                }
            }
            .task(id: exportConfiguration) {
                await prepareExportShareURL(for: exportConfiguration)
            }
            .onChange(of: exportStartDate) { _, newValue in
                if exportEndDate < newValue {
                    exportEndDate = newValue
                }
            }
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
        case .direction:
            snapshot.directionDistribution
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
            period: selectedPeriod,
            anchorDate: anchorDate,
            customStartDate: customStartDate,
            customEndDate: customEndDate,
            directionID: selectedDirectionID,
            query: searchText,
            directionCount: directions.count,
            latestDirectionUpdate: directions.map(\.updatedAt).max()
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
            let delay = requestedFilter.query.isEmpty ? 90 : 250
            try await Task.sleep(for: .milliseconds(delay))
        } catch {
            return
        }
        guard !Task.isCancelled, isVisible else { return }

        let loader = StatisticsProjectionActor(modelContainer: modelContext.container)
        do {
            let projection = try await loader.load(
                filter: requestedFilter,
                calendar: calendar,
                dayBoundary: dayBoundary
            )
            guard !Task.isCancelled, requestedFilter == filter, isVisible else { return }
            cache(projection)
        } catch {
            // Keep the last valid projection on transient SwiftData/CloudKit reads.
        }
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

    private func movePeriod(by value: Int) {
        guard value <= 0 || canMoveToNextPeriod else { return }
        withAnimation(.snappy(duration: 0.32, extraBounce: 0)) {
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
                let offset = value * dayCount
                self.customStartDate = calendar.date(
                    byAdding: .day,
                    value: offset,
                    to: start
                ) ?? start
                self.customEndDate = calendar.date(
                    byAdding: .day,
                    value: offset,
                    to: end
                ) ?? end
                anchorDate = self.customStartDate ?? anchorDate
            } else {
                anchorDate = selectedPeriod.offset(anchorDate, by: value, calendar: calendar)
            }
        }
    }

    private func moveToToday() {
        withAnimation(.snappy(duration: 0.32, extraBounce: 0)) {
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
                self.customStartDate = calendar.date(
                    byAdding: .day,
                    value: -distance,
                    to: today
                ) ?? today
            }
            anchorDate = today
        }
    }

    private func selectPeriod(_ period: StatisticsPeriod) {
        withAnimation(.snappy(duration: 0.32, extraBounce: 0)) {
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

    private func applyAnchorDate() {
        withAnimation(.snappy(duration: 0.32, extraBounce: 0)) {
            customStartDate = nil
            customEndDate = nil
            anchorDate = min(
                dayBoundary.day(containing: anchorDateDraft, calendar: calendar),
                today
            )
            isAnchorPickerPresented = false
        }
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
        withAnimation(.snappy(duration: 0.32, extraBounce: 0)) {
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
        exportDirectionID = selectedDirectionID
        exportQuery = searchText
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
                isPreparingExport = false
                return
            }
        }

        guard !Task.isCancelled, configuration == exportConfiguration else { return }
        let exportCalendar = calendar
        let filename = exportFilename(for: projection, content: configuration.content)
        let result = await Task.detached(priority: .utility) {
            let csv = StatisticsCSVExporter().export(
                rows: projection.csvRows,
                content: configuration.content,
                calendar: exportCalendar
            )
            return try? IOSStatisticsCSVTemporaryFileWriter().write(
                csv: csv,
                filename: filename
            )
        }.value

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

private struct IOSStatisticsSummaryCard: View {
    let title: String
    let summary: StatisticsPeriodSummary
    let previousSummary: StatisticsPeriodSummary

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        IOSStatisticsCard(title: String(localized: "概要"), subtitle: title) {
            LazyVGrid(columns: columns, spacing: 10) {
                IOSStatisticsMetric(
                    title: String(localized: "集中時間"),
                    value: IOSStatisticsFormatting.duration(summary.totalFocusSeconds),
                    previousValue: IOSStatisticsFormatting.duration(previousSummary.totalFocusSeconds),
                    systemImage: "timer"
                )
                IOSStatisticsMetric(
                    title: String(localized: "Blocks"),
                    value: BlockUnit.displayText(forFocusedSeconds: summary.totalFocusSeconds),
                    previousValue: BlockUnit.displayText(forFocusedSeconds: previousSummary.totalFocusSeconds),
                    systemImage: "square.grid.2x2"
                )
                IOSStatisticsMetric(
                    title: String(localized: "集中回数"),
                    value: "\(summary.flowCount)",
                    previousValue: "\(previousSummary.flowCount)",
                    systemImage: "water.waves"
                )
                IOSStatisticsMetric(
                    title: String(localized: "完了タスク"),
                    value: "\(summary.completedTaskCount)",
                    previousValue: "\(previousSummary.completedTaskCount)",
                    systemImage: "checkmark.circle"
                )
                IOSStatisticsMetric(
                    title: String(localized: "活動日"),
                    value: String(localized: "\(summary.activeFlowDayCount)日"),
                    previousValue: String(localized: "\(previousSummary.activeFlowDayCount)日"),
                    systemImage: "calendar"
                )
            }
        }
    }
}

private struct IOSStatisticsMetric: View {
    let title: String
    let value: String
    let previousValue: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(String(localized: "前の期間")) · \(previousValue)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.075))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct IOSStatisticsTrendCard: View {
    @Environment(\.locale) private var locale

    @Binding var mode: StatisticsMode
    let period: StatisticsPeriod
    let points: [StatisticsTrendPoint]

    var body: some View {
        IOSStatisticsCard(
            title: String(localized: "傾向"),
            subtitle: mode == .flow ? String(localized: "集中時間") : String(localized: "完了タスク"),
            headerAccessory: {
                IOSStatisticsModePicker(selection: $mode)
            }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Label(String(localized: "選択した期間"), systemImage: "minus")
                        .foregroundStyle(Color.accentColor)
                    Label(String(localized: "前の期間"), systemImage: "ellipsis")
                        .foregroundStyle(.secondary)
                }
                .font(.caption2)

                Chart {
                    ForEach(points) { point in
                        LineMark(
                            x: .value(String(localized: "日"), point.index),
                            y: .value(String(localized: "前の期間"), previousValue(point)),
                            series: .value(String(localized: "期間"), String(localized: "前の期間"))
                        )
                        .foregroundStyle(Color.secondary.opacity(0.5))
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
                        .symbolSize(22)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: axisIndexes) { value in
                        AxisGridLine()
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
                                Text(mode == .flow ? String(localized: "\(raw)分") : "\(raw)")
                            }
                        }
                    }
                }
                .frame(height: 210)
                .overlay {
                    if points.allSatisfy({ currentValue($0) == 0 && previousValue($0) == 0 }) {
                        IOSStatisticsEmptyState()
                    }
                }
            }
            .id(mode)
            .transition(.opacity.combined(with: .scale(scale: 0.99)))
            .animation(.easeInOut(duration: 0.2), value: mode)
        }
    }

    private var axisIndexes: [Int] {
        guard !points.isEmpty else { return [] }
        let stride = max(1, points.count / 4)
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

private struct IOSStatisticsDistributionCard: View {
    @Binding var dimension: IOSStatisticsDistributionDimension
    let items: [StatisticsDistributionItem]
    let totalFocusSeconds: Int

    @State private var selectedItemID: String?

    private var selectedItem: StatisticsDistributionItem? {
        guard let selectedItemID else { return nil }
        return items.first { $0.id == selectedItemID }
    }

    private var displayedItems: [StatisticsDistributionItem] {
        selectedItem.map { [$0] } ?? items
    }

    var body: some View {
        IOSStatisticsCard(
            title: String(localized: "集中時間の内訳"),
            headerAccessory: {
                Picker(String(localized: "内訳"), selection: $dimension) {
                    ForEach(IOSStatisticsDistributionDimension.allCases) { dimension in
                        Text(dimension.displayName).tag(dimension)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 154)
            }
        ) {
            if items.isEmpty {
                IOSStatisticsEmptyState()
                    .frame(maxWidth: .infinity, minHeight: 190)
            } else {
                VStack(spacing: 18) {
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
                                            selectItem(at: value.location, in: geometry.size)
                                        }
                                )
                        }
                    }
                    .frame(width: 190, height: 190)
                    .overlay {
                        VStack(spacing: 3) {
                            Text(IOSStatisticsFormatting.duration(
                                selectedItem?.focusSeconds ?? totalFocusSeconds
                            ))
                            .font(.headline.monospacedDigit())
                            Text(selectedItem?.name ?? String(localized: "集中時間"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            if selectedItem != nil {
                                Button {
                                    selectedItemID = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(String(localized: "すべて"))
                            }
                        }
                        .frame(maxWidth: 98)
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
                                Text(IOSStatisticsFormatting.duration(item.focusSeconds))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .font(.callout)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .animation(.easeInOut(duration: 0.18), value: selectedItemID)
            }
        }
        .onChange(of: dimension) { _, _ in
            selectedItemID = nil
        }
        .onChange(of: items.map(\.id)) { _, identifiers in
            if let selectedItemID, !identifiers.contains(selectedItemID) {
                self.selectedItemID = nil
            }
        }
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
        let value = normalizedRadians / (2 * .pi) * total

        var upperBound = 0.0
        for item in items {
            upperBound += Double(max(0, item.focusSeconds))
            if value <= upperBound {
                selectedItemID = item.id
                return
            }
        }
        selectedItemID = items.last?.id
    }
}

private struct IOSStatisticsDotsCard: View {
    @Environment(\.calendar) private var calendar

    @Binding var mode: StatisticsMode
    let period: StatisticsPeriod
    let flowDays: [StatisticsDay]
    let achievementDays: [AchievementDay]
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
                completedTaskCount: achievement?.completedCount ?? 0
            )
        }
    }

    private var maxValue: Int {
        max(1, days.map(\.value).max() ?? 1)
    }

    private var paddedDays: [IOSStatisticsContributionDay?] {
        guard let first = days.first else { return [] }
        let weekday = calendar.component(.weekday, from: first.date)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + days.map(Optional.some)
    }

    var body: some View {
        IOSStatisticsCard(
            title: String(localized: "Dots"),
            subtitle: mode == .flow ? String(localized: "集中時間") : String(localized: "完了タスク"),
            headerAccessory: {
                IOSStatisticsModePicker(selection: $mode)
            }
        ) {
            if days.isEmpty {
                IOSStatisticsEmptyState()
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    switch period {
                    case .week:
                        weekGrid
                    case .month:
                        monthGrid
                    case .year:
                        IOSStatisticsYearGrid(
                            paddedDays: paddedDays,
                            maxValue: maxValue
                        )
                    }

                    HStack(spacing: 5) {
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
        .id(mode)
        .transition(.opacity.combined(with: .scale(scale: 0.99)))
        .animation(.easeInOut(duration: 0.2), value: mode)
    }

    private var weekGrid: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    IOSStatisticsContributionCell(
                        day: day,
                        maxValue: maxValue,
                        onSelectDay: onSelectDay
                    )
                    .aspectRatio(1, contentMode: .fit)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(CalendarWeekdaySymbols.orderedAbbreviated(calendar: calendar), id: \.self) { weekday in
                Text(weekday)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(paddedDays.enumerated()), id: \.offset) { _, day in
                IOSStatisticsContributionCell(
                    day: day,
                    maxValue: maxValue,
                    onSelectDay: onSelectDay
                )
                .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}

private struct IOSStatisticsContributionCell: View {
    let day: IOSStatisticsContributionDay?
    let maxValue: Int
    let onSelectDay: (IOSStatisticsContributionDay) -> Void

    var body: some View {
        Button {
            if let day {
                onSelectDay(day)
            }
        } label: {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(IOSStatisticsDotColor.fill(for: day, maxValue: maxValue))
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.055))
                }
        }
        .buttonStyle(.plain)
        .disabled(day == nil)
        .accessibilityLabel(day?.accessibilityLabel ?? "")
        .accessibilityHint(String(localized: "選択"))
    }
}

private struct IOSStatisticsYearGrid: View {
    let paddedDays: [IOSStatisticsContributionDay?]
    let maxValue: Int

    var body: some View {
        GeometryReader { geometry in
            let layout = layout(for: geometry.size)
            Canvas { context, _ in
                for (index, day) in paddedDays.enumerated() {
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
        }
        .frame(height: 58)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Dots"))
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

private struct IOSStatisticsDaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    let day: IOSStatisticsContributionDay
    let onOpenHistory: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(day.date.formatted(
                    .dateTime.locale(locale).year().month(.wide).day().weekday(.wide)
                ))
                .font(.headline)

                HStack(spacing: 10) {
                    dayMetric(String(localized: "集中時間"), IOSStatisticsFormatting.duration(day.focusedSeconds))
                    dayMetric(String(localized: "集中回数"), "\(day.flowCount)")
                    dayMetric(String(localized: "完了タスク"), "\(day.completedTaskCount)")
                }

                Button {
                    dismiss()
                    onOpenHistory()
                } label: {
                    Label(String(localized: "履歴"), systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
            .iosCenteredNavigationTitle(String(localized: "Dots"))
        }
    }

    private func dayMetric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.075))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct IOSStatisticsModePicker: View {
    @Binding var selection: StatisticsMode

    var body: some View {
        Picker(String(localized: "統計表示"), selection: $selection) {
            Text(StatisticsMode.flow.displayName).tag(StatisticsMode.flow)
            Text(StatisticsMode.achievement.displayName).tag(StatisticsMode.achievement)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 118)
    }
}

private struct IOSStatisticsAnchorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var date: Date
    let maximumDate: Date
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            DatePicker(
                String(localized: "期間を指定"),
                selection: $date,
                in: ...maximumDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .iosCenteredNavigationTitle(String(localized: "期間を指定"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "キャンセル")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "完了"), action: onApply)
                }
            }
        }
    }
}

private struct IOSStatisticsCustomRangeSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var startDate: Date
    @Binding var endDate: Date
    let maximumDate: Date
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            Form {
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
            .iosCenteredNavigationTitle(String(localized: "期間を指定"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "キャンセル")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "完了"), action: onApply)
                }
            }
            .onChange(of: startDate) { _, newValue in
                if endDate < newValue {
                    endDate = newValue
                }
            }
        }
    }
}

private struct IOSStatisticsLoadingCards: View {
    var body: some View {
        ForEach(0..<4, id: \.self) { index in
            IOSStatisticsCard(
                title: index == 0
                    ? String(localized: "概要")
                    : index == 1
                        ? String(localized: "傾向")
                        : index == 2
                            ? String(localized: "集中時間の内訳")
                            : String(localized: "Dots")
            ) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.075))
                        .frame(height: index == 0 ? 210 : 230)
                    if index == 0 {
                        ProgressView()
                    }
                }
                .accessibilityHidden(true)
            }
        }
    }
}

private struct IOSStatisticsCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let headerAccessory: AnyView?
    let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        headerAccessory = nil
        self.content = content()
    }

    init<HeaderAccessory: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.headerAccessory = AnyView(headerAccessory())
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if title != nil || headerAccessory != nil {
                HStack(spacing: 8) {
                    if let title {
                        Text(title)
                            .font(.headline)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if let headerAccessory {
                        headerAccessory
                    }
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        }
    }
}

private struct IOSStatisticsEmptyState: View {
    var body: some View {
        ContentUnavailableView(
            String(localized: "この期間のデータはありません"),
            systemImage: "chart.xyaxis.line",
            description: Text(String(localized: "期間やフィルターを変更してください"))
        )
        .controlSize(.small)
    }
}

private enum IOSStatisticsDistributionDimension: String, CaseIterable, Identifiable {
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

private struct IOSStatisticsContributionDay: Identifiable {
    let date: Date
    let value: Int
    let colorHex: String?
    let focusedSeconds: Int
    let flowCount: Int
    let completedTaskCount: Int

    var id: Date { date }

    var accessibilityLabel: String {
        let formattedDate = date.formatted(date: .abbreviated, time: .omitted)
        let duration = IOSStatisticsFormatting.duration(focusedSeconds)
        return String(
            localized: "\(formattedDate)：集中時間\(duration)、集中\(flowCount)回、完了タスク\(completedTaskCount)件"
        )
    }
}

private enum IOSStatisticsFormatting {
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
    var iosDisplayName: String {
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

private struct IOSStatisticsExportConfiguration: Hashable, Sendable {
    let content: StatisticsCSVContent
    let filter: StatisticsPeriodFilter
}

private struct IOSStatisticsCSVTemporaryFileWriter {
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

private struct IOSStatisticsPeriodRefreshID: Hashable {
    let isVisible: Bool
    let period: StatisticsPeriod
    let anchorDate: Date
    let customStartDate: Date?
    let customEndDate: Date?
    let directionID: UUID?
    let query: String
    let directionCount: Int
    let latestDirectionUpdate: Date?
}
