//
//  DayHistoryView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/11.
//

import SwiftData
import SwiftUI

struct DayHistoryView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FlowSession.startedAt, order: .reverse) private var sessions: [FlowSession]
    @Query(sort: \FlowBreak.startedAt, order: .reverse) private var breaks: [FlowBreak]
    @Query(sort: \Todo.updatedAt, order: .reverse) private var todos: [Todo]
    @Query(sort: \Direction.sortIndex) private var directions: [Direction]

    @State private var selectedDate: Date
    @State private var selectedMode: DayHistoryMode = .calendar
    @State private var selectedRange: HistoryCalendarRange = .week
    @State private var visibleCalendarKinds = Set(HistoryCalendarItemKind.allCases)
    @State private var visibleTaskTypes = Set(DirectionType.allCases)
    @State private var visibleDirectionTypes = Set(DirectionType.allCases)
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var expandedTaskIDs: Set<String> = []
    @State private var expandedDirectionIDs: Set<UUID> = []
    @State private var editingTodo: Todo?
    @State private var inspectedSession: FlowSession?
    @State private var manualFlowRequest: HistoryManualFlowRequest?
    @State private var isAddingTaskRecord = false
    @State private var taskDirection: Direction?

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

    private var globalCalendarSearchItems: [HistoryCalendarItem] {
        searchBuilder.historyCalendarItems(
            query: searchText,
            sessions: sessions,
            breaks: breaks
        )
        .filter { visibleCalendarKinds.contains($0.kind) }
    }

    init(initialDate: Date = .now, onClose: (() -> Void)? = nil) {
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
            interval: selectedRange.interval(
                containing: selectedDate,
                calendar: calendar,
                dayBoundary: dayBoundary
            ),
            sessions: searchFilteredSessions,
            todos: searchFilteredTodos
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            modeContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(String(localized: "履歴"))
        .toolbarBackground(.bar, for: .windowToolbar)
        .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
        .toolbar {
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
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            addHistoryRecordButton
        }
        .sheet(item: $editingTodo) { todo in
            TodoFormView(mode: .edit(todo))
                .frame(minWidth: 480, idealWidth: 540, minHeight: 620, idealHeight: 700)
        }
        .sheet(item: $inspectedSession) { session in
            FlowHistoryInspectorView(session: session)
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
        .sheet(isPresented: $isAddingTaskRecord) {
            HistoryTaskRecordForm(
                startedAt: defaultManualFlowStart(on: selectedDate),
                onDismiss: { isAddingTaskRecord = false }
            )
            .frame(minWidth: 460, idealWidth: 520, minHeight: 560, idealHeight: 650)
        }
        .sheet(item: $taskDirection) { direction in
            TodoFormView(
                mode: .create,
                fixedDirection: direction,
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
        Picker("", selection: $selectedMode) {
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
        case .directions:
            HistoryAggregateFilterMenu(
                visibleTypes: $visibleDirectionTypes,
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
                title: String(localized: "Flow"),
                value: "\(snapshot.flowCount)",
                systemImage: "waveform.path.ecg"
            )
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        if isSearching {
            globalSearchContent
        } else {
            switch selectedMode {
            case .calendar:
                HistoryCalendarView(
                    selectedDate: $selectedDate,
                    range: $selectedRange,
                    sessions: searchFilteredSessions,
                    breaks: searchFilteredBreaks,
                    visibleKinds: $visibleCalendarKinds,
                    sidebarTitle: dateTitle,
                    sidebarHeader: AnyView(historyToolbar),
                    sidebarSummary: selectedRange == .day
                        ? AnyView(daySidebarSummary)
                        : nil
                )
            case .tasks:
                aggregateWorkspace { tasksContent }
            case .directions:
                aggregateWorkspace { directionsContent }
            }
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
        case .directions:
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summary
                    directionsContent
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
                        summary
                        content()
                    }
                    .padding(16)
                }
            }
        }
    }

    private func aggregateList<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .frame(maxWidth: 920, alignment: .leading)
                .padding(16)
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
                Text(periodSummaryTitle)
                    .font(.headline)
                summary
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
        VStack(alignment: .leading, spacing: 12) {
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

    private var addHistoryRecordButton: some View {
        Button {
            isAddingTaskRecord = true
        } label: {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.accentColor, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 16)
        .padding(.bottom, 14)
        .help(String(localized: "記録を追加"))
        .accessibilityLabel(String(localized: "記録を追加"))
    }

    private var directionsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "方向別"))
                .font(.headline)

            if filteredDirectionSummaries.isEmpty {
                emptyState
            } else {
                ForEach(filteredDirectionSummaries) { direction in
                    HistoryExpandableDirectionRow(
                        direction: direction,
                        tasks: tasks(for: direction),
                        isExpanded: expandedDirectionIDs.contains(direction.id),
                        onToggleExpansion: { toggleDirectionExpansion(direction.id) },
                        onToggleCheckbox: toggleCheckbox,
                        onEditTask: { todo in editingTodo = todo },
                        directionOnlyFlows: snapshot.flows.filter {
                            $0.directionID == direction.directionID && $0.todoID == nil
                        },
                        onEditFlow: { flow in inspectedSession = flow.session },
                        onAddTask: { taskDirection = self.direction(withID: direction.directionID) }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            String(localized: "記録なし"),
            systemImage: "clock.arrow.circlepath",
            description: Text(String(localized: "この期間のFlowとタスクはありません。"))
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var dateTitle: String {
        switch selectedRange {
        case .day:
            if calendar.isDateInToday(selectedDate) {
                return String(localized: "今日 ・ \(fullDateFormatter.string(from: selectedDate))")
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
            selectedMode == .tasks ? visibleTaskTypes : visibleDirectionTypes
        )

        switch selectedRange {
        case .day:
            HistoryMiniCalendar(
                selectedDate: $selectedDate,
                indicatorSource: indicatorSource
            )
        case .week:
            HistoryMiniCalendar(
                selectedDate: $selectedDate,
                selectionMode: .week,
                indicatorSource: indicatorSource
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
                sessions: searchFilteredSessions,
                todos: searchFilteredTodos
            )
            guard !filteredTasks(in: daySnapshot).isEmpty else { return nil }
            return HistoryTaskDaySection(date: date, snapshot: daySnapshot)
        }
    }

    private var filteredTaskSummaries: [DayHistoryTaskSummary] {
        filteredTasks(in: snapshot)
    }

    private var filteredDirectionSummaries: [DayHistoryDirectionSummary] {
        snapshot.directionSummaries.filter { visibleDirectionTypes.contains($0.directionType) }
    }

    private func filteredTasks(in snapshot: DayHistorySnapshot) -> [DayHistoryTaskSummary] {
        snapshot.taskSummaries.filter { visibleTaskTypes.contains($0.directionType) }
    }

    private var searchFilteredTodos: [Todo] {
        todos.filter(matchesSearch)
    }

    private var searchFilteredSessions: [FlowSession] {
        sessions.filter(matchesSearch)
    }

    private var searchFilteredBreaks: [FlowBreak] {
        let query = normalizedSearchQuery
        guard !query.isEmpty else { return breaks }
        if String(localized: "休憩").localizedCaseInsensitiveContains(query) {
            return breaks
        }

        let sessionIDs = Set(searchFilteredSessions.map(\.id))
        let seriesIDs = Set(searchFilteredSessions.compactMap(\.seriesID))
        return breaks.filter { flowBreak in
            sessionIDs.contains(flowBreak.previousSessionID)
                || flowBreak.nextSessionID.map(sessionIDs.contains) == true
                || seriesIDs.contains(flowBreak.seriesID)
        }
    }

    private var normalizedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func moveHistoryPeriod(by value: Int) {
        selectedDate = selectedRange.moving(selectedDate, by: value, calendar: calendar)
    }

    private func moveHistoryToToday() {
        selectedDate = dayBoundary.day(containing: .now, calendar: calendar)
    }

    private func matchesSearch(_ todo: Todo) -> Bool {
        DatabaseSearchQuery(text: searchText).matchesHistory(todo)
    }

    private func matchesSearch(_ session: FlowSession) -> Bool {
        DatabaseSearchQuery(text: searchText).matchesHistory(session)
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
                onEditFlow: { flow in inspectedSession = flow.session },
                onAddFlow: { todo in presentManualFlow(for: todo) }
            )
        }
    }

    private func flows(for task: DayHistoryTaskSummary, in snapshot: DayHistorySnapshot) -> [DayHistoryFlow] {
        return snapshot.flows.filter { flow in
            if let todoID = flow.todoID, !task.linkedTodoIDs.isEmpty {
                return task.linkedTodoIDs.contains(todoID)
            }
            return flow.todoID == nil && flow.directionID == task.directionID
        }
    }

    private func tasks(for direction: DayHistoryDirectionSummary) -> [DayHistoryTaskSummary] {
        snapshot.taskSummaries.filter { $0.directionID == direction.directionID && $0.todo != nil }
    }

    private func toggleTaskExpansion(_ id: String) {
        withAnimation(.snappy(duration: 0.2)) {
            if expandedTaskIDs.remove(id) == nil { expandedTaskIDs.insert(id) }
        }
    }

    private func toggleDirectionExpansion(_ id: UUID) {
        withAnimation(.snappy(duration: 0.2)) {
            if expandedDirectionIDs.remove(id) == nil { expandedDirectionIDs.insert(id) }
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
        try? modelContext.save()
    }

    private func direction(withID id: UUID) -> Direction? {
        directions.first { $0.id == id }
    }

    private func presentManualFlow(for todo: Todo) {
        manualFlowRequest = HistoryManualFlowRequest(
            todo: todo,
            startedAt: defaultManualFlowStart(on: todo.scheduledDate ?? selectedDate)
        )
    }

    private func defaultManualFlowStart(on date: Date) -> Date {
        if calendar.isDateInToday(date) {
            return Date().addingTimeInterval(-25 * 60)
        }
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
    }
}

private struct MacHistoryGlobalSearchRow: View {
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
        .padding(.vertical, 8)
        .contentShape(Rectangle())
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

private struct HistorySummaryTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Color.secondary.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct HistoryAggregateFilterMenu: View {
    @Binding var visibleTypes: Set<DirectionType>
    let neutralLabel: String

    var body: some View {
        Menu {
            filterToggle(neutralLabel, type: .neutral)
            filterToggle(String(localized: "習慣"), type: .habit)
            filterToggle(String(localized: "ナイス"), type: .nice)
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
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
        .toggleStyle(.checkbox)
    }
}

private struct HistoryExpandableTaskRow: View {
    let task: DayHistoryTaskSummary
    let flows: [DayHistoryFlow]
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let onToggleCheckbox: (() -> Void)?
    let onEdit: (Todo) -> Void
    let onEditFlow: (DayHistoryFlow) -> Void
    let onAddFlow: (Todo) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HistoryTodoProgressIndicator(
                    task: task,
                    onToggleCheckbox: onToggleCheckbox
                )

                HStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Text(task.directionSymbol)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.body.weight(.medium))
                                .strikethrough(task.todo?.isCompleted == true)
                                .lineLimit(1)
                            Text(String(localized: "\(task.directionName) ・ \(task.flowCount) Flow"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        if let todo = task.todo { onEdit(todo) }
                    }

                    Spacer(minLength: 8)

                    Text(durationText(task.focusSeconds))
                        .font(.callout.weight(.semibold).monospacedDigit())

                    if let todo = task.todo {
                        Button {
                            onAddFlow(todo)
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help(String(localized: "このタスクにFlowを追加"))
                        .accessibilityLabel(String(localized: "このタスクにFlowを追加"))
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onToggleExpansion)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            if isExpanded {
                Divider().padding(.leading, 54)
                if flows.isEmpty {
                    Text(String(localized: "この期間のFlowはありません"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 56)
                        .padding(.vertical, 10)
                } else {
                    ForEach(flows) { flow in
                        HistoryFlowDisclosureRow(flow: flow) {
                            onEditFlow(flow)
                        }
                    }
                }
            }
        }
        .background(Color.secondary.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        return minutes < 60 ? String(localized: "\(minutes)分") : String(localized: "\(minutes / 60)時間\(minutes % 60)分")
    }
}

private struct HistoryTodoProgressIndicator: View {
    let task: DayHistoryTaskSummary
    let onToggleCheckbox: (() -> Void)?

    @ViewBuilder
    var body: some View {
        switch measurement {
        case .checkbox:
            if let onToggleCheckbox {
                Button(action: onToggleCheckbox) {
                    checkbox
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(width: 34, height: 34)
                .accessibilityLabel(isCompleted ? String(localized: "未完了に戻す") : String(localized: "完了にする"))
                .accessibilityValue(progressDescription)
            } else {
                checkbox
                    .frame(width: 34, height: 34)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(localized: "タスク進捗"))
                    .accessibilityValue(progressDescription)
            }
        case .focusBlocks, .minutes:
            progressRing
                .frame(width: 34, height: 34)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "タスク進捗"))
                .accessibilityValue(progressDescription)
        }
    }

    private var checkbox: some View {
        RoundedRectangle(cornerRadius: 5)
            .strokeBorder(tint, lineWidth: 1.6)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(isCompleted ? tint : Color.clear)
            }
            .overlay {
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 20, height: 20)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.22), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if measurement == .minutes {
                Image(systemName: "timer")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(tint)
            } else if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: 22, height: 22)
    }

    private var measurement: TodoMeasurement {
        task.todo?.measurement ?? .checkbox
    }

    private var isCompleted: Bool {
        !task.todos.isEmpty && task.todos.allSatisfy(\.isCompleted)
    }

    private var progress: Double {
        guard !task.todos.isEmpty else { return 0 }
        switch measurement {
        case .checkbox:
            return Double(task.todos.filter(\.isCompleted).count) / Double(task.todos.count)
        case .focusBlocks:
            let target = task.todos.reduce(0) { $0 + max(1, $1.plannedAmount ?? 1) }
            return min(BlockUnit.blocks(forFocusedSeconds: task.focusSeconds) / Double(target), 1)
        case .minutes:
            let target = task.todos.reduce(0) { $0 + max(1, $1.plannedAmount ?? 1) }
            return min(Double(task.focusSeconds) / 60 / Double(target), 1)
        }
    }

    private var tint: Color {
        Color(hex: task.directionColorHex)
    }

    private var progressDescription: String {
        if isCompleted { return String(localized: "完了") }
        return "\(Int((progress * 100).rounded()))%"
    }
}

