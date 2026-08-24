import SwiftData
import SwiftUI
import UIKit

struct IOSHistoryView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar

    @Query(sort: \FlowSession.startedAt) private var sessions: [FlowSession]
    @Query(sort: \FlowBreak.startedAt) private var flowBreaks: [FlowBreak]
    @Query(sort: \Todo.updatedAt, order: .reverse) private var todos: [Todo]

    @Binding private var selectedDate: Date
    @State private var range = HistoryCalendarRange.day
    @State private var selectedMode = DayHistoryMode.calendar
    @State private var visibleKinds = Set(HistoryCalendarItemKind.allCases)
    @State private var visibleTaskTypes = Set(DirectionType.allCases)
    @State private var visibleDirectionTypes = Set(DirectionType.allCases)
    @State private var selectedItem: HistoryCalendarItem?
    @State private var selectedSeries: HistoryCalendarSeriesBlock?
    @State private var isAddingTaskRecord = false
    @State private var historyRecordStart = Date.now
    @State private var searchText = ""
    @State private var isSearchPresented = false

    init(selectedDate: Binding<Date>) {
        _selectedDate = selectedDate
    }

    private var searchBuilder: DatabaseSearchBuilder {
        DatabaseSearchBuilder(calendar: calendar)
    }

    private var isSearching: Bool {
        DatabaseSearchQuery(text: searchText).isActive
    }

    private var globalCalendarSearchItems: [HistoryCalendarItem] {
        searchBuilder.historyCalendarItems(
            query: searchText,
            sessions: sessions,
            breaks: flowBreaks
        )
        .filter { visibleKinds.contains($0.kind) }
    }

    private var globalHistorySnapshot: DayHistorySnapshot {
        searchBuilder.historySnapshot(
            query: searchText,
            sessions: sessions,
            todos: todos
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if isSearching {
                globalSearchContent
            } else {
                calendarToolbar
                Divider()
                historyContent
                    .iosPeriodSwipeNavigation(
                        pageID: selectedPeriodPageID,
                        isEnabled: allowsContentPeriodSwipe
                    ) { offset in
                        navigatePeriod(by: offset)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
    }

    private var calendarSnapshot: HistoryCalendarSnapshot {
        calendarSnapshot(for: selectedDate)
    }

    private func calendarSnapshot(for date: Date) -> HistoryCalendarSnapshot {
        let interval = range.interval(
            containing: date,
            calendar: calendar,
            dayBoundary: dayBoundary
        )
        return HistoryCalendarBuilder(calendar: calendar).build(
            interval: interval,
            sessions: sessions,
            breaks: flowBreaks
        )
    }

    private var historySnapshot: DayHistorySnapshot {
        historySnapshot(for: selectedDate)
    }

    private func historySnapshot(for date: Date) -> DayHistorySnapshot {
        DayHistoryBuilder(calendar: calendar, dayBoundary: dayBoundary).build(
            interval: range.interval(
                containing: date,
                calendar: calendar,
                dayBoundary: dayBoundary
            ),
            sessions: sessions,
            todos: todos
        )
    }

    private var visibleCalendarItems: [HistoryCalendarItem] {
        visibleCalendarItems(for: selectedDate)
    }

    @ViewBuilder
    private var historyContent: some View {
        historyPageContent(for: selectedDate)
    }

    @ViewBuilder
    private func historyPageContent(for date: Date) -> some View {
        switch selectedMode {
        case .calendar:
            let snapshot = calendarSnapshot(for: date)
            switch range {
            case .day:
                IOSHistoryChronologicalTimeline(
                    items: visibleCalendarItems(for: date),
                    gapInterval: HistoryCalendarRange.day.interval(
                        containing: date,
                        calendar: calendar,
                        dayBoundary: dayBoundary
                    ),
                    onSelect: { selectedItem = $0 }
                )
            case .week:
                IOSHistorySeriesWeekTimeline(
                    interval: snapshot.interval,
                    items: visibleCalendarItems(for: date),
                    onSelectSeries: { selectedSeries = $0 },
                    onAddRecord: presentHistoryRecord
                )
            case .month:
                let dayItems = calendarItems(
                    on: date,
                    from: visibleCalendarItems(for: date)
                )
                ScrollView {
                    LazyVStack(spacing: 0) {
                        IOSHistoryMonthGrid(
                            interval: snapshot.interval,
                            items: visibleCalendarItems(for: date),
                            selectedDate: $selectedDate
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .iosHorizontalPeriodSwipe { offset in
                            navigatePeriod(by: offset)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 3) {
                            Text(String(localized: "この日の記録"))
                                .font(.headline)
                            Text(date, format: .dateTime.month().day().weekday(.wide))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        IOSHistoryChronologicalTimeline(
                            items: dayItems,
                            gapInterval: HistoryCalendarRange.day.interval(
                                containing: date,
                                calendar: calendar,
                                dayBoundary: dayBoundary
                            ),
                            isEmbedded: true,
                            onSelect: { selectedItem = $0 }
                        )
                    }
                }
            }
        case .tasks:
            IOSHistoryTaskSummaryList(
                snapshot: historySnapshot(for: date),
                searchText: searchText,
                visibleTypes: visibleTaskTypes
            )
        case .directions:
            IOSHistoryDirectionSummaryList(
                snapshot: historySnapshot(for: date),
                searchText: searchText,
                visibleTypes: visibleDirectionTypes
            )
        }
    }

    private func visibleCalendarItems(for date: Date) -> [HistoryCalendarItem] {
        calendarSnapshot(for: date).items
            .filter { visibleKinds.contains($0.kind) }
            .filter(matchesSelectedType)
            .filter(matchesSearch)
    }

    private func calendarItems(
        on date: Date,
        from items: [HistoryCalendarItem]
    ) -> [HistoryCalendarItem] {
        let interval = HistoryCalendarRange.day.interval(
            containing: date,
            calendar: calendar,
            dayBoundary: dayBoundary
        )
        return items.filter {
            $0.startedAt < interval.end && $0.endedAt > interval.start
        }
    }

    @ViewBuilder
    private var globalSearchContent: some View {
        switch selectedMode {
        case .calendar:
            IOSHistoryGlobalSearchList(
                items: globalCalendarSearchItems,
                searchText: searchText,
                selection: $selectedItem
            )
        case .tasks:
            IOSHistoryTaskSummaryList(
                snapshot: globalHistorySnapshot,
                searchText: "",
                visibleTypes: visibleTaskTypes
            )
        case .directions:
            IOSHistoryDirectionSummaryList(
                snapshot: globalHistorySnapshot,
                searchText: "",
                visibleTypes: visibleDirectionTypes
            )
        }
    }

    private func matchesSelectedType(_ item: HistoryCalendarItem) -> Bool {
        guard item.kind == .flow else { return selectedMode == .calendar }
        switch selectedMode {
        case .calendar:
            return true
        case .tasks:
            return visibleTaskTypes.contains(item.directionType)
        case .directions:
            return visibleDirectionTypes.contains(item.directionType)
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
                        Label(mode.displayName, systemImage: "checkmark")
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

    private var calendarToolbar: some View {
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
                    sessions: sessions,
                    visibleDirectionTypes: selectedIndicatorTypes
                )
            case .week:
                IOSHistoryWeekStrip(
                    selectedDate: $selectedDate,
                    sessions: sessions,
                    visibleDirectionTypes: selectedIndicatorTypes
                )
            case .month:
                if selectedMode != .calendar {
                    IOSHistoryMonthGrid(
                        interval: calendarSnapshot.interval,
                        items: visibleCalendarItems,
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
        .background(.bar)
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
        case .directions:
            IOSHistoryAggregateFilterMenu(
                visibleTypes: $visibleDirectionTypes,
                neutralLabel: String(localized: "通常")
            )
        }
    }

    private var selectedIndicatorTypes: Set<DirectionType>? {
        switch selectedMode {
        case .calendar:
            nil
        case .tasks:
            visibleTaskTypes
        case .directions:
            visibleDirectionTypes
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

    private var selectedPeriodPageID: Date {
        range.interval(
            containing: selectedDate,
            calendar: calendar,
            dayBoundary: dayBoundary
        ).start
    }
}

private struct IOSHistoryDayStrip: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    @Binding var selectedDate: Date
    let sessions: [FlowSession]
    let visibleDirectionTypes: Set<DirectionType>?

    var body: some View {
        let activityIndex = IOSHistoryActivityColorIndex(
            sessions: sessions,
            visibleDirectionTypes: visibleDirectionTypes,
            calendar: calendar
        )

        IOSScrollablePeriodStrip(
            selectedDate: $selectedDate,
            unit: .day,
            visibleItemCount: 7,
            spacing: 5,
            height: 55
        ) { date, isSelected in
            Button {
                selectedDate = calendar.startOfDay(for: date)
            } label: {
                VStack(spacing: 4) {
                    Text(date.formatted(.dateTime.locale(locale).weekday(.narrow)))
                        .font(.caption2.weight(.semibold))
                    Text(verbatim: String(calendar.component(.day, from: date)))
                        .font(.body.monospacedDigit().weight(.semibold))
                    IOSHistoryActivityDots(
                        colors: activityIndex.byDay[calendar.startOfDay(for: date)] ?? []
                    )
                }
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 55)
                .background(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

}

private struct IOSHistoryWeekStrip: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    @Binding var selectedDate: Date
    let sessions: [FlowSession]
    let visibleDirectionTypes: Set<DirectionType>?

    var body: some View {
        let activityIndex = IOSHistoryActivityColorIndex(
            sessions: sessions,
            visibleDirectionTypes: visibleDirectionTypes,
            calendar: calendar
        )

        IOSScrollablePeriodStrip(
            selectedDate: $selectedDate,
            unit: .week,
            visibleItemCount: 3,
            spacing: 6,
            height: 58
        ) { anchor, isSelected in
            let interval = HistoryCalendarRange.week.interval(
                containing: anchor,
                calendar: calendar,
                dayBoundary: dayBoundary
            )

            Button {
                selectedDate = calendar.startOfDay(for: anchor)
            } label: {
                VStack(spacing: 3) {
                    Text(interval.start.formatted(.dateTime.locale(locale).month(.abbreviated)))
                        .font(.caption.weight(.semibold))
                    Text(dayRangeText(interval))
                        .font(.body.monospacedDigit().weight(.semibold))
                    IOSHistoryActivityDots(
                        colors: activityIndex.byWeek[weekStart(for: anchor)] ?? []
                    )
                }
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    private func dayRangeText(_ interval: DateInterval) -> String {
        let end = interval.end.addingTimeInterval(-1)
        return "\(calendar.component(.day, from: interval.start))–\(calendar.component(.day, from: end))"
    }

    private func weekStart(for date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }
}

@MainActor
private struct IOSHistoryActivityColorIndex {
    private(set) var byDay: [Date: [String]] = [:]
    private(set) var byWeek: [Date: [String]] = [:]
    private var seenByDay: [Date: Set<String>] = [:]
    private var seenByWeek: [Date: Set<String>] = [:]

    init(
        sessions: [FlowSession],
        visibleDirectionTypes: Set<DirectionType>?,
        calendar: Calendar
    ) {
        for session in sessions
        where session.status != .interrupted && session.resolvedActualFocusDurationSeconds > 0 {
            if session.resolvedSegments.isEmpty {
                let directionType = session.direction?.type ?? .neutral
                guard visibleDirectionTypes?.contains(directionType) != false else { continue }
                append(
                    colorHex: session.direction?.colorHex ?? "#8E8E93",
                    at: session.startedAt,
                    calendar: calendar
                )
                continue
            }

            for segment in session.resolvedSegments where segment.resolvedFocusSeconds > 0 {
                let directionType = segment.direction?.type ?? session.direction?.type ?? .neutral
                guard visibleDirectionTypes?.contains(directionType) != false else { continue }
                append(
                    colorHex: segment.direction?.colorHex ?? "#8E8E93",
                    at: segment.startedAt,
                    calendar: calendar
                )
            }
        }
    }

    private mutating func append(
        colorHex: String,
        at date: Date,
        calendar: Calendar
    ) {
        let normalizedColor = colorHex.lowercased()
        let day = calendar.startOfDay(for: date)
        let week = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? day

        if seenByDay[day, default: []].insert(normalizedColor).inserted,
           byDay[day, default: []].count < 4 {
            byDay[day, default: []].append(colorHex)
        }
        if seenByWeek[week, default: []].insert(normalizedColor).inserted,
           byWeek[week, default: []].count < 4 {
            byWeek[week, default: []].append(colorHex)
        }
    }
}

private struct IOSHistoryActivityDots: View {
    let colors: [String]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(colors, id: \.self) { colorHex in
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 4, height: 4)
            }
        }
        .frame(height: 4)
    }
}

private struct IOSHistoryGlobalSearchList: View {
    let items: [HistoryCalendarItem]
    let searchText: String
    @Binding var selection: HistoryCalendarItem?

    var body: some View {
        if items.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(items) { item in
                        Button {
                            selection = item
                        } label: {
                            IOSHistoryGlobalSearchRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
    }
}

private struct IOSHistoryGlobalSearchRow: View {
    @Environment(\.locale) private var locale
    let item: HistoryCalendarItem

    var body: some View {
        HStack(spacing: 12) {
            Text(item.symbol)
                .font(.title3)
                .frame(width: 38, height: 38)
                .background(
                    Color(hex: item.colorHex).opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 8)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(item.startedAt, format: .dateTime.locale(locale).year().month().day())
                    .font(.caption.weight(.semibold))
                Text(item.startedAt, format: .dateTime.locale(locale).hour().minute())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
    }
}

private struct IOSHistoryTaskSummaryList: View {
    let snapshot: DayHistorySnapshot
    let searchText: String
    let visibleTypes: Set<DirectionType>

    private var visibleTasks: [DayHistoryTaskSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return snapshot.taskSummaries.filter { task in
            guard visibleTypes.contains(task.directionType) else { return false }
            guard !query.isEmpty else { return true }
            return [task.title, task.directionName, task.directionSymbol]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if visibleTasks.isEmpty {
                    ContentUnavailableView(
                        String(localized: "記録なし"),
                        systemImage: "clock.arrow.circlepath",
                        description: Text(String(localized: "この期間には集中記録もタスクもありません。"))
                    )
                    .padding(.top, 72)
                } else {
                    ForEach(visibleTasks) { task in
                        IOSHistorySummaryRow(
                            symbol: task.directionSymbol,
                            title: task.title,
                            subtitle: task.directionName,
                            colorHex: task.directionColorHex,
                            focusSeconds: task.focusSeconds,
                            flowCount: task.flowCount
                        )
                    }
                }
            }
            .padding(16)
        }
    }
}

private struct IOSHistoryDirectionSummaryList: View {
    let snapshot: DayHistorySnapshot
    let searchText: String
    let visibleTypes: Set<DirectionType>

    private var recordedDirections: [DayHistoryDirectionSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return snapshot.directionSummaries.filter { direction in
            guard direction.focusSeconds > 0 else { return false }
            guard visibleTypes.contains(direction.directionType) else { return false }
            guard !query.isEmpty else { return true }
            return [direction.name, direction.symbol]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if recordedDirections.isEmpty {
                    ContentUnavailableView(
                        String(localized: "記録なし"),
                        systemImage: "clock.arrow.circlepath",
                        description: Text(String(localized: "この期間には集中記録もタスクもありません。"))
                    )
                    .padding(.top, 72)
                } else {
                    ForEach(recordedDirections) { direction in
                        IOSHistorySummaryRow(
                            symbol: direction.symbol,
                            title: direction.name,
                            subtitle: nil,
                            colorHex: direction.colorHex,
                            focusSeconds: direction.focusSeconds,
                            flowCount: direction.flowCount
                        )
                    }
                }
            }
            .padding(16)
        }
    }
}

private struct IOSHistoryAggregateFilterMenu: View {
    @Binding var visibleTypes: Set<DirectionType>
    let neutralLabel: String

    var body: some View {
        Menu {
            filterToggle(neutralLabel, type: .neutral)
            filterToggle(String(localized: "習慣一覧"), type: .habit)
            filterToggle(String(localized: "ナイス"), type: .nice)
        } label: {
            Image(
                systemName: visibleTypes.count == DirectionType.allCases.count
                    ? "line.3.horizontal.decrease"
                    : "line.3.horizontal.decrease.circle.fill"
            )
            .frame(width: 30, height: 30)
        }
        .accessibilityLabel(String(localized: "表示内容"))
    }

    private func filterToggle(_ title: String, type: DirectionType) -> some View {
        Toggle(
            title,
            isOn: Binding(
                get: { visibleTypes.contains(type) },
                set: { isVisible in
                    if isVisible {
                        visibleTypes.insert(type)
                    } else {
                        visibleTypes.remove(type)
                    }
                }
            )
        )
    }
}

private struct IOSHistorySummaryRow: View {
    let symbol: String
    let title: String
    let subtitle: String?
    let colorHex: String
    let focusSeconds: Int
    let flowCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(symbol)
                .font(.title3)
                .frame(width: 38, height: 38)
                .background(Color(hex: colorHex).opacity(0.16), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                if let subtitle, subtitle != title {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(focusDurationText)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text(String(localized: "集中\(flowCount)回"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }

    private var focusDurationText: String {
        let minutes = focusSeconds / 60
        if minutes < 60 {
            return String(localized: "\(minutes)分")
        }
        return String(localized: "\(minutes / 60)時間\(minutes % 60)分")
    }
}

private struct IOSHistoryMonthGrid: View {
    let interval: DateInterval
    let items: [HistoryCalendarItem]
    @Binding var selectedDate: Date

    @Environment(\.calendar) private var calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(selectedDate, format: .dateTime.year().month(.wide))
                    .font(.headline)

                Spacer(minLength: 0)

                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel(String(localized: "前へ"))

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel(String(localized: "次へ"))
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(monthDates, id: \.self) { date in
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    Button {
                        selectedDate = date
                    } label: {
                        VStack(spacing: 5) {
                            Text(verbatim: String(calendar.component(.day, from: date)))
                                .font(.subheadline.weight(isSelected || calendar.isDateInToday(date) ? .bold : .regular))
                                .foregroundStyle(isSelected ? Color.white : Color.primary)
                                .frame(width: 30, height: 30)
                                .background(
                                    isSelected ? Color.accentColor : Color.clear,
                                    in: Circle()
                                )

                            HStack(spacing: 2) {
                                ForEach(colors(on: date).prefix(3), id: \.self) { colorHex in
                                    Circle()
                                        .fill(Color(hex: colorHex))
                                        .frame(width: 5, height: 5)
                                }
                            }
                            .frame(height: 5)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func moveMonth(by value: Int) {
        selectedDate = calendar.date(byAdding: .month, value: value, to: selectedDate) ?? selectedDate
    }

    private var monthDates: [Date] {
        guard let month = calendar.dateInterval(of: .month, for: interval.start),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: month.start) else { return [] }
        let lastDay = month.end.addingTimeInterval(-1)
        let lastWeekEnd = calendar.dateInterval(of: .weekOfYear, for: lastDay)?.end ?? month.end
        let count = max(0, calendar.dateComponents([.day], from: firstWeek.start, to: lastWeekEnd).day ?? 0)
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: firstWeek.start) }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = max(0, calendar.firstWeekday - 1)
        return Array(symbols[offset...] + symbols[..<offset])
    }

    private func colors(on date: Date) -> [String] {
        var seen = Set<String>()
        return items.compactMap { item in
            guard calendar.isDate(item.startedAt, inSameDayAs: date), item.kind == .flow else { return nil }
            return seen.insert(item.colorHex).inserted ? item.colorHex : nil
        }
    }
}

struct IOSHistoryItemDetail: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Direction.sortIndex) private var directions: [Direction]
    @Query(sort: \Todo.updatedAt, order: .reverse) private var todos: [Todo]

    let item: HistoryCalendarItem

    @State private var selectedTodoID: UUID?
    @State private var selectedDirectionID: UUID?
    @State private var taskTitleDraft: String
    @State private var timeDraft: FlowHistoryTimeDraft
    @State private var memo: String
    @State private var createdTodo: Todo?
    @State private var isCreatingTask = false
    @State private var showsDeleteConfirmation = false
    @State private var breakDurationMinutes: Int
    @State private var breakEndAt: Date
    @State private var breakEditError: String?

    private let editor = FlowHistoryEditor()
    private let breakEditor = FlowBreakEditor()

    init(item: HistoryCalendarItem) {
        self.item = item
        let session = item.session
        let selectedTodo = item.todo ?? session?.todo
        let selectedDirection = item.flowSegment?.direction ?? selectedTodo?.direction ?? session?.direction
        _selectedTodoID = State(initialValue: selectedTodo?.id)
        _selectedDirectionID = State(initialValue: selectedDirection?.id)
        _taskTitleDraft = State(initialValue: selectedTodo?.title ?? "")
        _timeDraft = State(initialValue: FlowHistoryTimeDraft(
            startedAt: item.startedAt,
            endedAt: item.endedAt,
            focusSeconds: item.durationSeconds
        ))
        _memo = State(initialValue: session?.result ?? selectedTodo?.notes ?? "")
        _breakDurationMinutes = State(
            initialValue: max(
                FlowBreakEditor.minimumDurationMinutes,
                item.durationSeconds / 60
            )
        )
        _breakEndAt = State(initialValue: item.endedAt)
        _breakEditError = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch item.kind {
                case .flow:
                    if let session = item.session {
                        flowEditor(session: session)
                    }
                case .rest:
                    if let flowBreak = item.flowBreak {
                        breakEditorView(flowBreak: flowBreak)
                    }
                }
            }
            .iosCenteredNavigationTitle(
                item.kind == .rest ? String(localized: "休憩") : String(localized: "集中記録")
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "閉じる")) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    switch item.kind {
                    case .flow:
                        if let session = item.session {
                            Button(String(localized: "保存")) {
                                save(session: session)
                            }
                            .disabled(selectedDirection == nil)
                        }
                    case .rest:
                        if let flowBreak = item.flowBreak {
                            Button(String(localized: "保存")) {
                                save(flowBreak: flowBreak)
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: selectedTodoID) { _, newValue in
            guard let newValue, let todo = todo(withID: newValue) else {
                taskTitleDraft = ""
                return
            }
            selectedDirectionID = todo.direction?.id
            taskTitleDraft = todo.title
            if memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                memo = todo.notes ?? ""
            }
        }
        .sheet(isPresented: $isCreatingTask) {
            if let selectedDirection {
                NavigationStack {
                    IOSTaskEditorView(
                        mode: .create,
                        directions: availableDirections,
                        fixedDirection: selectedDirection,
                        scheduledDate: item.startedAt
                    ) { todo in
                        attachCreatedTodo(todo)
                    }
                }
            }
        }
        .confirmationDialog(
            String(localized: "この集中記録を削除しますか？"),
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "削除"), role: .destructive) {
                guard let session = item.session else { return }
                if let segment = item.flowSegment {
                    editor.delete(
                        segment: segment,
                        from: session,
                        modelContext: modelContext
                    )
                } else {
                    editor.delete(session: session, modelContext: modelContext)
                }
                try? modelContext.save()
                dismiss()
            }
            Button(String(localized: "キャンセル"), role: .cancel) {}
        } message: {
            Text(String(localized: "この記録分の集中時間を、タスクと分野の合計から差し引きます。"))
        }
        .alert(
            String(localized: "移動できません"),
            isPresented: Binding(
                get: { breakEditError != nil },
                set: { if !$0 { breakEditError = nil } }
            )
        ) {
            Button(String(localized: "OK")) {
                breakEditError = nil
            }
        } message: {
            Text(breakEditError ?? "")
        }
    }

    private func attachCreatedTodo(_ todo: Todo) {
        guard let session = item.session else { return }
        createdTodo = todo
        selectedTodoID = todo.id
        selectedDirectionID = todo.direction?.id
        taskTitleDraft = todo.title

        if let segment = item.flowSegment {
            editor.attach(
                todo: todo,
                to: segment,
                in: session,
                modelContext: modelContext
            )
        } else {
            editor.attach(
                todo: todo,
                to: session,
                modelContext: modelContext
            )
        }
        try? modelContext.save()
    }

    private var selectedTodo: Todo? {
        guard let selectedTodoID else { return nil }
        return todo(withID: selectedTodoID)
    }

    private var selectedDirection: Direction? {
        selectedTodo?.direction
            ?? selectedDirectionID.flatMap { id in
                availableDirections.first { $0.id == id }
            }
    }

    private var availableDirections: [Direction] {
        directions.filter { !$0.isArchived }
    }

    private var availableTodos: [Todo] {
        var candidates = todos
        if let createdTodo, !candidates.contains(where: { $0.id == createdTodo.id }) {
            candidates.append(createdTodo)
        }

        return candidates
            .filter { todo in
                if todo.id == item.todo?.id || todo.id == item.session?.todo?.id {
                    return true
                }
                guard !todo.isDeleted, !todo.isArchived else { return false }
                return TodayTodoFilter().includes(todo, on: item.startedAt)
            }
            .sorted {
                if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
                if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
                return $0.createdAt < $1.createdAt
            }
    }

    private func todo(withID id: UUID) -> Todo? {
        todos.first { $0.id == id }
            ?? (createdTodo?.id == id ? createdTodo : nil)
    }

    @ViewBuilder
    private func flowEditor(session: FlowSession) -> some View {
        Form {
            Section(String(localized: "対象タスク")) {
                Picker(String(localized: "対象タスク"), selection: $selectedTodoID) {
                    Text(String(localized: "タスクなし")).tag(UUID?.none)
                    ForEach(availableTodos) { todo in
                        Text("\(todo.direction?.symbolName ?? "📥") \(TodoDisplay.title(for: todo))")
                            .tag(Optional(todo.id))
                    }
                }

                if selectedTodo != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "タスク名"))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField(
                            String(localized: "何をしましたか？"),
                            text: $taskTitleDraft,
                            axis: .vertical
                        )
                    }
                }

                Button {
                    isCreatingTask = true
                } label: {
                    Label(String(localized: "タスクを追加"), systemImage: "plus")
                }
                .disabled(selectedDirection == nil)
            }

            Section(String(localized: "分野")) {
                Picker(String(localized: "分野"), selection: $selectedDirectionID) {
                    ForEach(availableDirections) { direction in
                        Text("\(direction.symbolName) \(direction.name)")
                            .tag(Optional(direction.id))
                    }
                }
                .disabled(selectedTodo != nil)
            }

            Section(String(localized: "時間")) {
                DatePicker(
                    String(localized: "開始"),
                    selection: Binding(
                        get: { timeDraft.startedAt },
                        set: { timeDraft.setStartedAt($0) }
                    )
                )

                DatePicker(
                    String(localized: "終了"),
                    selection: Binding(
                        get: { timeDraft.endedAt },
                        set: { timeDraft.setEndedAt($0) }
                    )
                )

                Stepper(
                    String(localized: "\(timeDraft.focusMinutes)分"),
                    value: Binding(
                        get: { timeDraft.focusMinutes },
                        set: { timeDraft.setFocusMinutes($0) }
                    ),
                    in: 1...720
                )
            }

            Section(String(localized: "メモ")) {
                TextEditor(text: $memo)
                    .frame(minHeight: 110)
            }

            Section {
                Button(String(localized: "この集中記録を削除"), role: .destructive) {
                    showsDeleteConfirmation = true
                }
            }
        }
    }

    private func breakEditorView(flowBreak: FlowBreak) -> some View {
        Form {
            Section(String(localized: "時間")) {
                LabeledContent(
                    String(localized: "開始"),
                    value: flowBreak.startedAt.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )

                DatePicker(
                    String(localized: "終了"),
                    selection: Binding(
                        get: { breakEndAt },
                        set: { selectedTime in
                            let normalized = breakEditor.normalizedEndTime(
                                for: flowBreak,
                                selectedTime: selectedTime,
                                calendar: calendar
                            )
                            breakEndAt = normalized
                            breakDurationMinutes = breakEditor.durationMinutes(
                                from: flowBreak.startedAt,
                                to: normalized
                            )
                        }
                    ),
                    displayedComponents: [.hourAndMinute]
                )

                Stepper(
                    String(localized: "\(breakDurationMinutes)分"),
                    value: Binding(
                        get: { breakDurationMinutes },
                        set: { minutes in
                            breakDurationMinutes = minutes
                            breakEndAt = flowBreak.startedAt.addingTimeInterval(
                                TimeInterval(minutes * 60)
                            )
                        }
                    ),
                    in: FlowBreakEditor.minimumDurationMinutes
                        ... FlowBreakEditor.maximumDurationMinutes
                )
            }
        }
    }

    private func save(session: FlowSession) {
        guard let selectedDirection else { return }
        let now = Date.now
        selectedTodo?.rename(to: taskTitleDraft, now: now)
        if let segment = item.flowSegment {
            editor.update(
                segment: segment,
                in: session,
                todo: selectedTodo,
                direction: selectedDirection,
                startedAt: timeDraft.startedAt,
                focusSeconds: timeDraft.focusSeconds,
                memo: memo,
                modelContext: modelContext,
                now: now
            )
        } else {
            editor.update(
                session: session,
                todo: selectedTodo,
                direction: selectedDirection,
                startedAt: timeDraft.startedAt,
                focusSeconds: timeDraft.focusSeconds,
                memo: memo,
                modelContext: modelContext,
                now: now
            )
        }
        try? modelContext.save()
        dismiss()
    }

    private func save(flowBreak: FlowBreak) {
        do {
            _ = try breakEditor.updateDuration(
                of: flowBreak,
                minutes: breakDurationMinutes,
                modelContext: modelContext,
                protectedSessionID: activeFlowStore.activeSession?.id
            )
            dismiss()
        } catch FlowBreakEditorError.activeFlowWouldMove {
            breakEditError = String(localized: "進行中の集中は移動できません。")
        } catch {
            breakEditError = error.localizedDescription
        }
    }

    private var timeRange: String {
        "\(item.startedAt.formatted(date: .omitted, time: .shortened))–\(item.endedAt.formatted(date: .omitted, time: .shortened))"
    }

    private var durationText: String {
        let minutes = item.durationSeconds / 60
        return minutes >= 60
            ? String(localized: "\(minutes / 60)時間\(minutes % 60)分")
            : String(localized: "\(minutes)分")
    }
}
