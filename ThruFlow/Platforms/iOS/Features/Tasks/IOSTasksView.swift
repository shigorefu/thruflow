import SwiftData
import SwiftUI

struct IOSTasksView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var isVisible = true

    @State private var observesRecords = false
    @State private var records: IOSTaskCalendarRecords?
    @State private var loadFailed = false
    @State private var revealsInitialRows = false
    @State private var hasMountedComposer = false
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var range = TaskCalendarRange.oneDay
    @State private var filter = TaskCalendarFilter.all
    @State private var editorMode: IOSTaskEditorMode?
    @State private var backlogMode: IOSBacklogMode?
    @State private var pendingBacklogMode: IOSBacklogMode?
    @State private var showsBacklogMenu = false
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var showsComposer = false
    @State private var composerID = UUID()
    @State private var backlogMoveError: String?
    @State private var hasPerformedInitialMaterialization = false
    @State private var calendarDayRevision = 0

    private var calendarBuilder: TaskCalendarBuilder { TaskCalendarBuilder(calendar: calendar) }
    private var rescheduleService: TaskRescheduleService {
        TaskRescheduleService(calendar: calendar, dayBoundary: dayBoundary)
    }
    private var searchBuilder: DatabaseSearchBuilder { DatabaseSearchBuilder(calendar: calendar) }
    private var todos: [Todo] { records?.todos ?? [] }
    private var areas: [Area] { records?.areas ?? [] }
    private var projects: [Project] { records?.projects ?? [] }

    private var usesPersistentComposer: Bool { horizontalSizeClass == .regular }

    private var isComposerVisible: Bool { usesPersistentComposer || showsComposer }

    private var isSearching: Bool {
        DatabaseSearchQuery(text: searchText).isActive
    }

    private var searchSections: [DatabaseTaskSearchSection] {
        searchBuilder.taskSections(
            query: searchText,
            todos: todos,
            filter: filter
        )
    }

    private var activeAreas: [Area] {
        areas.filter { !$0.isArchived }
    }

    private var visibleDates: [Date] {
        calendarBuilder.dates(for: range, anchoredAt: selectedDate)
    }

    private var taskSearchQuery: DatabaseSearchQuery {
        DatabaseSearchQuery(text: searchText)
    }

    var body: some View {
        content(snapshot: records?.snapshot)
    }

    private func content(snapshot: TaskCalendarSnapshot?) -> some View {
        VStack(spacing: 0) {
            if !isSearching {
                controls(snapshot: snapshot)
                Divider()
            }
            if let snapshot {
                if isSearching {
                    IOSTaskSearchResults(
                        searchText: searchText,
                        sections: searchSections,
                        onEditTodo: { editorMode = .edit($0) }
                    )
                } else {
                    taskContent(snapshot: snapshot)
                        .productContentFade(on: range)
                        .iosPeriodSwipeNavigation(pageID: selectedPeriodPageID) { offset in
                            navigatePeriod(by: offset)
                        }
                }
            } else if loadFailed {
                ContentUnavailableView(
                    String(localized: "データを読み込めませんでした。"),
                    systemImage: "exclamationmark.triangle"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                FeatureLoadingIndicator()
            }
        }
        .background {
            if isVisible, observesRecords {
                IOSTaskCalendarQuery(calendarDayRevision: calendarDayRevision) { result in
                    switch result {
                    case .success(let records):
                        if self.records == nil { revealsInitialRows = true }
                        self.records = records
                        loadFailed = false
                    case .failure(let error):
                        loadFailed = true
                        PersistenceIssueCenter.shared.log(error, operation: .dataLoad)
                    }
                }
            }
        }
        .background {
            Rectangle()
                .fill(.background)
                .ignoresSafeArea()
        }
        .iosCenteredNavigationTitle(String(localized: "タスク"))
        .iosToolbarSearch(
            text: $searchText,
            isPresented: $isSearchPresented,
            prompt: String(localized: "検索")
        )
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ZStack(alignment: .topTrailing) {
                    Button {
                        showsBacklogMenu.toggle()
                    } label: {
                        IOSMoreMenuLabel()
                    }
                    .accessibilityLabel(String(localized: "その他"))
                    .accessibilityValue("\(backlogCount(in: snapshot))")
                    .disabled(snapshot == nil)

                    IOSNotificationBadge(count: backlogCount(in: snapshot))
                        .allowsHitTesting(false)
                }
                .frame(width: 44, height: 44)
                .popover(isPresented: $showsBacklogMenu, arrowEdge: .top) {
                    if let snapshot {
                        backlogMenuContent(snapshot: snapshot)
                            .presentationCompactAdaptation(.popover)
                            .onDisappear(perform: presentPendingBacklog)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if hasMountedComposer || isComposerVisible {
                taskComposer
                    .id(composerID)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                    .background(.background)
                    .frame(height: isComposerVisible ? nil : 0)
                    .opacity(isComposerVisible ? 1 : 0)
                    .allowsHitTesting(isComposerVisible)
                    .accessibilityHidden(!isComposerVisible)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !isComposerVisible {
                addTaskButton
            }
        }
        .sheet(item: $editorMode) { mode in
            NavigationStack {
                IOSTaskEditorView(mode: mode, areas: activeAreas)
            }
        }
        .sheet(item: $backlogMode) { mode in
            NavigationStack {
                if let snapshot {
                    IOSBacklogView(
                        mode: mode,
                        todos: mode == .overdue
                            ? snapshot.backlog.overdue
                            : snapshot.backlog.unscheduled,
                        edit: { todo in
                            backlogMode = nil
                            editorMode = .edit(todo)
                        }
                    )
                }
            }
        }
        .alert(
            String(localized: "移動できません"),
            isPresented: Binding(
                get: { backlogMoveError != nil },
                set: { if !$0 { backlogMoveError = nil } }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) {
                backlogMoveError = nil
            }
        } message: {
            Text(backlogMoveError ?? "")
        }
        .task(id: isVisible) {
            guard isVisible else {
                revealsInitialRows = false
                return
            }
            if !observesRecords {
                alignInitialSelectionWithCurrentAppDay()
            }
            await Task.yield()
            guard !Task.isCancelled else { return }
            observesRecords = true
        }
        .task(id: requiredTodoMaterializationID) {
            guard isVisible, records != nil else { return }
            if !hasPerformedInitialMaterialization {
                await Task.yield()
                guard !Task.isCancelled else { return }
                ensureRequiredTodos(reconcilesDuplicates: true)
                hasPerformedInitialMaterialization = true
                return
            }
            do {
                try await Task.sleep(for: .milliseconds(180))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            ensureRequiredTodos(reconcilesDuplicates: false)
        }
        .onChange(of: isComposerVisible, initial: true) { _, isPresented in
            if isPresented { hasMountedComposer = true }
        }
        .onChange(of: selectedPeriodPageID) { _, _ in revealsInitialRows = false }
        .onChange(of: range) { _, _ in revealsInitialRows = false }
        .onChange(of: filter) { _, _ in revealsInitialRows = false }
        .onChange(of: isSearching) { _, _ in revealsInitialRows = false }
        .onChange(of: horizontalSizeClass) { _, _ in
            // Folding restores + without discarding the mounted draft.
            showsComposer = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            calendarDayRevision += 1
        }
    }

    private var taskComposer: some View {
        IOSTaskComposer(
            areas: activeAreas,
            suggestionTodos: todos,
            autofocusOnAppear: !usesPersistentComposer,
            isPresented: isComposerVisible,
            allowsSubmission: records != nil,
            onClose: composerCloseAction
        )
    }

    private var composerCloseAction: (() -> Void)? {
        guard !usesPersistentComposer else { return nil }
        return { dismissComposer() }
    }

    private var addTaskButton: some View {
        Button(action: presentComposer) {
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
        .transition(.scale(scale: 0.85).combined(with: .opacity))
        .accessibilityLabel(String(localized: "タスクを追加"))
    }

    private func presentComposer() {
        withAnimation(.snappy(duration: 0.28)) {
            showsComposer = true
        }
    }

    private func dismissComposer() {
        withAnimation(.snappy(duration: 0.24)) {
            showsComposer = false
            composerID = UUID()
        }
    }

    private func navigatePeriod(by offset: Int) {
        let date = calendarBuilder.advancedDate(
            from: selectedDate,
            range: range,
            area: offset
        )
        selectedDate = calendar.startOfDay(for: date)
    }

    private var selectedPeriodPageID: Date {
        switch range {
        case .oneDay:
            calendar.startOfDay(for: selectedDate)
        case .sevenDays:
            calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start
                ?? calendar.startOfDay(for: selectedDate)
        case .month:
            calendar.dateInterval(of: .month, for: selectedDate)?.start
                ?? calendar.startOfDay(for: selectedDate)
        }
    }

    private func backlogMenuContent(snapshot: TaskCalendarSnapshot) -> some View {
        VStack(spacing: 4) {
            backlogMenuButton(
                String(localized: "やり残し"),
                count: snapshot.backlog.overdue.count,
                systemImage: "exclamationmark.circle",
                mode: .overdue
            )
            backlogMenuButton(
                String(localized: "日付なし"),
                count: snapshot.backlog.unscheduled.count,
                systemImage: "tray",
                mode: .unscheduled
            )
        }
        .padding(8)
        .frame(width: 200)
    }

    private func backlogMenuButton(
        _ title: String,
        count: Int,
        systemImage: String,
        mode: IOSBacklogMode
    ) -> some View {
        Button {
            pendingBacklogMode = mode
            showsBacklogMenu = false
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(.tint)
                    .frame(width: 22)
                Text(title)
                Text("\(count)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.16), in: Capsule())
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func presentPendingBacklog() {
        guard let mode = pendingBacklogMode else { return }
        pendingBacklogMode = nil

        Task { @MainActor in
            await Task.yield()
            backlogMode = mode
        }
    }

    private func controls(snapshot: TaskCalendarSnapshot?) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Menu {
                    Picker(String(localized: "フィルター"), selection: $filter) {
                        ForEach(TaskCalendarFilter.allCases) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                } label: {
                    Image(
                        systemName: filter == .all
                            ? "line.3.horizontal.decrease"
                            : "line.3.horizontal.decrease.circle.fill"
                    )
                    .frame(width: 30, height: 30)
                }
                .accessibilityLabel(String(localized: "フィルター"))
                .accessibilityValue(filter.displayName)

                Spacer(minLength: 0)

                Picker(String(localized: "表示範囲"), selection: $range) {
                    ForEach(TaskCalendarRange.allCases) { value in
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

            if range == .oneDay {
                IOSWeekDateStrip(
                    selectedDate: $selectedDate,
                    snapshot: snapshot,
                    filter: filter,
                    searchQuery: taskSearchQuery
                )
            } else if range == .sevenDays {
                IOSWeekCardStrip(
                    selectedDate: $selectedDate,
                    snapshot: snapshot,
                    filter: filter,
                    searchQuery: taskSearchQuery
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func taskContent(snapshot: TaskCalendarSnapshot) -> some View {
        switch range {
        case .oneDay:
            groupedList(
                for: selectedDate,
                todos: todos(on: selectedDate, in: snapshot),
                snapshot: snapshot
            )
        case .sevenDays:
            weekList(anchorDate: selectedDate, snapshot: snapshot)
        case .month:
            ScrollView {
                VStack(spacing: 14) {
                    IOSTaskMonthCalendar(
                        selectedDate: $selectedDate,
                        snapshot: snapshot,
                        filter: filter,
                        searchQuery: taskSearchQuery
                    )

                    IOSTaskDaySection(
                        date: selectedDate,
                        todos: todos(on: selectedDate, in: snapshot),
                        revealsInitialRows: revealsInitialRows,
                        onEditTodo: { editorMode = .edit($0) }
                    )
                }
                .padding(12)
            }
        }
    }

    private func weekList(anchorDate: Date, snapshot: TaskCalendarSnapshot) -> some View {
        let dates = calendarBuilder
            .dates(for: .sevenDays, anchoredAt: anchorDate)
            .compactMap { date -> (Date, [Todo])? in
                let tasks = todos(on: date, in: snapshot)
                return tasks.isEmpty ? nil : (date, tasks)
            }

        return ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(Array(dates.enumerated()), id: \.element.0) { index, entry in
                    IOSTaskDaySection(
                        date: entry.0,
                        todos: entry.1,
                        firstRowIndex: index == 0 ? 0 : 5,
                        revealsInitialRows: revealsInitialRows,
                        onEditTodo: { editorMode = .edit($0) }
                    )
                }

                if dates.isEmpty {
                    ContentUnavailableView(
                        String(localized: "今日の項目はありません"),
                        systemImage: "checkmark.circle"
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                }
            }
            .padding(12)
        }
    }

    private func groupedList(
        for date: Date,
        todos: [Todo],
        snapshot: TaskCalendarSnapshot
    ) -> some View {
        let overdueTodos = visibleOverdueTodos(on: date, in: snapshot)

        return ScrollView {
            LazyVStack(spacing: 14) {
                IOSTaskOverdueCard(
                    todos: overdueTodos,
                    revealsInitialRows: revealsInitialRows,
                    onMoveToToday: moveTodosToToday,
                    onEditTodo: { editorMode = .edit($0) }
                )
                IOSTaskDaySection(
                    date: date,
                    todos: todos,
                    suppressesEmptyState: !overdueTodos.isEmpty,
                    firstRowIndex: overdueTodos.count,
                    revealsInitialRows: revealsInitialRows,
                    onEditTodo: { editorMode = .edit($0) }
                )
            }
            .padding(12)
        }
    }

    private func todos(on date: Date, in snapshot: TaskCalendarSnapshot) -> [Todo] {
        snapshot.todos(on: date)
            .filter(filter.includes)
            .filter(matchesSearch)
            .sorted(by: taskSort)
    }

    private func visibleOverdueTodos(
        on date: Date,
        in snapshot: TaskCalendarSnapshot
    ) -> [Todo] {
        let today = dayBoundary.day(containing: .now, calendar: calendar)
        guard range == .oneDay,
              calendar.isDate(date, inSameDayAs: today) else {
            return []
        }
        return snapshot.backlog.overdue
            .filter(filter.includes)
            .filter(matchesSearch)
            .sorted(by: taskSort)
    }

    private func matchesSearch(_ todo: Todo) -> Bool {
        taskSearchQuery.matchesTask(todo)
    }

    private func moveTodosToToday(_ candidates: [Todo]) {
        let today = dayBoundary.day(containing: .now, calendar: calendar)
        let movable = candidates.filter { todo in
            if case .success = rescheduleService.validate(todo, movingTo: today, among: todos) {
                return true
            }
            return false
        }
        guard !movable.isEmpty else { return }

        let firstSortIndex = (todos.map(\.sortIndex).min() ?? 0) - movable.count
        for (offset, todo) in movable.enumerated() {
            todo.reschedule(to: today)
            todo.setSortIndex(firstSortIndex + offset)
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            backlogMoveError = String(localized: "タスクを今日へ移動できませんでした。")
        }
    }

    private var requiredTodoMaterializationID: IOSRequiredTodoMaterializationID {
        IOSRequiredTodoMaterializationID(
            isVisible: isVisible,
            hasRecords: records != nil,
            rangeRawValue: range.rawValue,
            visibleDates: visibleDates.map { calendar.startOfDay(for: $0) },
            habitRevisions: activeAreas
                .filter { $0.type == .habit }
                .map {
                    IOSHabitMaterializationRevision(
                        id: $0.id,
                        updatedAt: $0.updatedAt,
                        isArchived: $0.isArchived
                    )
                },
            projectRevisions: projects.map {
                IOSProjectMaterializationRevision(
                    id: $0.id, updatedAt: $0.updatedAt, completedAt: $0.completedAt,
                    areaUpdatedAt: $0.area?.updatedAt, areaArchivedAt: $0.area?.archivedAt
                )
            }.sorted { $0.id.uuidString < $1.id.uuidString },
            calendarDayRevision: calendarDayRevision
        )
    }

    private func backlogCount(in snapshot: TaskCalendarSnapshot?) -> Int {
        guard let snapshot else { return 0 }
        return snapshot.backlog.overdue.count + snapshot.backlog.unscheduled.count
    }

    private func ensureRequiredTodos(
        now: Date = .now,
        reconcilesDuplicates: Bool
    ) {
        if DefaultAreas.existingTaskInbox(in: areas) == nil {
            modelContext.insert(DefaultAreas.makeTaskInbox())
        }

        let today = dayBoundary.day(containing: now, calendar: calendar)
        let dates = visibleDates
            .filter { $0 >= today }
            .filter { range != .month || calendarBuilder.isDate($0, inMonthContaining: selectedDate) }
            .sorted()

        do {
            _ = try HabitTodoMaterializer(
                calendar: calendar,
                dayBoundary: dayBoundary
            ).materialize(
                areas: activeAreas,
                dates: dates,
                modelContext: modelContext,
                now: now,
                knownTodos: todos,
                reconcilesDuplicates: reconcilesDuplicates
            )
        } catch {
            modelContext.rollback()
            PersistenceIssueCenter.shared.report(error, operation: .habitMaterialization)
        }
    }

    private func alignInitialSelectionWithCurrentAppDay(now: Date = .now) {
        let calendarToday = calendar.startOfDay(for: now)
        guard calendar.isDate(selectedDate, inSameDayAs: calendarToday) else { return }
        selectedDate = dayBoundary.day(containing: now, calendar: calendar)
    }

    private func taskSort(_ lhs: Todo, _ rhs: Todo) -> Bool {
        if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
        if lhs.priority != rhs.priority { return priorityRank(lhs.priority) < priorityRank(rhs.priority) }
        return lhs.sortIndex < rhs.sortIndex
    }

    private func priorityRank(_ priority: TodoPriority) -> Int {
        switch priority {
        case .high: 0
        case .medium: 1
        case .low: 2
        }
    }
}

private struct IOSRequiredTodoMaterializationID: Hashable {
    let isVisible: Bool
    let hasRecords: Bool
    let rangeRawValue: String
    let visibleDates: [Date]
    let habitRevisions: [IOSHabitMaterializationRevision]
    let projectRevisions: [IOSProjectMaterializationRevision]
    let calendarDayRevision: Int
}

private struct IOSHabitMaterializationRevision: Hashable {
    let id: UUID
    let updatedAt: Date
    let isArchived: Bool
}

private struct IOSProjectMaterializationRevision: Hashable {
    let id: UUID
    let updatedAt: Date
    let completedAt: Date?
    let areaUpdatedAt: Date?
    let areaArchivedAt: Date?
}
