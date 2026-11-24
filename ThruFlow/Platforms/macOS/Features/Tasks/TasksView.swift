//
//  TasksView.swift
//  ThruFlow
//
//

import SwiftData
import SwiftUI

struct TasksView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    let initialFilter: TaskCalendarFilter
    var filterRevision = 0
    var isVisible = true
    private let onFirstRows: () -> Bool

    @State private var data: MacTasksData?
    @State private var startsDataSource = false
    @State private var rowRevealDeadline: ContinuousClock.Instant?
    @State private var loadFailed = false

    @State private var editingTodo: Todo?
    @State private var newTodoTitle = ""
    @State private var newTodoAreaID: UUID?
    @State private var newTodoProject: Project?
    @State private var newTodoVolume: QuickTodoVolume = .unspecified
    @State private var newTodoPriority: TodoPriority = .medium
    @State private var newTodoIsRoomIfPossible = false
    @State private var newTodoDateOption: QuickTodoDate = .today
    @State private var newTodoTimeMinutes: Int?
    @State private var newTodoReminderEnabled = false
    @State private var newTodoHashtags: [String] = []
    @State private var newTodoError: String?
    @State private var anchorDate = Calendar.current.startOfDay(for: .now)
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var calendarRange: TaskCalendarRange = .oneDay
    @State private var taskFilter: TaskCalendarFilter
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var moveError: String?
    @State private var backlogInspectorMode: MacTaskBacklogMode?
    @State private var hasPerformedInitialMaterialization = false
    @State private var calendarDayRevision = 0
    @AppStorage("today.groupOrder") private var groupOrderRaw = TasksTodoGroup.defaultOrderRaw

    init(
        initialFilter: TaskCalendarFilter = .all,
        filterRevision: Int = 0,
        isVisible: Bool = true,
        onFirstRows: @escaping () -> Bool = { true }
    ) {
        self.initialFilter = initialFilter
        self.filterRevision = filterRevision
        self.isVisible = isVisible
        self.onFirstRows = onFirstRows
        _taskFilter = State(initialValue: initialFilter)
    }

    private var areas: [Area] { data?.areas ?? [] }
    private var todos: [Todo] { data?.todos ?? [] }
    private var projects: [Project] { data?.projects ?? [] }

    private var revealsRows: Bool {
        guard isVisible, let rowRevealDeadline else { return false }
        return ContinuousClock.now < rowRevealDeadline
    }

    private var calendarBuilder: TaskCalendarBuilder { TaskCalendarBuilder(calendar: calendar) }
    private var rescheduleService: TaskRescheduleService {
        TaskRescheduleService(calendar: calendar, dayBoundary: dayBoundary)
    }
    private var searchBuilder: DatabaseSearchBuilder { DatabaseSearchBuilder(calendar: calendar) }
    private let progress = TodoProgressCalculator()

    private var isSearching: Bool {
        DatabaseSearchQuery(text: searchText).isActive
    }

    private var searchSections: [DatabaseTaskSearchSection] {
        searchBuilder.taskSections(
            query: searchText,
            todos: todos,
            filter: taskFilter
        )
    }

    private var activeAreas: [Area] {
        areas.filter { !$0.isArchived }
    }

    private var visibleAreas: [Area] {
        activeAreas.filter { !DefaultAreas.isTaskInbox($0) }
    }

    private var groupOrder: [AreaType] {
        TasksTodoGroup.order(from: groupOrderRaw)
    }

    private var visibleDates: [Date] {
        calendarBuilder.dates(for: calendarRange, anchoredAt: anchorDate)
    }

    private var taskSearchQuery: DatabaseSearchQuery {
        DatabaseSearchQuery(text: searchText)
    }

    var body: some View {
        let snapshot = data?.snapshot
        VStack(spacing: 0) {
            if isSearching {
                if snapshot != nil {
                    TasksSearchResults(
                        searchText: searchText,
                        searchSections: searchSections,
                        row: draggableTodoRow
                    )
                } else {
                    loadStatus
                }
            } else {
                tasksWorkspace(snapshot: snapshot)
            }
        }
        .toolbar {
            if isVisible {
                ToolbarItem(placement: .principal) {
                    taskFilterPicker
                        .fixedSize(horizontal: true, vertical: false)
                }

                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 10) {
                        backlogToolbarButton(
                            String(localized: "やり残し"),
                            count: snapshot?.backlog.overdue.count,
                            mode: .overdue
                        )

                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 1, height: 16)

                        backlogToolbarButton(
                            String(localized: "日付なし"),
                            count: snapshot?.backlog.unscheduled.count,
                            mode: .unscheduled
                        )
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .fixedSize(horizontal: true, vertical: true)
                }

                ToolbarItem(placement: .primaryAction) {
                    MacToolbarSearchControl(
                        text: $searchText,
                        isPresented: $isSearchPresented
                    )
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            MessengerTodoComposer(
                title: $newTodoTitle,
                selectedAreaID: $newTodoAreaID,
                selectedProject: $newTodoProject,
                volume: $newTodoVolume,
                priority: $newTodoPriority,
                isRoomIfPossible: $newTodoIsRoomIfPossible,
                dateOption: $newTodoDateOption,
                timeMinutes: $newTodoTimeMinutes,
                reminderEnabled: $newTodoReminderEnabled,
                hashtags: $newTodoHashtags,
                areas: visibleAreas,
                validationMessage: newTodoError,
                suggestionTodos: todos,
                allowsSubmission: snapshot != nil,
                onSubmit: createInlineTodo
            )
        }
        .sheet(item: $editingTodo) { todo in
            TodoFormView(mode: .edit(todo))
        }
        .inspector(isPresented: backlogInspectorIsPresented) {
            Group {
                if let snapshot {
                    TasksBacklogInspector(
                        backlogInspectorTitle: backlogInspectorTitle,
                        backlogInspectorSystemImage: backlogInspectorSystemImage,
                        inspectorTodos: backlogInspectorTodos(in: snapshot),
                        onMoveAllToToday: moveTodosToToday,
                        onMoveToToday: { _ = moveTodo($0, to: .now) },
                        onClose: { backlogInspectorMode = nil },
                        row: draggableTodoRow
                    )
                } else {
                    loadStatus
                }
            }
            .inspectorColumnWidth(min: 300, ideal: 340, max: 420)
        }
        .alert(String(localized: "移動できません"), isPresented: moveErrorIsPresented) {
            Button(String(localized: "OK"), role: .cancel) {
                moveError = nil
            }
        } message: {
            Text(moveError ?? "")
        }
        .background {
            if isVisible && startsDataSource {
                MacTasksDataSource(dayRevision: calendarDayRevision) { result in
                    switch result {
                    case .success(let newData):
                        if data == nil, isVisible, !newData.snapshot.activeTodos.isEmpty, onFirstRows() {
                            rowRevealDeadline = ContinuousClock.now.advanced(by: .milliseconds(350))
                        }
                        data = newData
                        loadFailed = false
                    case .failure(let error):
                        loadFailed = true
                        PersistenceIssueCenter.shared.log(error, operation: .dataLoad)
                    }
                }
            }
        }
        .onChange(of: isVisible) { _, visible in
            if !visible {
                startsDataSource = false
                rowRevealDeadline = nil
            }
        }
        .task(id: isVisible) {
            guard isVisible else { return }
            if !hasPerformedInitialMaterialization {
                alignInitialSelectionWithCurrentAppDay()
                selectComposerDate(selectedDate)
            }
            await Task.yield()
            guard !Task.isCancelled else { return }
            startsDataSource = true
        }
        .task(id: isVisible && snapshot != nil) {
            guard isVisible, snapshot != nil, !hasPerformedInitialMaterialization else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            ensureRequiredTodosForVisibleDates(reconcilesDuplicates: true)
            hasPerformedInitialMaterialization = true
        }
        .task(id: isVisible ? requiredTodoMaterializationID : nil) {
            guard isVisible, hasPerformedInitialMaterialization else { return }
            do {
                try await Task.sleep(for: .milliseconds(180))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            ensureRequiredTodosForVisibleDates(reconcilesDuplicates: false)
        }
        .onChange(of: filterRevision) { _, _ in
            taskFilter = initialFilter
        }
        .onChange(of: calendarRange) { _, _ in
            rowRevealDeadline = nil
            anchorDate = selectedDate
        }
        .onChange(of: selectedDate) { _, newDate in
            rowRevealDeadline = nil
            selectComposerDate(newDate)
        }
        .onChange(of: taskFilter) { _, _ in rowRevealDeadline = nil }
        .onChange(of: isSearching) { _, _ in rowRevealDeadline = nil }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            if isVisible { calendarDayRevision += 1 }
        }
        .onTapGesture {
#if os(macOS)
            MacOSFocusController.dismissCurrentEditor()
#endif
        }
    }

    @ViewBuilder
    private var loadStatus: some View {
        if loadFailed {
            ContentUnavailableView(
                String(localized: "データを読み込めませんでした。"),
                systemImage: "exclamationmark.circle"
            )
        } else {
            FeatureLoadingIndicator()
        }
    }

    private var taskFilterPicker: some View {
        Picker(String(localized: "フィルター"), selection: $taskFilter) {
            ForEach(TaskCalendarFilter.allCases) { option in
                Text(option.displayName).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel(String(localized: "フィルター"))
        .accessibilityValue(taskFilter.displayName)
    }

    private func tasksWorkspace(snapshot: TaskCalendarSnapshot?) -> some View {
        TasksCalendarWorkspace(
            title: taskPeriodTitle,
            snapshot: snapshot,
            taskFilter: taskFilter,
            calendarRange: $calendarRange,
            selectedDate: selectedDateBinding,
            onPrevious: { moveTaskPeriod(by: -1) },
            onToday: moveToToday,
            onNext: { moveTaskPeriod(by: 1) },
            onDropPayload: moveTaskPayload
        ) {
            if let snapshot {
                boardContent(snapshot: snapshot)
                    .productContentFade(on: calendarRange)
            } else {
                loadStatus
            }
        }
    }

    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: { selectedDate },
            set: { date in
                let day = calendar.startOfDay(for: date)
                selectedDate = day
                anchorDate = day
            }
        )
    }

    @ViewBuilder
    private func boardContent(snapshot: TaskCalendarSnapshot) -> some View {
        switch calendarRange {
        case .oneDay:
            TasksDayList(
                selectedDate: selectedDate,
                selectedTodos: selectedDateTodos(in: snapshot),
                overdueTodos: visibleOverdueTodos(in: snapshot),
                groupOrder: groupOrder,
                revealsRows: revealsRows,
                rowRevealDeadline: rowRevealDeadline,
                onMoveAllToToday: moveTodosToToday,
                onMoveTodos: moveTodos,
                onMoveGroups: moveGroups,
                row: draggableTodoRow
            )
        case .sevenDays:
            TaskMultiDayBoard(
                dates: visibleDates,
                selectedDate: selectedDate,
                snapshot: snapshot,
                filter: taskFilter,
                searchQuery: taskSearchQuery,
                columnWidth: 238,
                revealsRows: revealsRows,
                rowRevealDeadline: rowRevealDeadline,
                onSelectDate: selectDate,
                onToggle: toggleTodo,
                onEdit: { editingTodo = $0 },
                onStartFlow: startFlow,
                onDelete: deleteTodo,
                onMove: { todo, date in
                    _ = moveTodo(todo, to: date)
                }
            )
        case .month:
            TaskMonthGrid(
                anchorDate: anchorDate,
                dates: visibleDates,
                selectedDate: selectedDate,
                snapshot: snapshot,
                filter: taskFilter,
                searchQuery: taskSearchQuery,
                onSelectDate: openDay,
                onMove: moveTodo
            )
        }
    }

    private var backlogInspectorIsPresented: Binding<Bool> {
        Binding(
            get: { isVisible && backlogInspectorMode != nil },
            set: { isPresented in
                if isVisible && !isPresented {
                    backlogInspectorMode = nil
                }
            }
        )
    }

    private func backlogToolbarButton(
        _ title: String,
        count: Int?,
        mode: MacTaskBacklogMode
    ) -> some View {
        Button {
            backlogInspectorMode = mode
        } label: {
            HStack(spacing: 6) {
                Text(title)
                if let count {
                    Text("\(count)")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.16), in: Capsule())
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle((count ?? 0) == 0 ? .secondary : .primary)
        .accessibilityLabel(count.map { String(localized: "項目 \(title)、件数 \($0)") } ?? title)
    }

    private func backlogInspectorTodos(in snapshot: TaskCalendarSnapshot) -> [Todo] {
        switch backlogInspectorMode {
        case .overdue:
            snapshot.backlog.overdue.filter(matchesSearch)
        case .unscheduled:
            snapshot.backlog.unscheduled.filter(matchesSearch)
        case nil:
            []
        }
    }

    private func matchesSearch(_ todo: Todo) -> Bool {
        taskSearchQuery.matchesTask(todo)
    }

    private var backlogInspectorTitle: String {
        backlogInspectorMode == .overdue
            ? String(localized: "やり残し")
            : String(localized: "日付なし")
    }

    private var backlogInspectorSystemImage: String {
        backlogInspectorMode == .overdue ? "exclamationmark.circle" : "tray"
    }

    private var moveErrorIsPresented: Binding<Bool> {
        Binding(
            get: { moveError != nil },
            set: { isPresented in
                if !isPresented {
                    moveError = nil
                }
            }
        )
    }

    private func moveToToday() {
        let today = dayBoundary.day(containing: .now, calendar: calendar)
        anchorDate = today
        selectedDate = today
    }

    private func moveTaskPeriod(by area: Int) {
        let date = calendarBuilder.advancedDate(
            from: anchorDate,
            range: calendarRange,
            area: area
        )
        anchorDate = calendar.startOfDay(for: date)
        selectedDate = anchorDate
    }

    private var taskPeriodTitle: String {
        switch calendarRange {
        case .oneDay:
            selectedDate.formatted(.dateTime.locale(locale).year().month(.wide).day().weekday(.wide))
        case .sevenDays:
            taskWeekTitle
        case .month:
            anchorDate.formatted(.dateTime.locale(locale).year().month(.wide))
        }
    }

    private var taskWeekTitle: String {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: anchorDate) else {
            return anchorDate.formatted(.dateTime.locale(locale).year().month().day())
        }
        let end = interval.end.addingTimeInterval(-1)
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("yMd")
        return "\(formatter.string(from: interval.start)) – \(formatter.string(from: end))"
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
            moveError = String(localized: "タスクを今日へ移動できませんでした。")
        }
    }

    private func selectDate(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
    }

    private func openDay(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        selectedDate = day
        anchorDate = day
        calendarRange = .oneDay
    }

    private func selectComposerDate(_ date: Date) {
        let today = dayBoundary.day(containing: .now, calendar: calendar)
        if calendar.isDate(date, inSameDayAs: today) {
            newTodoDateOption = .today
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
                  calendar.isDate(date, inSameDayAs: tomorrow) {
            newTodoDateOption = .tomorrow
        } else {
            newTodoDateOption = .custom(calendar.startOfDay(for: date))
        }
    }

    private func toggleTodo(_ todo: Todo) {
        guard todo.setManuallyCompleted(!todo.isCompleted) else { return }
        _ = modelContext.saveReporting(.taskUpdate)
    }

    private func startFlow(_ todo: Todo) {
        activeFlowStore.configure(area: todo.area, todo: todo)
    }

    private func deleteTodo(_ todo: Todo) {
        todo.softDelete()
        _ = modelContext.saveReporting(.taskUpdate)
    }

    @discardableResult
    private func moveTodo(_ todo: Todo, to date: Date) -> Bool {
        switch rescheduleService.validate(todo, movingTo: date, among: todos) {
        case .success:
            todo.reschedule(to: calendar.startOfDay(for: date))
            todo.setSortIndex((todos.map(\.sortIndex).min() ?? 0) - 1)
            do {
                try modelContext.save()
                return true
            } catch {
                modelContext.rollback()
                moveError = String(localized: "タスクを移動できませんでした。")
                return false
            }
        case .failure(let failure):
            moveError = failure.message
            return false
        }
    }

    private func moveTaskPayload(_ payload: String, to date: Date) -> Bool {
        guard payload.hasPrefix("task:"),
              let id = UUID(uuidString: String(payload.dropFirst("task:".count))),
              let todo = todos.first(where: { $0.id == id }) else { return false }
        return moveTodo(todo, to: date)
    }

    @ViewBuilder
    private func draggableTodoRow(_ todo: Todo) -> some View {
        if canDrag(todo) {
            todoRow(todo).draggable("task:\(todo.id.uuidString)")
        } else {
            todoRow(todo)
        }
    }

    private func canDrag(_ todo: Todo) -> Bool {
        guard !todo.isCompleted else { return false }
        guard todo.taskType == .habit else { return true }
        return HabitDefinition(todo: todo)?.goalSchedule == .weeklyCount
    }

    private func todoRow(_ todo: Todo) -> some View {
        TodoRow(
            todo: todo,
            summary: progress.summary(
                measurement: todo.measurement,
                plannedAmount: todo.plannedAmount,
                actualProgress: todo.actualProgress,
                focusDurationSeconds: todo.focusDurationSeconds
            )
        )
        .contextMenu {
            MacTaskContextMenu(todo: todo, onEdit: { editingTodo = todo }, onError: { moveError = $0 })
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(String(localized: "削除"), systemImage: "trash", role: .destructive) {
                todo.softDelete()
            }
        }
    }

    private func moveGroups(
        from source: IndexSet,
        to destination: Int,
        selectedGroups: [TasksTodoGroup]
    ) {
        var visibleOrder = selectedGroups.map(\.type)
        visibleOrder.move(fromOffsets: source, toOffset: destination)

        let hiddenOrder = groupOrder.filter { type in
            !visibleOrder.contains(type)
        }

        groupOrderRaw = (visibleOrder + hiddenOrder)
            .map(\.rawValue)
            .joined(separator: ",")
    }

    private func moveTodos(
        in type: AreaType,
        from source: IndexSet,
        to destination: Int,
        selectedTodos: [Todo]
    ) {
        var reordered = selectedTodos.filter { TasksTodoGroup.type(for: $0) == type }
        reordered.move(fromOffsets: source, toOffset: destination)

        let groupedTodos = Dictionary(grouping: selectedTodos) { todo in
            TasksTodoGroup.type(for: todo)
        }
        let orderedTodos = groupOrder.flatMap { groupType -> [Todo] in
            groupType == type ? reordered : groupedTodos[groupType] ?? []
        }

        for (index, todo) in orderedTodos.enumerated() {
            todo.setSortIndex(index)
        }

        _ = modelContext.saveReporting(.taskUpdate)
    }

    private func createInlineTodo() -> Bool {
        let draft = TodoDraft(
            title: newTodoTitle,
            hashtags: newTodoHashtags,
            area: area(for: newTodoAreaID),
            project: newTodoProject,
            measurement: newTodoVolume.measurement,
            priority: newTodoPriority,
            isRoomIfPossible: newTodoPriority == .low && newTodoIsRoomIfPossible,
            plannedAmount: newTodoVolume.plannedAmount,
            scheduledDate: newTodoDateOption.resolvedDate(
                calendar: calendar,
                dayBoundary: dayBoundary
            ),
            scheduledTimeMinutes: newTodoTimeMinutes,
            reminderEnabled: newTodoReminderEnabled
        )
        do {
            let todo = try TaskEditingService().save(draft: draft, modelContext: modelContext)
            if todo.reminderEnabled { TaskReminderAuthorization.requestForUserAction() }
        } catch TaskEditingError.validation(let errors) {
            newTodoError = errors.map(\.localizedDescription).joined(separator: "\n")
            return false
        } catch {
            newTodoError = String(localized: "記録を保存できませんでした。")
            return false
        }

        newTodoTitle = ""
        newTodoHashtags = []
        newTodoTimeMinutes = nil
        newTodoReminderEnabled = false
        if newTodoPriority != .low {
            newTodoIsRoomIfPossible = false
        }
        newTodoError = nil
        return true
    }

    private func ensureRequiredTodosForVisibleDates(
        now: Date = .now,
        reconcilesDuplicates: Bool
    ) {
        let today = dayBoundary.day(containing: now, calendar: calendar)
        let dates = visibleDates
            .filter { $0 >= today }
            .filter { date in
                calendarRange != .month || calendarBuilder.isDate(date, inMonthContaining: anchorDate)
            }
            .sorted()

        guard !dates.isEmpty else { return }

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

    private func selectedDateTodos(in snapshot: TaskCalendarSnapshot) -> [Todo] {
        snapshot.todos(on: selectedDate)
            .filter(taskFilter.includes)
            .filter(taskSearchQuery.matchesTask)
            .sorted(by: TaskBoardSort.areInIncreasingOrder)
    }

    private func visibleOverdueTodos(in snapshot: TaskCalendarSnapshot) -> [Todo] {
        snapshot.backlog.overdue
            .filter(taskFilter.includes)
            .filter(taskSearchQuery.matchesTask)
    }

    private var requiredTodoMaterializationID: MacRequiredTodoMaterializationID {
        MacRequiredTodoMaterializationID(
            rangeRawValue: calendarRange.rawValue,
            visibleDates: visibleDates.map { calendar.startOfDay(for: $0) },
            habitRevisions: activeAreas
                .filter { $0.type == .habit }
                .map {
                    MacHabitMaterializationRevision(
                        id: $0.id,
                        updatedAt: $0.updatedAt,
                        isArchived: $0.isArchived
                    )
                },
            projectRevisions: projects.map {
                MacProjectHabitMaterializationRevision(
                    id: $0.id, updatedAt: $0.updatedAt, completedAt: $0.completedAt,
                    areaUpdatedAt: $0.area?.updatedAt, areaArchivedAt: $0.area?.archivedAt
                )
            }.sorted { $0.id.uuidString < $1.id.uuidString },
            calendarDayRevision: calendarDayRevision
        )
    }

    private func alignInitialSelectionWithCurrentAppDay(now: Date = .now) {
        let calendarToday = calendar.startOfDay(for: now)
        guard calendar.isDate(selectedDate, inSameDayAs: calendarToday) else { return }
        let appToday = dayBoundary.day(containing: now, calendar: calendar)
        selectedDate = appToday
        anchorDate = appToday
    }

    private func area(for id: UUID?) -> Area? {
        guard let id else { return nil }
        return visibleAreas.first { $0.id == id }
    }
}

private enum MacTaskBacklogMode {
    case overdue
    case unscheduled
}

private struct MacRequiredTodoMaterializationID: Hashable {
    let rangeRawValue: String
    let visibleDates: [Date]
    let habitRevisions: [MacHabitMaterializationRevision]
    let projectRevisions: [MacProjectHabitMaterializationRevision]
    let calendarDayRevision: Int
}

private struct MacProjectHabitMaterializationRevision: Hashable {
    let id: UUID
    let updatedAt: Date
    let completedAt: Date?
    let areaUpdatedAt: Date?
    let areaArchivedAt: Date?
}

private struct MacHabitMaterializationRevision: Hashable {
    let id: UUID
    let updatedAt: Date
    let isArchived: Bool
}

#Preview {
    TasksView()
        .environmentObject(ActiveFlowStore())
        .modelContainer(for: [Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self], inMemory: true)
}
