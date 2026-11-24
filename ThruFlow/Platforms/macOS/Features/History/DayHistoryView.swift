//
//  DayHistoryView.swift
//  ThruFlow
//
//

import SwiftData
import SwiftUI

struct DayHistoryView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext

    private let initialDate: Date
    private let navigationRevision: Int
    private let isVisible: Bool
    @State private var startsDataSource = false
    @State private var dataCache: [MacHistoryCacheEntry] = []
    @State private var failedRequest: MacHistoryRequest?
    @State private var reportReveal = 0

    @State private var selectedDate: Date
    @State private var selectedMode: DayHistoryMode = .calendar
    @State private var selectedRange: HistoryCalendarRange = .week
    @State private var visibleCalendarKinds = Set(HistoryCalendarItemKind.allCases)
    @State private var visibleTaskTypes = Set(AreaType.allCases)
    @State private var visibleAreaTypes = Set(AreaType.allCases)
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var expandedTaskIDs: Set<String> = []
    @State private var expandedAreaIDs: Set<UUID> = []
    @State private var editingTodo: Todo?
    @State private var inspectedFlow: DayHistoryFlow?
    @State private var manualFlowRequest: HistoryManualFlowRequest?
    @State private var isAddingTaskRecord = false
    @State private var historyRecordStart = Date.now
    @State private var taskArea: Area?

    private let onClose: (() -> Void)?
    private var builder: DayHistoryBuilder {
        DayHistoryBuilder(calendar: calendar, dayBoundary: dayBoundary)
    }
    private var searchBuilder: DatabaseSearchBuilder {
        DatabaseSearchBuilder(calendar: calendar)
    }

    private var isSearching: Bool {
        DatabaseSearchQuery(text: searchText).isActive
    }

    private var periodInterval: DateInterval {
        selectedRange.interval(containing: selectedDate, calendar: calendar, dayBoundary: dayBoundary)
    }

    private var request: MacHistoryRequest {
        let miniCalendar = selectedRange == .month
            ? nil
            : HistoryMiniCalendar.displayedInterval(containing: selectedDate, calendar: calendar)
        return MacHistoryRequest(
            period: isSearching ? nil : periodInterval,
            miniCalendar: isSearching ? nil : miniCalendar,
            calendar: calendar
        )
    }

    private var currentData: MacHistoryData? {
        dataCache.first { $0.request == request }?.data
    }

    private var sessions: [FlowSession] { currentData?.sessions ?? [] }
    private var breaks: [FlowBreak] { currentData?.breaks ?? [] }
    private var todos: [Todo] { currentData?.todos ?? [] }
    private var areas: [Area] { currentData?.areas ?? [] }

    private var globalCalendarSearchItems: [HistoryCalendarItem] {
        searchBuilder.historyCalendarItems(
            query: searchText,
            sessions: sessions,
            breaks: breaks
        )
        .filter { visibleCalendarKinds.contains($0.kind) }
    }

    init(
        initialDate: Date = .now,
        navigationRevision: Int = 0,
        isVisible: Bool = true,
        onClose: (() -> Void)? = nil
    ) {
        self.initialDate = initialDate
        self.navigationRevision = navigationRevision
        self.isVisible = isVisible
        _selectedDate = State(initialValue: Calendar.current.startOfDay(for: initialDate))
        self.onClose = onClose
    }

    private var snapshot: DayHistorySnapshot {
        if isSearching {
            return searchBuilder.historySnapshot(
                query: searchText,
                sessions: sessions,
                todos: todos
            )
        }
        return builder.build(
            interval: periodInterval,
            sessions: sessions,
            todos: todos
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            modeContent
                .productContentFade(on: selectedMode)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            if isVisible {
                ToolbarItem(placement: .navigation) {
                    if let onClose {
                        Button(action: onClose) {
                            Image(systemName: "chevron.left")
                        }
                        .help(String(localized: "統計に戻る"))
                        .accessibilityLabel(String(localized: "統計に戻る"))
                    }
                }

                ToolbarItem(placement: .principal) {
                    modePicker
                        .fixedSize(horizontal: true, vertical: false)
                }

                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        contextualFilterMenu
                        MacToolbarSearchControl(
                            text: $searchText,
                            isPresented: $isSearchPresented
                        )
                        Button {
                            toggleHistoryRecord()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help(String(localized: "記録を追加"))
                        .accessibilityLabel(String(localized: "記録を追加"))
                    }
                }
            }
        }
        .background {
            if isVisible && startsDataSource {
                let requested = request
                MacHistoryDataSource(request: requested) { result in
                    guard requested == request else { return }
                    switch result {
                    case .success(let data):
                        let wasUncached = currentData == nil
                        if wasUncached { reportReveal &+= 1 }
                        dataCache.removeAll { $0.request == requested }
                        dataCache.insert(MacHistoryCacheEntry(request: requested, data: data), at: 0)
                        if dataCache.count > 4 { dataCache.removeLast() }
                        failedRequest = nil
                    case .failure(let error):
                        failedRequest = requested
                        PersistenceIssueCenter.shared.log(error, operation: .dataLoad)
                    }
                }
                .id(requested)
            }
        }
        .task(id: isVisible) {
            guard isVisible else {
                startsDataSource = false
                return
            }
            await Task.yield()
            guard !Task.isCancelled else { return }
            startsDataSource = true
        }
        .onChange(of: isSearching) { _, isSearching in
            if !isSearching {
                dataCache.removeAll { $0.request.period == nil }
            }
        }
        .onChange(of: navigationRevision) { _, _ in
            selectedDate = calendar.startOfDay(for: initialDate)
            selectedMode = .calendar
            selectedRange = .week
            searchText = ""
        }
        .inspector(isPresented: Binding(
            get: { isVisible && isAddingTaskRecord },
            set: { if isVisible { isAddingTaskRecord = $0 } }
        )) {
            HistoryTaskRecordForm(
                startedAt: historyRecordStart,
                context: HistoryRecordContext(selectedMode),
                onDismiss: { isAddingTaskRecord = false }
            )
            .id("\(historyRecordStart.timeIntervalSinceReferenceDate)-\(selectedMode.rawValue)")
            .inspectorColumnWidth(min: 420, ideal: 480, max: 560)
        }
        .sheet(item: $editingTodo) { todo in
            TodoFormView(mode: .edit(todo))
                .frame(minWidth: 480, idealWidth: 540, minHeight: 620, idealHeight: 700)
        }
        .sheet(item: $inspectedFlow) { flow in
            FlowHistoryInspectorView(
                session: flow.session,
                segment: flow.segment
            )
        }
        .sheet(item: $manualFlowRequest) { request in
            ManualFlowCreationView(
                startedAt: request.startedAt,
                todo: request.todo,
                locksTodo: true,
                onDismiss: { manualFlowRequest = nil }
            )
            .frame(minWidth: 420, idealWidth: 480, minHeight: 430, idealHeight: 500)
        }
        .sheet(item: $taskArea) { area in
            TodoFormView(
                mode: .create,
                fixedArea: area,
                scheduledDate: selectedDate
            )
            .frame(minWidth: 480, idealWidth: 540, minHeight: 620, idealHeight: 700)
        }
    }

    private var historyToolbar: some View {
        MacCalendarNavigationHeader(
            title: dateTitle,
            onPrevious: { moveHistoryPeriod(by: -1) },
            onToday: moveHistoryToToday,
            onNext: { moveHistoryPeriod(by: 1) }
        ) {
            rangePicker
        }
    }

    private var modePicker: some View {
        Picker(String(localized: "履歴表示"), selection: $selectedMode) {
            ForEach(DayHistoryMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel(String(localized: "履歴表示"))
    }

    private var rangePicker: some View {
        Picker(String(localized: "期間"), selection: $selectedRange) {
            ForEach(HistoryCalendarRange.allCases) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel(String(localized: "履歴の期間"))
    }

    @ViewBuilder
    private var contextualFilterMenu: some View {
        switch selectedMode {
        case .calendar:
            HistoryVisibilityMenu(visibleKinds: $visibleCalendarKinds)
        case .tasks:
            HistoryAggregateFilterMenu(
                visibleTypes: $visibleTaskTypes,
                neutralLabel: String(localized: "タスク")
            )
        case .areas:
            HistoryAggregateFilterMenu(
                visibleTypes: $visibleAreaTypes,
                neutralLabel: String(localized: "通常")
            )
        }
    }

    private var summary: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            HistorySummaryTile(
                title: String(localized: "集中"),
                value: durationText(snapshot.totalFocusSeconds),
                systemImage: "timer"
            )
            HistorySummaryTile(
                title: String(localized: "ブロック"),
                value: BlockUnit.displayText(forFocusedSeconds: snapshot.totalFocusSeconds),
                systemImage: "square.stack.3d.up"
            )
            HistorySummaryTile(
                title: String(localized: "集中回数"),
                value: "\(snapshot.flowCount)",
                systemImage: "waveform.path.ecg"
            )
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        if isSearching {
            if currentData != nil {
                globalSearchContent
            } else {
                loadStatus
            }
        } else {
            switch selectedMode {
            case .calendar:
                HistoryCalendarView(
                    selectedDate: $selectedDate,
                    range: $selectedRange,
                    sessions: sessions,
                    breaks: breaks,
                    hasLoaded: currentData != nil,
                    loadFailed: failedRequest == request,
                    reportReveal: reportReveal,
                    visibleKinds: $visibleCalendarKinds,
                    sidebarTitle: dateTitle,
                    sidebarHeader: AnyView(historyToolbar),
                    sidebarSummary: selectedRange == .day && currentData != nil
                        ? AnyView(daySidebarSummary)
                        : nil,
                    onAddRecord: presentHistoryRecord
                )
                .productContentFade(on: selectedRange)
            case .tasks:
                aggregateWorkspace { tasksContent }
            case .areas:
                aggregateWorkspace { areasContent }
            }
        }
    }

    @ViewBuilder
    private var loadStatus: some View {
        if failedRequest == request {
            ContentUnavailableView(
                String(localized: "データを読み込めませんでした。"),
                systemImage: "exclamationmark.circle"
            )
        } else {
            FeatureLoadingIndicator()
        }
    }

    @ViewBuilder
    private var globalSearchContent: some View {
        switch selectedMode {
        case .calendar:
            if globalCalendarSearchItems.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(globalCalendarSearchItems) { item in
                    Button {
                        openGlobalHistoryItem(item)
                    } label: {
                        MacHistoryGlobalSearchRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        case .tasks:
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summary
                    tasksContent
                }
                .frame(maxWidth: 920, alignment: .leading)
                .padding(16)
            }
        case .areas:
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summary
                    areasContent
                }
                .frame(maxWidth: 920, alignment: .leading)
                .padding(16)
            }
        }
    }

    private func aggregateWorkspace<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        GeometryReader { geometry in
            if geometry.size.width >= 900 {
                HStack(spacing: 0) {
                    aggregateList(content: content)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    aggregateInspector
                        .frame(
                            width: MacCalendarSidebarLayout.width(
                                for: dateTitle,
                                in: geometry.size.width,
                                preferredFraction: 0.30
                            )
                        )
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        historyToolbar
                        aggregatePeriodPicker
                        if currentData != nil {
                            summary
                            content()
                                .productContentFade(on: reportReveal)
                        } else {
                            loadStatus.frame(minHeight: 220)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private func aggregateList<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            if currentData != nil {
                content()
                    .productContentFade(on: reportReveal)
                    .frame(maxWidth: 920, alignment: .leading)
                    .padding(16)
            } else {
                loadStatus.frame(minHeight: 220)
            }
        }
    }

    private var aggregateInspector: some View {
        VStack(spacing: 0) {
            historyToolbar

            Divider()

            aggregatePeriodPicker
                .padding(16)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                if currentData != nil {
                    Text(periodSummaryTitle)
                        .font(.headline)
                    summary
                }
            }
            .padding(16)

            Spacer(minLength: 0)
        }
        .background(Color.secondary.opacity(0.035))
    }

    private var daySidebarSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "この日の記録"))
                .font(.headline)
            summary
        }
    }

    private var tasksContent: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "タスク別"))
                .font(.headline)

            if !isSearching, selectedRange == .week, !weeklyTaskSections.isEmpty {
                ForEach(weeklyTaskSections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(taskSectionTitle(section.date))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(calendar.isDateInToday(section.date) ? Color.accentColor : Color.secondary)
                            .padding(.top, 6)

                        taskRows(
                            filteredTasks(in: section.snapshot),
                            snapshot: section.snapshot,
                            expansionPrefix: section.id,
                            allowsGroupedCheckboxToggle: true
                        )
                    }
                }
            } else if filteredTaskSummaries.isEmpty {
                emptyState
            } else {
                taskRows(
                    filteredTaskSummaries,
                    snapshot: snapshot,
                    expansionPrefix: "range",
                    allowsGroupedCheckboxToggle: selectedRange == .day
                )
            }
        }
    }

    private var areasContent: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "方向別"))
                .font(.headline)

            if filteredAreaSummaries.isEmpty {
                emptyState
            } else {
                ForEach(filteredAreaSummaries) { area in
                    HistoryExpandableAreaRow(
                        area: area,
                        tasks: tasks(for: area),
                        isExpanded: expandedAreaIDs.contains(area.id),
                        onToggleExpansion: { toggleAreaExpansion(area.id) },
                        onToggleCheckbox: toggleCheckbox,
                        onEditTask: { todo in editingTodo = todo },
                        areaOnlyFlows: snapshot.flows.filter {
                            $0.areaID == area.areaID && $0.todoID == nil
                        },
                        onEditFlow: { flow in inspectedFlow = flow },
                        onAddTask: { taskArea = self.area(withID: area.areaID) }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            String(localized: "記録なし"),
            systemImage: "clock.arrow.circlepath",
            description: Text(String(localized: "この期間には集中記録もタスクもありません。"))
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var dateTitle: String {
        switch selectedRange {
        case .day:
            if calendar.isDateInToday(selectedDate) {
                return String(localized: "今日・\(fullDateFormatter.string(from: selectedDate))")
            }
            return fullDateFormatter.string(from: selectedDate)
        case .week:
            let interval = selectedRange.interval(
                containing: selectedDate,
                calendar: calendar,
                dayBoundary: dayBoundary
            )
            let end = interval.end.addingTimeInterval(-1)
            return "\(shortDateFormatter.string(from: interval.start))–\(shortDateFormatter.string(from: end))"
        case .month:
            return selectedDate.formatted(.dateTime.locale(locale).year().month(.wide))
        }
    }

    private var fullDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("yMdE")
        return formatter
    }

    private var shortDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return formatter
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        if minutes < 60 { return String(localized: "\(minutes)分") }
        return String(localized: "\(minutes / 60)時間\(minutes % 60)分")
    }

    @ViewBuilder
    private var aggregatePeriodPicker: some View {
        let indicatorSource = HistoryMiniCalendarIndicatorSource.filteredFlowHistory(
            selectedMode == .tasks ? visibleTaskTypes : visibleAreaTypes
        )

        switch selectedRange {
        case .day:
            HistoryMiniCalendar(
                selectedDate: $selectedDate,
                indicatorSource: indicatorSource,
                historySessions: sessions
            )
        case .week:
            HistoryMiniCalendar(
                selectedDate: $selectedDate,
                selectionMode: .week,
                indicatorSource: indicatorSource,
                historySessions: sessions
            )
        case .month:
            HistoryYearMonthPicker(selectedDate: $selectedDate)
        }
    }

    private var periodSummaryTitle: String {
        switch selectedRange {
        case .day: String(localized: "この日の記録")
        case .week: String(localized: "この週の記録")
        case .month: String(localized: "この月の記録")
        }
    }

    private var weeklyTaskSections: [HistoryTaskDaySection] {
        guard !isSearching, selectedRange == .week else { return [] }
        let interval = selectedRange.interval(
            containing: selectedDate,
            calendar: calendar,
            dayBoundary: dayBoundary
        )
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
            let daySnapshot = builder.build(
                date: date,
                sessions: sessions,
                todos: todos
            )
            guard !filteredTasks(in: daySnapshot).isEmpty else { return nil }
            return HistoryTaskDaySection(date: date, snapshot: daySnapshot)
        }
    }

    private var filteredTaskSummaries: [DayHistoryTaskSummary] {
        filteredTasks(in: snapshot)
    }

    private var filteredAreaSummaries: [DayHistoryAreaSummary] {
        snapshot.areaSummaries.filter { visibleAreaTypes.contains($0.areaType) }
    }

    private func filteredTasks(in snapshot: DayHistorySnapshot) -> [DayHistoryTaskSummary] {
        snapshot.taskSummaries.filter { visibleTaskTypes.contains($0.areaType) }
    }

    private func moveHistoryPeriod(by value: Int) {
        selectedDate = selectedRange.moving(selectedDate, by: value, calendar: calendar)
    }

    private func moveHistoryToToday() {
        selectedDate = dayBoundary.day(containing: .now, calendar: calendar)
    }

    private func openGlobalHistoryItem(_ item: HistoryCalendarItem) {
        selectedDate = calendar.startOfDay(for: item.startedAt)
        selectedRange = .day
        selectedMode = .calendar
        searchText = ""
    }

    @ViewBuilder
    private func taskRows(
        _ tasks: [DayHistoryTaskSummary],
        snapshot: DayHistorySnapshot,
        expansionPrefix: String,
        allowsGroupedCheckboxToggle: Bool
    ) -> some View {
        ForEach(tasks) { task in
            let expansionID = "\(expansionPrefix)-\(task.id)"
            HistoryExpandableTaskRow(
                task: task,
                flows: flows(for: task, in: snapshot),
                isExpanded: expandedTaskIDs.contains(expansionID),
                onToggleExpansion: { toggleTaskExpansion(expansionID) },
                onToggleCheckbox: task.todos.count == 1 || allowsGroupedCheckboxToggle
                    ? { toggleCheckbox(task) }
                    : nil,
                onEdit: { todo in editingTodo = todo },
                onEditFlow: { flow in inspectedFlow = flow },
                onAddFlow: { todo in presentManualFlow(for: todo) }
            )
        }
    }

    private func flows(for task: DayHistoryTaskSummary, in snapshot: DayHistorySnapshot) -> [DayHistoryFlow] {
        return snapshot.flows.filter { flow in
            if let todoID = flow.todoID, !task.linkedTodoIDs.isEmpty {
                return task.linkedTodoIDs.contains(todoID)
            }
            return flow.todoID == nil && flow.areaID == task.areaID
        }
    }

    private func tasks(for area: DayHistoryAreaSummary) -> [DayHistoryTaskSummary] {
        snapshot.taskSummaries.filter { $0.areaID == area.areaID && $0.todo != nil }
    }

    private func toggleTaskExpansion(_ id: String) {
        withAnimation(.snappy(duration: 0.2)) {
            if expandedTaskIDs.remove(id) == nil { expandedTaskIDs.insert(id) }
        }
    }

    private func toggleAreaExpansion(_ id: UUID) {
        withAnimation(.snappy(duration: 0.2)) {
            if expandedAreaIDs.remove(id) == nil { expandedAreaIDs.insert(id) }
        }
    }

    private func taskSectionTitle(_ date: Date) -> String {
        date.formatted(.dateTime.locale(locale).month().day().weekday(.wide))
    }

    private func toggleCheckbox(_ task: DayHistoryTaskSummary) {
        guard !task.todos.isEmpty,
              task.todos.allSatisfy({ $0.measurement == .checkbox }) else { return }
        let shouldComplete = !task.todos.allSatisfy(\.isCompleted)
        task.todos.forEach { $0.setManuallyCompleted(shouldComplete) }
        _ = modelContext.saveReporting(.historyUpdate)
    }

    private func area(withID id: UUID) -> Area? {
        areas.first { $0.id == id }
    }

    private func presentManualFlow(for todo: Todo) {
        manualFlowRequest = HistoryManualFlowRequest(
            todo: todo,
            startedAt: defaultManualFlowStart(on: todo.scheduledDate ?? selectedDate)
        )
    }

    private func presentHistoryRecord(at startedAt: Date) {
        historyRecordStart = startedAt
        isAddingTaskRecord = true
    }

    private func toggleHistoryRecord() {
        if isAddingTaskRecord {
            isAddingTaskRecord = false
        } else {
            presentHistoryRecord(at: defaultManualFlowStart(on: selectedDate))
        }
    }

    private func defaultManualFlowStart(on date: Date) -> Date {
        if calendar.isDateInToday(date) {
            return Date().addingTimeInterval(-25 * 60)
        }
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
    }
}

private struct HistoryManualFlowRequest: Identifiable {
    let id = UUID()
    let todo: Todo
    let startedAt: Date
}

private struct HistoryTaskDaySection: Identifiable {
    let date: Date
    let snapshot: DayHistorySnapshot

    var id: String { date.ISO8601Format() }
}

#Preview {
    DayHistoryView()
        .environmentObject(ActiveFlowStore())
        .modelContainer(for: [Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self], inMemory: true)
}
