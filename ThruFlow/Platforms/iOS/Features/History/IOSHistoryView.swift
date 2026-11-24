import SwiftData
import SwiftUI
import UIKit

struct IOSHistoryView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar

    private let isVisible: Bool
    @Binding private var selectedDate: Date
    @State private var observesRecords = false
    @State private var recordsCache: [IOSHistoryRecords] = []
    @State private var failedRequest: IOSHistoryRequest?
    @State private var indicatorWindow: IOSHistoryIndicatorWindow?
    @State private var indicators: IOSHistoryIndicators?
    @State private var revealRevision = 0
    @State private var range = HistoryCalendarRange.day
    @State private var selectedMode = DayHistoryMode.calendar
    @State private var visibleKinds = Set(HistoryCalendarItemKind.allCases)
    @State private var visibleTaskTypes = Set(AreaType.allCases)
    @State private var visibleAreaTypes = Set(AreaType.allCases)
    @State private var selectedItem: HistoryCalendarItem?
    @State private var selectedSeries: HistoryCalendarSeriesBlock?
    @State private var isAddingTaskRecord = false
    @State private var historyRecordStart = Date.now
    @State private var searchText = ""
    @State private var isSearchPresented = false

    init(isVisible: Bool = true, selectedDate: Binding<Date>) {
        self.isVisible = isVisible
        _selectedDate = selectedDate
    }

    private var searchBuilder: DatabaseSearchBuilder {
        DatabaseSearchBuilder(calendar: calendar)
    }

    private var isSearching: Bool {
        DatabaseSearchQuery(text: searchText).isActive
    }

    private var selectedInterval: DateInterval {
        range.interval(containing: selectedDate, calendar: calendar, dayBoundary: dayBoundary)
    }

    private var request: IOSHistoryRequest {
        IOSHistoryRequest(interval: isSearching ? nil : selectedInterval, calendar: calendar)
    }

    var body: some View {
        let records = recordsCache.first { $0.request == request }
        let calendarItems = records.flatMap { records in
            !isSearching && (selectedMode == .calendar || range == .month)
                ? visibleCalendarItems(in: records)
                : nil
        }
        VStack(spacing: 0) {
            if !isSearching {
                calendarToolbar(items: calendarItems ?? [])
                Divider()
            }
            if let records {
                Group {
                    if isSearching {
                        globalSearchContent(records: records)
                    } else {
                        historyContent(records: records, items: calendarItems ?? [])
                            .productContentFade(on: selectedMode.rawValue + ":" + range.rawValue)
                            .iosPeriodSwipeNavigation(
                                pageID: selectedInterval.start,
                                isEnabled: allowsContentPeriodSwipe
                            ) { offset in
                                navigatePeriod(by: offset)
                            }
                    }
                }
                .transition(reduceMotion ? .identity : .asymmetric(insertion: .opacity, removal: .identity))
            } else if failedRequest == request {
                ContentUnavailableView(
                    String(localized: "データを読み込めませんでした。"),
                    systemImage: "exclamationmark.triangle"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                FeatureLoadingIndicator()
                    .transition(.identity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: revealRevision)
        .background {
            if isVisible, observesRecords {
                IOSHistoryRecordsQuery(request: request) { result in
                    switch result {
                    case .success(let records):
                        if !recordsCache.contains(where: { $0.request == records.request }) {
                            revealRevision &+= 1
                        }
                        recordsCache.removeAll { $0.request == records.request }
                        recordsCache.insert(records, at: 0)
                        if recordsCache.count > 3 { recordsCache.removeLast() }
                        failedRequest = nil
                    case .failure(let error):
                        failedRequest = request
                        PersistenceIssueCenter.shared.log(error, operation: .dataLoad)
                    }
                }
                .id(request)
                if !isSearching, let indicatorRequest {
                    IOSHistoryIndicatorQuery(request: indicatorRequest) { result in
                        indicators = IOSHistoryIndicators(request: indicatorRequest, sessions: result)
                    }
                    .id(indicatorRequest)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea(edges: .bottom)
        }
        .iosCenteredNavigationTitle(String(localized: "履歴"))
        .iosToolbarSearch(
            text: $searchText,
            isPresented: $isSearchPresented,
            prompt: String(localized: "検索")
        )
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                modeMenu
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleHistoryRecord()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "記録を追加"))
            }
        }
        .sheet(item: $selectedItem) { item in
            IOSHistoryItemDetail(item: item)
                .presentationDetents(item.kind == .flow ? [.large] : [.medium])
        }
        .sheet(item: $selectedSeries) { block in
            IOSHistorySeriesTimelineSheet(block: block)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $isAddingTaskRecord) {
            HistoryTaskRecordForm(
                startedAt: historyRecordStart,
                context: HistoryRecordContext(selectedMode),
                onDismiss: { isAddingTaskRecord = false }
            )
            .id("\(historyRecordStart.timeIntervalSinceReferenceDate)-\(selectedMode.rawValue)")
        }
        .task(id: isVisible) {
            guard isVisible else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            observesRecords = true
        }
        .onChange(of: isSearching) { _, searching in
            if !searching { recordsCache.removeAll { $0.request.interval == nil } }
        }
    }

    private func historySnapshot(in records: IOSHistoryRecords) -> DayHistorySnapshot {
        DayHistoryBuilder(calendar: calendar, dayBoundary: dayBoundary).build(
            interval: selectedInterval,
            sessions: records.sessions,
            todos: records.todos
        )
    }

    private var indicatorRequest: IOSHistoryRequest? {
        guard let indicatorWindow, indicatorWindow.range == range,
              indicatorWindow.calendar == calendar,
              indicatorWindow.interval.start <= calendar.startOfDay(for: selectedDate),
              indicatorWindow.interval.end > calendar.startOfDay(for: selectedDate) else { return nil }
        return IOSHistoryRequest(interval: indicatorWindow.interval, calendar: calendar)
    }

    private var indicatorSessions: [FlowSession] {
        indicators?.request == indicatorRequest ? indicators?.sessions ?? [] : []
    }

    private func updateIndicatorWindow(_ interval: DateInterval) {
        indicatorWindow = IOSHistoryIndicatorWindow(interval: interval, range: range, calendar: calendar)
    }

    @ViewBuilder
    private func historyContent(records: IOSHistoryRecords, items: [HistoryCalendarItem]) -> some View {
        let date = selectedDate
        switch selectedMode {
        case .calendar:
            switch range {
            case .day:
                IOSHistoryChronologicalTimeline(
                    items: items,
                    gapInterval: HistoryCalendarRange.day.interval(
                        containing: date,
                        calendar: calendar,
                        dayBoundary: dayBoundary
                    ),
                    onSelect: { selectedItem = $0 }
                )
            case .week:
                IOSHistorySeriesWeekTimeline(
                    interval: selectedInterval,
                    items: items,
                    onSelectSeries: { selectedSeries = $0 },
                    onAddRecord: presentHistoryRecord
                )
            case .month:
                IOSHistoryMonthView(
                    selectedDate: $selectedDate,
                    interval: selectedInterval,
                    items: items,
                    onNavigatePeriod: navigatePeriod,
                    onSelect: { selectedItem = $0 }
                )
            }
        case .tasks:
            IOSHistoryTaskSummaryList(
                snapshot: historySnapshot(in: records),
                searchText: searchText,
                visibleTypes: visibleTaskTypes
            )
        case .areas:
            IOSHistoryAreaSummaryList(
                snapshot: historySnapshot(in: records),
                searchText: searchText,
                visibleTypes: visibleAreaTypes
            )
        }
    }

    private func visibleCalendarItems(in records: IOSHistoryRecords) -> [HistoryCalendarItem] {
        HistoryCalendarBuilder(calendar: calendar).build(
            interval: selectedInterval,
            sessions: records.sessions,
            breaks: records.breaks
        ).items
            .filter { visibleKinds.contains($0.kind) }
            .filter(matchesSelectedType)
            .filter(matchesSearch)
    }

    @ViewBuilder
    private func globalSearchContent(records: IOSHistoryRecords) -> some View {
        switch selectedMode {
        case .calendar:
            IOSHistoryGlobalSearchList(
                items: searchBuilder.historyCalendarItems(query: searchText, sessions: records.sessions, breaks: records.breaks)
                    .filter { visibleKinds.contains($0.kind) },
                searchText: searchText,
                selection: $selectedItem
            )
        case .tasks:
            IOSHistoryTaskSummaryList(
                snapshot: searchBuilder.historySnapshot(query: searchText, sessions: records.sessions, todos: records.todos),
                searchText: "",
                visibleTypes: visibleTaskTypes
            )
        case .areas:
            IOSHistoryAreaSummaryList(
                snapshot: searchBuilder.historySnapshot(query: searchText, sessions: records.sessions, todos: records.todos),
                searchText: "",
                visibleTypes: visibleAreaTypes
            )
        }
    }

    private func matchesSelectedType(_ item: HistoryCalendarItem) -> Bool {
        guard item.kind == .flow else { return selectedMode == .calendar }
        switch selectedMode {
        case .calendar:
            return true
        case .tasks:
            return visibleTaskTypes.contains(item.areaType)
        case .areas:
            return visibleAreaTypes.contains(item.areaType)
        }
    }

    private func matchesSearch(_ item: HistoryCalendarItem) -> Bool {
        DatabaseSearchQuery(text: searchText).matchesHistory(item)
    }

    private var modeMenu: some View {
        Menu {
            ForEach(DayHistoryMode.allCases) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    if selectedMode == mode {
                        Label(mode.displayName, systemImage: "checkmark").labelStyle(.titleAndIcon)
                    } else {
                        Text(mode.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedMode.displayName)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
        }
        .accessibilityLabel(String(localized: "履歴表示"))
    }

    private func calendarToolbar(items: [HistoryCalendarItem]) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                contextualFilterMenu

                Spacer(minLength: 0)

                Picker(String(localized: "期間"), selection: $range) {
                    ForEach(HistoryCalendarRange.allCases) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 190)

                Spacer(minLength: 0)

                Button(String(localized: "今日")) {
                    selectedDate = dayBoundary.day(containing: .now, calendar: calendar)
                }
                .buttonStyle(.borderedProminent)
            }

            switch range {
            case .day:
                IOSHistoryDayStrip(
                    selectedDate: $selectedDate,
                    sessions: indicatorSessions,
                    visibleAreaTypes: selectedIndicatorTypes,
                    onWindowChange: updateIndicatorWindow
                )
            case .week:
                IOSHistoryWeekStrip(
                    selectedDate: $selectedDate,
                    sessions: indicatorSessions,
                    visibleAreaTypes: selectedIndicatorTypes,
                    onWindowChange: updateIndicatorWindow
                )
            case .month:
                if selectedMode != .calendar {
                    IOSHistoryMonthGrid(
                        interval: selectedInterval,
                        items: items,
                        selectedDate: $selectedDate
                    )
                    .iosHorizontalPeriodSwipe { offset in
                        navigatePeriod(by: offset)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var contextualFilterMenu: some View {
        switch selectedMode {
        case .calendar:
            historyVisibilityMenu
        case .tasks:
            IOSHistoryAggregateFilterMenu(
                visibleTypes: $visibleTaskTypes,
                neutralLabel: String(localized: "タスク")
            )
        case .areas:
            IOSHistoryAggregateFilterMenu(
                visibleTypes: $visibleAreaTypes,
                neutralLabel: String(localized: "通常")
            )
        }
    }

    private var selectedIndicatorTypes: Set<AreaType>? {
        switch selectedMode {
        case .calendar:
            nil
        case .tasks:
            visibleTaskTypes
        case .areas:
            visibleAreaTypes
        }
    }

    private var historyVisibilityMenu: some View {
        Menu {
            Toggle(String(localized: "集中記録"), isOn: visibilityBinding(for: .flow))
            Toggle(String(localized: "休憩"), isOn: visibilityBinding(for: .rest))
        } label: {
            Image(
                systemName: visibleKinds.count == HistoryCalendarItemKind.allCases.count
                    ? "line.3.horizontal.decrease"
                    : "line.3.horizontal.decrease.circle.fill"
            )
            .frame(width: 30, height: 30)
        }
        .accessibilityLabel(String(localized: "フィルター"))
    }

    private func visibilityBinding(for kind: HistoryCalendarItemKind) -> Binding<Bool> {
        Binding(
            get: { visibleKinds.contains(kind) },
            set: { isVisible in
                if isVisible {
                    visibleKinds.insert(kind)
                } else {
                    visibleKinds.remove(kind)
                }
            }
        )
    }

    private var defaultTaskRecordStart: Date {
        if calendar.isDateInToday(selectedDate) {
            return Date.now.addingTimeInterval(-25 * 60)
        }
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate
    }

    private func presentHistoryRecord(at startedAt: Date) {
        historyRecordStart = startedAt
        isAddingTaskRecord = true
    }

    private func toggleHistoryRecord() {
        if isAddingTaskRecord {
            isAddingTaskRecord = false
        } else {
            presentHistoryRecord(at: defaultTaskRecordStart)
        }
    }

    private var allowsContentPeriodSwipe: Bool {
        switch range {
        case .day:
            true
        case .week:
            selectedMode != .calendar
        case .month:
            selectedMode != .calendar
        }
    }

    private func navigatePeriod(by offset: Int) {
        let component: Calendar.Component
        switch range {
        case .day:
            component = .day
        case .week:
            component = .weekOfYear
        case .month:
            component = .month
        }
        guard let date = calendar.date(
            byAdding: component,
            value: offset,
            to: selectedDate
        ) else {
            return
        }
        selectedDate = calendar.startOfDay(for: date)
    }

}