private struct HistoryExpandableDirectionRow: View {
    let direction: DayHistoryDirectionSummary
    let tasks: [DayHistoryTaskSummary]
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let onToggleCheckbox: (DayHistoryTaskSummary) -> Void
    let onEditTask: (Todo) -> Void
    let directionOnlyFlows: [DayHistoryFlow]
    let onEditFlow: (DayHistoryFlow) -> Void
    let onAddTask: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(direction.symbol)
                    .font(.title2)
                    .frame(width: 34, height: 34)
                    .background(Color(hex: direction.colorHex).opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 3) {
                    Text(direction.name)
                        .font(.body.weight(.medium))
                    Text(String(localized: "\(direction.taskCount) タスク ・ \(direction.flowCount) Flow"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(durationText(direction.focusSeconds))
                    .font(.callout.weight(.semibold).monospacedDigit())

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(12)
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggleExpansion)

            if isExpanded {
                Divider().padding(.leading, 54)
                if tasks.isEmpty && directionOnlyFlows.isEmpty {
                    Text(String(localized: "この期間のタスクはありません"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 56)
                        .padding(.vertical, 10)
                } else {
                    ForEach(tasks) { task in
                        HStack(spacing: 10) {
                            if task.todo != nil {
                                HistoryTodoProgressIndicator(
                                    task: task,
                                    onToggleCheckbox: task.todos.count == 1 ? { onToggleCheckbox(task) } : nil
                                )
                            }
                            Text(task.directionSymbol)
                            Text(task.title)
                                .strikethrough(task.todo?.isCompleted == true)
                                .lineLimit(1)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    if let todo = task.todo { onEditTask(todo) }
                                }
                            Spacer()
                            Text(durationText(task.focusSeconds))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.trailing, 12)
                        .padding(.vertical, 4)
                    }
                }

                ForEach(directionOnlyFlows) { flow in
                    HistoryFlowDisclosureRow(flow: flow) {
                        onEditFlow(flow)
                    }
                }

                Button(action: onAddTask) {
                    Label(String(localized: "タスクを追加"), systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 46)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel(String(localized: "\(direction.name)にタスクを追加"))
            }
        }
        .background(Color.secondary.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        return minutes < 60 ? String(localized: "\(minutes)分") : String(localized: "\(minutes / 60)時間\(minutes % 60)分")
    }
}

private struct HistoryFlowDisclosureRow: View {
    @Environment(\.locale) private var locale

    let flow: DayHistoryFlow
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: flow.directionColorHex))
                    .frame(width: 4, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(flow.taskTitle)
                        .font(.callout)
                        .lineLimit(1)
                    Text("\(time(flow.startedAt))–\(time(flow.endedAt))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(duration(flow.focusSeconds))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, 56)
        .padding(.trailing, 12)
        .padding(.vertical, 7)
        .accessibilityLabel(String(localized: "Flowを編集"))
    }

    private func time(_ date: Date) -> String {
        date.formatted(.dateTime.locale(locale).hour().minute())
    }

    private func duration(_ seconds: Int) -> String {
        String(localized: "\(max(0, seconds) / 60)分")
    }
}

#Preview {
    DayHistoryView()
        .environmentObject(ActiveFlowStore())
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self], inMemory: true)
}
