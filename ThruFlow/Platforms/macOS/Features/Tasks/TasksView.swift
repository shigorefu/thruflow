//
//  TasksView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import SwiftData
import SwiftUI

struct TasksView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Direction.name, order: .forward) private var directions: [Direction]
    @Query(sort: \Todo.sortIndex, order: .forward) private var todos: [Todo]

    @State private var editingTodo: Todo?
    @State private var newTodoTitle = ""
    @State private var newTodoDirectionID: UUID?
    @State private var newTodoVolume: QuickTodoVolume = .unspecified
    @State private var newTodoPriority: TodoPriority = .medium
    @State private var newTodoIsRoomIfPossible = false
    @State private var newTodoDateOption: QuickTodoDate = .today
    @State private var newTodoHashtags: [String] = []
    @State private var newTodoError: String?
    @State private var anchorDate = Calendar.current.startOfDay(for: .now)
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var calendarRange: TaskCalendarRange = .oneDay
    @State private var taskFilter: TaskCalendarFilter = .all
    @State private var moveError: String?
    @State private var showsUnscheduledInspector = false
    @AppStorage("today.groupOrder") private var groupOrderRaw = TasksTodoGroup.defaultOrderRaw

    private var filter: TodayTodoFilter { TodayTodoFilter(calendar: calendar) }
    private var requiredPlanner: RequiredTodoPlanner { RequiredTodoPlanner(calendar: calendar) }
    private var calendarBuilder: TaskCalendarBuilder { TaskCalendarBuilder(calendar: calendar) }
    private var backlogBuilder: TaskBacklogBuilder { TaskBacklogBuilder(calendar: calendar) }
    private var rescheduleService: TaskRescheduleService { TaskRescheduleService(calendar: calendar) }
    private let progress = TodoProgressCalculator()
    private let validator = TodoValidator()

    private var activeDirections: [Direction] {
        directions.filter { !$0.isArchived }
    }

    private var visibleDirections: [Direction] {
        activeDirections.filter { !DefaultDirections.isTaskInbox($0) }
    }

    private var selectedDateTodos: [Todo] {
        todos.filter { filter.includes($0, on: selectedDate) && taskFilter.includes($0) }
    }

    private var selectedDateGroups: [TasksTodoGroup] {
        TasksTodoGroup.groups(for: selectedDateTodos, order: groupOrder)
    }

    private var groupOrder: [DirectionType] {
        TasksTodoGroup.order(from: groupOrderRaw)
    }

    private var visibleDates: [Date] {
        calendarBuilder.dates(for: calendarRange, anchoredAt: anchorDate)
    }

    private var backlogSnapshot: TaskBacklogSnapshot {
        backlogBuilder.build(todos: todos)
    }

    private var visibleOverdueTodos: [Todo] {
        backlogSnapshot.overdue.filter(taskFilter.includes)
    }

    var body: some View {
        VStack(spacing: 0) {
            TaskCalendarToolbar(
                range: $calendarRange,
                filter: $taskFilter,
                unscheduledCount: backlogSnapshot.unscheduled.count,
                onToday: moveToToday,
                onShowUnscheduled: { showsUnscheduledInspector = true }
            )

            Divider()

            tasksWorkspace
        }
        .navigationTitle(String(localized: "タスク"))
        .safeAreaInset(edge: .bottom) {
            MessengerTodoComposer(
                title: $newTodoTitle,
                selectedDirectionID: $newTodoDirectionID,
                volume: $newTodoVolume,
                priority: $newTodoPriority,
                isRoomIfPossible: $newTodoIsRoomIfPossible,
                dateOption: $newTodoDateOption,
                hashtags: $newTodoHashtags,
                directions: visibleDirections,
                validationMessage: newTodoError,
                onSubmit: createInlineTodo
            )
        }
        .sheet(item: $editingTodo) { todo in
            TodoFormView(mode: .edit(todo))
        }
        .inspector(isPresented: $showsUnscheduledInspector) {
            unscheduledInspector
                .inspectorColumnWidth(min: 300, ideal: 340, max: 420)
        }
        .alert(String(localized: "移動できません"), isPresented: moveErrorIsPresented) {
            Button(String(localized: "OK"), role: .cancel) {
                moveError = nil
            }
        } message: {
            Text(moveError ?? "")
        }
        .onAppear {
            selectComposerDate(selectedDate)
            ensureRequiredTodosForVisibleDates()
        }
        .onChange(of: calendarRange) { _, _ in
            anchorDate = selectedDate
            ensureRequiredTodosForVisibleDates()
        }
        .onChange(of: anchorDate) { _, _ in
            ensureRequiredTodosForVisibleDates()
        }
        .onChange(of: selectedDate) { _, newDate in
            selectComposerDate(newDate)
        }
        .onChange(of: directions.map(\.updatedAt)) { _, _ in
            ensureRequiredTodosForVisibleDates()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            ensureRequiredTodosForVisibleDates()
        }
        .onTapGesture {
#if os(macOS)
            MacOSFocusController.dismissCurrentEditor()
#endif
        }
    }

    @ViewBuilder
    private var tasksWorkspace: some View {
        if calendarRange == .oneDay {
            VStack(spacing: 0) {
                TaskDayStrip(
                    selectedDate: selectedDateBinding,
                    todos: todos.filter { !$0.isArchived && !$0.isDeleted },
                    filter: taskFilter,
                    onDropPayload: moveTaskPayload
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                Divider()

                oneDayList
            }
        } else {
            GeometryReader { geometry in
                if geometry.size.width >= 900 {
                    HStack(spacing: 0) {
                        boardContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Divider()

                        VStack(spacing: 0) {
                            taskPeriodPicker
                                .padding(16)
                            Spacer(minLength: 0)
                        }
                        .frame(width: min(390, max(310, geometry.size.width * 0.30)))
                        .background(Color.secondary.opacity(0.035))
                    }
                } else {
                    VStack(spacing: 0) {
                        taskPeriodPicker
                            .padding(12)
                        Divider()
                        boardContent
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var taskPeriodPicker: some View {
        switch calendarRange {
        case .oneDay:
            HistoryMiniCalendar(
                selectedDate: selectedDateBinding,
                indicatorSource: .tasks(taskFilter),
                onDropPayload: moveTaskPayload
            )
        case .sevenDays:
            HistoryMiniCalendar(
                selectedDate: selectedDateBinding,
                selectionMode: .week,
                indicatorSource: .tasks(taskFilter),
                onDropPayload: moveTaskPayload
            )
        case .month:
            HistoryYearMonthPicker(selectedDate: selectedDateBinding)
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
    private var boardContent: some View {
        switch calendarRange {
        case .oneDay:
            oneDayList
        case .sevenDays:
            TaskMultiDayBoard(
                dates: visibleDates,
                selectedDate: selectedDate,
                todos: todos.filter { !$0.isArchived && !$0.isDeleted },
                filter: taskFilter,
                columnWidth: 238,
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
                todos: todos.filter { !$0.isArchived && !$0.isDeleted },
                filter: taskFilter,
                onSelectDate: openDay,
                onMove: moveTodo
            )
        }
    }

    private var oneDayList: some View {
        List {
            if showsOverdueSection {
                Section {
                    ForEach(visibleOverdueTodos) { todo in
                        draggableTodoRow(todo)
                    }
                } header: {
                    TasksOverdueHeader(
                        count: visibleOverdueTodos.count,
                        onMoveAllToToday: { moveTodosToToday(visibleOverdueTodos) }
                    )
                }
                .listSectionSeparator(.hidden)
            }

            if selectedDateGroups.isEmpty {
                if !showsOverdueSection {
                    EmptyRow(text: String(localized: "この日のタスクはありません。"))
                        .listRowSeparator(.hidden)
                }
            } else {
                ForEach(selectedDateGroups) { group in
                    Section {
                        ForEach(group.todos) { todo in
                            draggableTodoRow(todo)
                        }
                        .onMove { source, destination in
                            moveTodos(in: group.type, from: source, to: destination)
                        }
                    } header: {
                        TasksSectionHeader(group: group)
                    }
                    .listSectionSeparator(.hidden)
                }
                .onMove(perform: moveGroups)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(.default, value: selectedDateTodos.map(\.id))
    }

    private var showsOverdueSection: Bool {
        calendar.isDateInToday(selectedDate) && !visibleOverdueTodos.isEmpty
    }

    private var unscheduledInspector: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Label(String(localized: "日付なし"), systemImage: "tray")
                    .font(.headline)

                Text("\(backlogSnapshot.unscheduled.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                if !backlogSnapshot.unscheduled.isEmpty {
                    Button(String(localized: "すべて今日へ")) {
                        moveTodosToToday(backlogSnapshot.unscheduled)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    showsUnscheduledInspector = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(String(localized: "日付なしを閉じる"))
            }
            .padding(16)

            Divider()

            if backlogSnapshot.unscheduled.isEmpty {
                ContentUnavailableView(
                    String(localized: "日付なしのタスクはありません"),
                    systemImage: "tray"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(backlogSnapshot.unscheduled) { todo in
                        unscheduledTodoRow(todo)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func unscheduledTodoRow(_ todo: Todo) -> some View {
        HStack(spacing: 8) {
            draggableTodoRow(todo)

            Button {
                _ = moveTodo(todo, to: .now)
            } label: {
                Image(systemName: "calendar.badge.plus")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(String(localized: "今日へ移動"))
            .accessibilityLabel(String(localized: "\(TodoDisplay.title(for: todo))を今日へ移動"))
        }
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
        let today = calendar.startOfDay(for: .now)
        anchorDate = today
        selectedDate = today
    }

    private func moveTodosToToday(_ candidates: [Todo]) {
        let today = calendar.startOfDay(for: .now)
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
        if calendar.isDateInToday(date) {
            newTodoDateOption = .today
        } else if calendar.isDateInTomorrow(date) {
            newTodoDateOption = .tomorrow
        } else {
            newTodoDateOption = .custom(calendar.startOfDay(for: date))
        }
    }

    private func toggleTodo(_ todo: Todo) {
        guard todo.setManuallyCompleted(!todo.isCompleted) else { return }
        try? modelContext.save()
    }

    private func startFlow(_ todo: Todo) {
        activeFlowStore.configure(direction: todo.direction, todo: todo)
    }

    private func deleteTodo(_ todo: Todo) {
        todo.softDelete()
        try? modelContext.save()
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
        guard todo.direction?.type == .habit else { return true }
        return todo.direction?.goalSchedule == .weeklyCount
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
            Button(String(localized: "編集"), systemImage: "pencil") {
                editingTodo = todo
            }

            if todo.direction?.type == .habit {
                if todo.direction?.goalSchedule == .weeklyCount {
                    weeklyHabitMoveMenu(for: todo)
                }
            } else {
                standardMoveMenu(for: todo)
            }

            Divider()

            Button(String(localized: "Flowを開始"), systemImage: "play.fill") {
                activeFlowStore.configure(direction: todo.direction, todo: todo)
            }

            Divider()

            Button(String(localized: "削除"), systemImage: "trash", role: .destructive) {
                todo.softDelete()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(String(localized: "削除"), systemImage: "trash", role: .destructive) {
                todo.softDelete()
            }
        }
    }

    @ViewBuilder
    private func standardMoveMenu(for todo: Todo) -> some View {
        Menu(String(localized: "移動")) {
            Button(String(localized: "今日")) {
                reschedule(todo, to: .now)
            }
            Button(String(localized: "明日")) {
                reschedule(todo, to: calendar.date(byAdding: .day, value: 1, to: .now))
            }
            Button(String(localized: "日付なし")) {
                reschedule(todo, to: nil)
            }
        }
    }

    @ViewBuilder
    private func weeklyHabitMoveMenu(for todo: Todo) -> some View {
        let options = requiredPlanner.weeklyRescheduleOptions(for: todo, in: todos)

        Menu(String(localized: "移動")) {
            ForEach(options, id: \.date) { option in
                Button(rescheduleLabel(for: option.date)) {
                    reschedule(todo, to: option.date)
                }
                .disabled(!option.isAllowed)
                .help(option.isAllowed ? "" : String(localized: "週間目標を達成できなくなるため移動できません"))
            }
        }
    }

    private func reschedule(_ todo: Todo, to date: Date?) {
        todo.reschedule(to: date)
        try? modelContext.save()
    }

    private func rescheduleLabel(for date: Date) -> String {
        if calendar.isDateInToday(date) {
            return String(localized: "今日")
        }
        if calendar.isDateInTomorrow(date) {
            return String(localized: "明日")
        }

        return rescheduleDateFormatter.string(from: date)
    }

    private var rescheduleDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MdE")
        return formatter
    }

    private func moveGroups(from source: IndexSet, to destination: Int) {
        var visibleOrder = selectedDateGroups.map(\.type)
        visibleOrder.move(fromOffsets: source, toOffset: destination)

        let hiddenOrder = groupOrder.filter { type in
            !visibleOrder.contains(type)
        }

        groupOrderRaw = (visibleOrder + hiddenOrder)
            .map(\.rawValue)
            .joined(separator: ",")
    }

    private func moveTodos(in type: DirectionType, from source: IndexSet, to destination: Int) {
        var reordered = selectedDateTodos.filter { TasksTodoGroup.type(for: $0) == type }
        reordered.move(fromOffsets: source, toOffset: destination)

        let groupedTodos = Dictionary(grouping: selectedDateTodos) { todo in
            TasksTodoGroup.type(for: todo)
        }
        let orderedTodos = groupOrder.flatMap { groupType -> [Todo] in
            groupType == type ? reordered : groupedTodos[groupType] ?? []
        }

        for (index, todo) in orderedTodos.enumerated() {
            todo.setSortIndex(index)
        }

        try? modelContext.save()
    }

    private func createInlineTodo() {
        let draft = TodoDraft(
            title: newTodoTitle,
            hashtags: newTodoHashtags,
            direction: direction(for: newTodoDirectionID),
            measurement: newTodoVolume.measurement,
            priority: newTodoPriority,
            isRoomIfPossible: newTodoPriority == .low && newTodoIsRoomIfPossible,
            plannedAmount: newTodoVolume.plannedAmount,
            scheduledDate: newTodoDateOption.resolvedDate
        )
        let errors = validator.validate(draft)

        guard errors.isEmpty else {
            newTodoError = errors.map(\.localizedDescription).joined(separator: "\n")
            return
        }

        let direction = resolvedDirection(for: newTodoDirectionID)
        let todo = Todo(
            title: draft.trimmedTitle,
            hashtags: draft.hashtags,
            direction: direction,
            measurement: newTodoVolume.measurement,
            priority: newTodoPriority,
            isRoomIfPossible: newTodoPriority == .low && newTodoIsRoomIfPossible,
            plannedAmount: newTodoVolume.plannedAmount,
            status: progress.status(
                measurement: newTodoVolume.measurement,
                plannedAmount: newTodoVolume.plannedAmount,
                actualProgress: 0
            ),
            scheduledDate: newTodoDateOption.resolvedDate,
            sortIndex: (todos.map(\.sortIndex).min() ?? 0) - 1
        )
        modelContext.insert(todo)
        try? modelContext.save()

        newTodoTitle = ""
        newTodoHashtags = []
        if newTodoPriority != .low {
            newTodoIsRoomIfPossible = false
        }
        newTodoError = nil
    }

    private func ensureRequiredTodosForVisibleDates(now: Date = .now) {
        let today = calendar.startOfDay(for: now)
        let dates = visibleDates
            .filter { $0 >= today }
            .filter { date in
                calendarRange != .month || calendarBuilder.isDate(date, inMonthContaining: anchorDate)
            }
            .sorted()

        guard !dates.isEmpty else { return }

        var knownTodos = todos
        var hasChanges = false
        let minimumSortIndex = todos.map(\.sortIndex).min() ?? 0

        for (dateOffset, date) in dates.enumerated() {
            let requiredDirections = activeDirections.filter { direction in
                guard requiredPlanner.shouldAppearToday(direction, on: date) else { return false }
                if direction.goalSchedule == .weeklyCount {
                    return calendar.isDate(date, inSameDayAs: today)
                }
                return true
            }

            for (directionOffset, direction) in requiredDirections.enumerated() {
                if let pendingTodo = requiredPlanner.pendingWeeklyTodoToRollForward(
                    for: direction,
                    in: knownTodos,
                    on: date
                ) {
                    pendingTodo.reschedule(to: date, now: now)
                    hasChanges = true
                    continue
                }

                guard let todo = requiredPlanner.makeRequiredTodo(
                    for: direction,
                    existingTodos: knownTodos,
                    on: date,
                    sortIndex: minimumSortIndex - (dateOffset * max(1, requiredDirections.count)) - directionOffset - 1
                ) else {
                    continue
                }

                modelContext.insert(todo)
                knownTodos.append(todo)
                hasChanges = true
            }
        }

        if hasChanges {
            try? modelContext.save()
        }
    }

    private func resolvedDirection(for id: UUID?) -> Direction {
        if let direction = direction(for: id) {
            return direction
        }

        if let taskInbox = DefaultDirections.existingTaskInbox(in: activeDirections) {
            return taskInbox
        }

        let taskInbox = DefaultDirections.makeTaskInbox()
        modelContext.insert(taskInbox)
        return taskInbox
    }

    private func direction(for id: UUID?) -> Direction? {
        guard let id else { return nil }
        return visibleDirections.first { $0.id == id }
    }
}

/// Quick-add volume selection for the composer. `checkbox` means "no target amount",
/// `blocks(n)` targets `n` focus blocks (1 Block = 25 focused minutes).
enum QuickTodoVolume: Hashable {
    case unspecified
    case checkbox
    case blocks(Int)
    case minutes(Int)

    var measurement: TodoMeasurement {
        switch self {
        case .unspecified, .checkbox:
            .checkbox
        case .blocks:
            .focusBlocks
        case .minutes:
            .minutes
        }
    }

    var plannedAmount: Int? {
        switch self {
        case .unspecified, .checkbox:
            nil
        case .blocks(let count), .minutes(let count):
            count
        }
    }

    var menuLabel: String {
        switch self {
        case .unspecified:
            String(localized: "種類")
        case .checkbox:
            String(localized: "チェックのみ")
        case .blocks(let count):
            count == 1 ? String(localized: "1 Block") : String(localized: "\(count) Blocks")
        case .minutes(let count):
            String(localized: "\(count)分")
        }
    }

    var chipLabel: String {
        switch self {
        case .unspecified:
            String(localized: "種類")
        case .checkbox:
            String(localized: "チェック")
        case .blocks(let count):
            count == 1 ? String(localized: "1 Block") : String(localized: "\(count) Blocks")
        case .minutes(let count):
            String(localized: "\(count)分")
        }
    }
}

/// Quick-add date selection for the composer.
enum QuickTodoDate: Hashable {
    case today
    case tomorrow
    case none
    case custom(Date)

    var resolvedDate: Date? {
        switch self {
        case .today:
            return .now
        case .tomorrow:
            return Calendar.current.date(byAdding: .day, value: 1, to: .now)
        case .none:
            return nil
        case .custom(let date):
            return date
        }
    }

    var chipLabel: String {
        switch self {
        case .today:
            String(localized: "今日")
        case .tomorrow:
            String(localized: "明日")
        case .none:
            String(localized: "日付なし")
        case .custom(let date):
            Self.formatter.string(from: date)
        }
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()
}

/// Compact, chip-based quick-add composer pinned to the bottom of Tasks.
struct MessengerTodoComposer: View {
    @Binding var title: String
    @Binding var selectedDirectionID: UUID?
    @Binding var volume: QuickTodoVolume
    @Binding var priority: TodoPriority
    @Binding var isRoomIfPossible: Bool
    @Binding var dateOption: QuickTodoDate
    @Binding var hashtags: [String]

    let directions: [Direction]
    let validationMessage: String?
    var allowsDateSelection = true
    var showsOuterBackground = true
    var allowsQuickInputLegend = true
    var onCancel: (() -> Void)?
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool
    @AppStorage("settings.showsTaskQuickInputLegend") private var showsQuickInputLegend = true
    @State private var parserMessage: String?
    @State private var pendingDirectionName: String?
    @State private var isApplyingParserResult = false
    @State private var inlineTokens: [TaskComposerInlineToken] = []
    @State private var hasExplicitDirection = false
    @State private var hasExplicitPriority = false
    @State private var hasExplicitDate = false
    @State private var selectedAutocompleteSuggestionID: String?

    private let parser = TaskQuickInputParser()

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if allowsQuickInputLegend && showsQuickInputLegend && isFocused && hasComposerContent && autocompleteToken == nil {
                quickInputLegend
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let autocompleteToken {
                autocompleteSuggestions(for: autocompleteToken)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            composerSurface
        }
        .animation(.snappy(duration: 0.22), value: hasComposerContent)
        .animation(.snappy(duration: 0.18), value: autocompleteToken)
        .padding(.horizontal, showsOuterBackground ? 12 : 0)
        .padding(.vertical, showsOuterBackground ? 8 : 0)
        .background {
            if showsOuterBackground {
                Rectangle().fill(.bar)
            }
        }
        .sheet(isPresented: pendingDirectionSheetBinding) {
            DirectionFormView(
                mode: .create,
                initialName: pendingDirectionName
            ) { direction in
                selectedDirectionID = direction.id
                hasExplicitDirection = true
                replaceInlineToken(.direction(direction.id))
                removeDirectionToken(named: direction.name)
                pendingDirectionName = nil
                parserMessage = nil
            }
        }
        .onChange(of: volume) { _, newValue in
            updateExistingInlineToken(
                .measurement(newValue.measurement, newValue.plannedAmount)
            )
        }
        .onChange(of: selectedDirectionID) { _, newValue in
            updateExistingInlineToken(newValue.map(TaskComposerInlineToken.direction), id: "direction")
        }
        .onChange(of: priority) { _, newValue in
            updateExistingInlineToken(.priority(newValue, isRoomIfPossible))
        }
        .onChange(of: isRoomIfPossible) { _, newValue in
            updateExistingInlineToken(.priority(priority, newValue))
        }
        .onChange(of: dateOption) { _, newValue in
            updateExistingInlineToken(.date(newValue))
        }
        .onChange(of: autocompleteToken) { _, _ in
            selectedAutocompleteSuggestionID = nil
        }
    }

    private var composerSurface: some View {
        VStack(alignment: .leading, spacing: 10) {
            inputArea

            controlBar

            if let message = parserMessage ?? validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let pendingDirectionName {
                unresolvedDirectionActions(name: pendingDirectionName)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.primary.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.primary.opacity(0.12))
        }
    }

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 9) {
            if !inlineTokens.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 5) {
                        ForEach(inlineTokens) { token in
                            Button {
                                removeInlineToken(token)
                            } label: {
                                inlineTokenView(token)
                            }
                            .buttonStyle(.plain)
                            .help(String(localized: "トークンを削除"))
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            HStack(alignment: .top, spacing: 8) {
                TextField(String(localized: "タスクを入力してください"), text: $title, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .lineLimit(2...5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .focused($isFocused)
                    .onSubmit {
                        if !activateSelectedAutocompleteSuggestion() {
                            submit()
                        }
                    }
                    .onKeyPress(.upArrow) {
                        moveAutocompleteSelection(by: -1) ? .handled : .ignored
                    }
                    .onKeyPress(.downArrow) {
                        moveAutocompleteSelection(by: 1) ? .handled : .ignored
                    }
                    .onChange(of: title) { _, newValue in
                        parseCommittedTokens(in: newValue)
                    }

                if let onCancel {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(String(localized: "閉じる"))
                    .accessibilityLabel(String(localized: "タスク作成を閉じる"))
                }

                submitButton
            }
        }
        .animation(.snappy(duration: 0.22), value: inlineTokens)
    }

    private var controlBar: some View {
        HStack(spacing: 8) {
            VolumeChip(volume: $volume)

            DirectionChip(
                selectedDirectionID: $selectedDirectionID,
                isExplicit: $hasExplicitDirection,
                directions: directions
            )
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(3)

            PriorityChip(
                priority: $priority,
                isRoomIfPossible: $isRoomIfPossible,
                isExplicit: $hasExplicitPriority
            )

            if priority == .low {
                RoomIfPossibleChip(isSelected: $isRoomIfPossible)
            }

            if allowsDateSelection {
                DateChip(dateOption: $dateOption, isExplicit: $hasExplicitDate)
            } else {
                Text(String(localized: "今日"))
                    .chipStyle(tint: .secondary)
                    .accessibilityLabel(String(localized: "日付 今日"))
            }

            ForEach(hashtags, id: \.self) { hashtag in
                Button {
                    hashtags.removeAll { $0.caseInsensitiveCompare(hashtag) == .orderedSame }
                    inlineTokens.removeAll { $0.hashtagMatches(hashtag) }
                } label: {
                    Text(verbatim: "#\(hashtag)")
                        .chipStyle(tint: .accentColor)
                }
                .buttonStyle(.plain)
                .help(String(localized: "タグを削除"))
            }

            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private func submit() {
        let result = parser.parse(title, directions: parserDirections, consumeTrailingToken: true)
        apply(result)
        if let unresolved = result.unresolvedDirection, !unresolved.isEmpty {
            pendingDirectionName = unresolved
            parserMessage = String(localized: "方向「\(unresolved)」が見つかりません")
            isCreatingDirection = true
            isFocused = true
            return
        }
        pendingDirectionName = nil
        parserMessage = nil
        onSubmit()
        clearInlineTokensAfterSubmission()
        isFocused = true
    }

    private var parserDirections: [TaskQuickInputDirection] {
        directions.map { TaskQuickInputDirection(id: $0.id, name: $0.name) }
    }

    private var pendingDirectionSheetBinding: Binding<Bool> {
        Binding(
            get: { pendingDirectionName != nil && isCreatingDirection },
            set: { newValue in
                if !newValue { isCreatingDirection = false }
            }
        )
    }

    @State private var isCreatingDirection = false

    private var hasComposerContent: Bool {
        !trimmedTitle.isEmpty || !inlineTokens.isEmpty
    }

    private var autocompleteToken: String? {
        guard isFocused else { return nil }
        return parser.trailingAutocompleteToken(in: title)
    }

    private var submitButton: some View {
        Button(action: submit) {
            Image(systemName: "arrow.up")
                .font(.system(size: 13, weight: .bold))
                .frame(width: 30, height: 30)
                .background(Color.accentColor, in: Circle())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .help(String(localized: "タスクを追加"))
        .accessibilityLabel(String(localized: "タスクを追加"))
        .disabled(trimmedTitle.isEmpty)
        .opacity(trimmedTitle.isEmpty ? 0.45 : 1)
    }

    private var quickInputLegend: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label(String(localized: "ショートカットを使えます"), systemImage: "command")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 0)
                Button {
                    showsQuickInputLegend = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .help(String(localized: "クイック入力のヒントを非表示"))
            }

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    legendItem(shortcut: "[ ]", label: String(localized: "チェック"))
                    legendItem(shortcut: "[1b]", label: String(localized: "1ブロック"))
                    legendItem(shortcut: "[25m]", label: String(localized: "25分"))
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 2),
                    alignment: .leading,
                    spacing: 6
                ) {
                    legendItem(shortcut: "@", label: String(localized: "方向"))
                    legendItem(shortcut: "!", label: String(localized: "優先度"))
                    legendItem(shortcut: "/", label: String(localized: "日付"))
                    legendItem(shortcut: "#", label: String(localized: "タグ"))
                }
            }
        }
        .foregroundStyle(.secondary)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(Color.primary.opacity(0.1))
        }
    }

    @ViewBuilder
    private func legendItem(shortcut: String, label: String) -> some View {
        HStack(spacing: 7) {
            Text(verbatim: shortcut)
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(.primary)
                .frame(minWidth: 30, alignment: .leading)
            Text(label)
                .font(.caption)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func autocompleteSuggestions(for token: String) -> some View {
        let suggestions = autocompleteSuggestionItems(for: token)

        VStack(alignment: .leading, spacing: 2) {
            ForEach(suggestions) { suggestion in
                suggestionRow(
                    suggestion,
                    isSelected: selectedSuggestionID(in: suggestions) == suggestion.id
                )
            }
        }
        .padding(5)
        .frame(width: 320, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.12))
        }
        .shadow(color: .black.opacity(0.16), radius: 12, y: 5)
    }

    private func autocompleteSuggestionItems(for token: String) -> [TaskComposerAutocompleteSuggestion] {
        let query = String(token.dropFirst())
        switch token.first {
        case "@": return directionAutocompleteSuggestions(query: query)
        case "!": return priorityAutocompleteSuggestions(query: query)
        case "/": return dateAutocompleteSuggestions(query: query)
        case "[": return measurementAutocompleteSuggestions(query: query)
        default: return []
        }
    }

    private func directionAutocompleteSuggestions(query: String) -> [TaskComposerAutocompleteSuggestion] {
        let matches = Array(
            directions
                .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
                .prefix(6)
        )
        guard !matches.isEmpty else {
            return [
                TaskComposerAutocompleteSuggestion(
                    id: "create-direction:\(query)",
                    icon: "plus.circle",
                    title: String(localized: "新しい方向を作成"),
                    detail: query.isEmpty ? nil : query,
                    action: .createDirection(query)
                )
            ]
        }
        return matches.map { direction in
            TaskComposerAutocompleteSuggestion(
                id: "direction:\(direction.id.uuidString)",
                symbol: direction.symbolName,
                title: direction.name,
                action: .direction(direction.id)
            )
        }
    }

    private func priorityAutocompleteSuggestions(query: String) -> [TaskComposerAutocompleteSuggestion] {
        let options: [(String, String, TodoPriority, Bool)] = [
            ("high", String(localized: "高"), .high, false),
            ("medium", String(localized: "中"), .medium, false),
            ("low", String(localized: "低い"), .low, false),
            ("later", String(localized: "余裕があれば"), .low, true),
        ]
        return options
            .filter { query.isEmpty || $0.0.hasPrefix(query.lowercased()) }
            .map { option in
                TaskComposerAutocompleteSuggestion(
                    id: "priority:\(option.0)",
                    icon: "exclamationmark",
                    title: option.1,
                    detail: "!\(option.0)",
                    action: .token("!\(option.0)")
                )
            }
    }

    private func dateAutocompleteSuggestions(query: String) -> [TaskComposerAutocompleteSuggestion] {
        let options: [(String, String)] = [
            ("today", String(localized: "今日")),
            ("tomorrow", String(localized: "明日")),
            ("nodate", String(localized: "日付なし")),
        ]
        return options
            .filter { query.isEmpty || $0.0.hasPrefix(query.lowercased()) }
            .map { option in
                TaskComposerAutocompleteSuggestion(
                    id: "date:\(option.0)",
                    icon: "calendar",
                    title: option.1,
                    detail: "/\(option.0)",
                    action: .token("/\(option.0)")
                )
            }
    }

    private func measurementAutocompleteSuggestions(query: String) -> [TaskComposerAutocompleteSuggestion] {
        let options: [(String, String, String)] = [
            ("[]", "square", String(localized: "チェック")),
            ("[1b]", "circle", String(localized: "1ブロック")),
            ("[25m]", "circle.lefthalf.filled", String(localized: "25分")),
        ]
        return options
            .filter { query.isEmpty || $0.0.dropFirst().hasPrefix(query) }
            .map { option in
                TaskComposerAutocompleteSuggestion(
                    id: "measurement:\(option.0)",
                    icon: option.1,
                    title: option.2,
                    detail: option.0,
                    action: .token(option.0)
                )
            }
    }

    private func suggestionRow(
        _ suggestion: TaskComposerAutocompleteSuggestion,
        isSelected: Bool
    ) -> some View {
        Button {
            activateAutocompleteSuggestion(suggestion)
        } label: {
            HStack(spacing: 9) {
                if let icon = suggestion.icon {
                    Image(systemName: icon)
                        .frame(width: 18)
                } else if let symbol = suggestion.symbol {
                    Text(symbol)
                        .frame(width: 18)
                }
                Text(suggestion.title)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let detail = suggestion.detail {
                    Text(verbatim: detail)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 32)
            .contentShape(Rectangle())
            .background(
                isSelected ? Color.accentColor.opacity(0.18) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { isHovering in
            if isHovering {
                selectedAutocompleteSuggestionID = suggestion.id
            }
        }
    }

    private func selectedSuggestionID(in suggestions: [TaskComposerAutocompleteSuggestion]) -> String? {
        if let selectedAutocompleteSuggestionID,
           suggestions.contains(where: { $0.id == selectedAutocompleteSuggestionID }) {
            return selectedAutocompleteSuggestionID
        }
        return suggestions.first?.id
    }

    private func moveAutocompleteSelection(by offset: Int) -> Bool {
        guard let token = autocompleteToken else { return false }
        let suggestions = autocompleteSuggestionItems(for: token)
        guard !suggestions.isEmpty else { return false }
        let currentID = selectedSuggestionID(in: suggestions)
        let currentIndex = suggestions.firstIndex { $0.id == currentID } ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), suggestions.count - 1)
        selectedAutocompleteSuggestionID = suggestions[nextIndex].id
        return true
    }

    private func activateSelectedAutocompleteSuggestion() -> Bool {
        guard let token = autocompleteToken else { return false }
        let suggestions = autocompleteSuggestionItems(for: token)
        guard let selectedID = selectedSuggestionID(in: suggestions),
              let suggestion = suggestions.first(where: { $0.id == selectedID }) else {
            return false
        }
        activateAutocompleteSuggestion(suggestion)
        return true
    }

    private func activateAutocompleteSuggestion(_ suggestion: TaskComposerAutocompleteSuggestion) {
        switch suggestion.action {
        case .direction(let id):
            guard let direction = directions.first(where: { $0.id == id }) else { return }
            choose(direction)
        case .createDirection(let name):
            pendingDirectionName = name
            isCreatingDirection = true
        case .token(let token):
            completeAutocompleteToken(token)
        }
        selectedAutocompleteSuggestionID = nil
    }

    private func unresolvedDirectionActions(name: String) -> some View {
        HStack(spacing: 8) {
            Button(String(localized: "新規作成")) {
                isCreatingDirection = true
            }
            .buttonStyle(.borderedProminent)

            Button(String(localized: "その他として追加")) {
                selectedDirectionID = nil
                hasExplicitDirection = true
                removeDirectionToken(named: name)
                pendingDirectionName = nil
                parserMessage = nil
                onSubmit()
                clearInlineTokensAfterSubmission()
            }
            .buttonStyle(.bordered)
        }
    }

    private func parseCommittedTokens(in input: String) {
        guard !isApplyingParserResult else { return }
        let result = parser.parse(input, directions: parserDirections, consumeTrailingToken: false)
        apply(result)
    }

    private func apply(_ result: TaskQuickInputParseResult) {
        isApplyingParserResult = true
        defer { isApplyingParserResult = false }

        recordInlineTokens(from: result)
        if title != result.title {
            title = result.title
        }
        if let measurement = result.measurement {
            let amount = max(1, result.plannedAmount ?? 1)
            switch measurement {
            case .checkbox: volume = .checkbox
            case .focusBlocks: volume = .blocks(amount)
            case .minutes: volume = .minutes(amount)
            }
        }
        if let directionID = result.directionID {
            selectedDirectionID = directionID
            hasExplicitDirection = true
        }
        if let priority = result.priority {
            self.priority = priority
            isRoomIfPossible = result.isRoomIfPossible ?? false
            hasExplicitPriority = true
        }
        if allowsDateSelection, let date = result.date {
            dateOption = quickDate(for: date)
            hasExplicitDate = true
        }
        hashtags = TodoHashtagNormalizer.normalize(hashtags + result.hashtags)
    }

    private func choose(_ direction: Direction) {
        guard let query = parser.trailingDirectionQuery(in: title) else { return }
        removeDirectionToken(named: query)
        selectedDirectionID = direction.id
        hasExplicitDirection = true
        replaceInlineToken(.direction(direction.id))
        parserMessage = nil
    }

    private func completeAutocompleteToken(_ token: String) {
        title = parser.replacingTrailingAutocompleteToken(in: title, with: "\(token) ")
        parseCommittedTokens(in: title)
        isFocused = true
    }

    private func recordInlineTokens(from result: TaskQuickInputParseResult) {
        if let measurement = result.measurement {
            replaceInlineToken(.measurement(measurement, result.plannedAmount))
        }
        if let directionID = result.directionID {
            replaceInlineToken(.direction(directionID))
        }
        if let priority = result.priority {
            replaceInlineToken(.priority(priority, result.isRoomIfPossible ?? false))
        }
        if allowsDateSelection, let date = result.date {
            replaceInlineToken(.date(quickDate(for: date)))
        }
        for hashtag in result.hashtags {
            replaceInlineToken(.hashtag(hashtag))
        }
    }

    private func replaceInlineToken(_ token: TaskComposerInlineToken) {
        inlineTokens.removeAll { $0.id == token.id }
        inlineTokens.append(token)
    }

    private func updateExistingInlineToken(_ token: TaskComposerInlineToken?, id: String? = nil) {
        let targetID = id ?? token?.id
        guard let targetID, inlineTokens.contains(where: { $0.id == targetID }) else { return }
        inlineTokens.removeAll { $0.id == targetID }
        if let token {
            inlineTokens.append(token)
        }
    }

    private func clearInlineTokensAfterSubmission() {
        if trimmedTitle.isEmpty {
            inlineTokens = []
            hasExplicitDirection = false
            hasExplicitPriority = false
            hasExplicitDate = false
        }
    }

    private func removeInlineToken(_ token: TaskComposerInlineToken) {
        inlineTokens.removeAll { $0.id == token.id }
        switch token {
        case .measurement:
            volume = .unspecified
        case .direction:
            selectedDirectionID = nil
            hasExplicitDirection = false
        case .priority:
            priority = .medium
            isRoomIfPossible = false
            hasExplicitPriority = false
        case .date:
            dateOption = .today
            hasExplicitDate = false
        case .hashtag(let hashtag):
            hashtags.removeAll { $0.caseInsensitiveCompare(hashtag) == .orderedSame }
        }
        isFocused = true
    }

    private func quickDate(for date: TaskQuickInputDate) -> QuickTodoDate {
        switch date {
        case .scheduled(let value):
            if Calendar.current.isDateInToday(value) { return .today }
            if Calendar.current.isDateInTomorrow(value) { return .tomorrow }
            return .custom(value)
        case .noDate:
            return .none
        }
    }

    private func inlineTokenView(_ token: TaskComposerInlineToken) -> some View {
        HStack(spacing: 5) {
            inlineTokenIcon(token)
            Text(inlineTokenLabel(token))
            Image(systemName: "xmark")
                .font(.system(size: 7, weight: .bold))
                .opacity(0.7)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(inlineTokenTint(token))
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(inlineTokenTint(token).opacity(0.12), in: Capsule())
        .overlay {
            Capsule().strokeBorder(inlineTokenTint(token).opacity(0.2), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func inlineTokenIcon(_ token: TaskComposerInlineToken) -> some View {
        switch token {
        case .measurement(let measurement, _):
            Image(systemName: measurement == .checkbox ? "square" :
                (measurement == .focusBlocks ? "circle" : "circle.lefthalf.filled"))
        case .direction(let id):
            Text(directions.first(where: { $0.id == id })?.symbolName ?? "@")
        case .priority:
            Image(systemName: "exclamationmark")
        case .date:
            Image(systemName: "calendar")
        case .hashtag:
            Image(systemName: "number")
        }
    }

    private func inlineTokenLabel(_ token: TaskComposerInlineToken) -> String {
        switch token {
        case .measurement(let measurement, let amount):
            switch measurement {
            case .checkbox:
                return String(localized: "チェック")
            case .focusBlocks:
                return "\(max(1, amount ?? 1)) \(String(localized: "ブロック"))"
            case .minutes:
                return "\(max(1, amount ?? 1)) \(String(localized: "分"))"
            }
        case .direction(let id):
            return directions.first(where: { $0.id == id })?.name ?? String(localized: "方向")
        case .priority(let priority, let later):
            return later ? String(localized: "余裕があれば") : priority.displayName
        case .date(let date):
            return date.chipLabel
        case .hashtag(let hashtag):
            return "#\(hashtag)"
        }
    }

    private func inlineTokenTint(_ token: TaskComposerInlineToken) -> Color {
        if case .direction(let id) = token,
           let direction = directions.first(where: { $0.id == id }),
           !DefaultDirections.isTaskInbox(direction) {
            return Color(hex: direction.colorHex)
        }
        return .accentColor
    }

    private func removeDirectionToken(named name: String) {
        let target = "@\(name)"
        title = title
            .split(whereSeparator: \.isWhitespace)
            .filter { String($0).caseInsensitiveCompare(target) != .orderedSame }
            .joined(separator: " ")
    }
}

private struct TaskComposerAutocompleteSuggestion: Identifiable {
    enum Action {
        case direction(UUID)
        case createDirection(String)
        case token(String)
    }

    let id: String
    var icon: String?
    var symbol: String?
    let title: String
    var detail: String?
    let action: Action
}

private enum TaskComposerInlineToken: Equatable, Identifiable {
    case measurement(TodoMeasurement, Int?)
    case direction(UUID)
    case priority(TodoPriority, Bool)
    case date(QuickTodoDate)
    case hashtag(String)

    var id: String {
        switch self {
        case .measurement: "measurement"
        case .direction: "direction"
        case .priority: "priority"
        case .date: "date"
        case .hashtag(let value): "hashtag:\(value.lowercased(with: Locale(identifier: "en_US_POSIX")))"
        }
    }

    func hashtagMatches(_ value: String) -> Bool {
        guard case .hashtag(let hashtag) = self else { return false }
        return hashtag.caseInsensitiveCompare(value) == .orderedSame
    }
}

struct QuickTodoCreationPopover: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Todo.sortIndex, order: .forward) private var allTodos: [Todo]

    let directions: [Direction]
    var showsQuickInputLegend = true
    var onCreated: ((Todo) -> Void)?

    @State private var title = ""
    @State private var selectedDirectionID: UUID?
    @State private var volume: QuickTodoVolume = .unspecified
    @State private var priority: TodoPriority = .medium
    @State private var isRoomIfPossible = false
    @State private var dateOption: QuickTodoDate = .today
    @State private var hashtags: [String] = []
    @State private var validationMessage: String?

    private let validator = TodoValidator()
    private let progressCalculator = TodoProgressCalculator()

    private var activeDirections: [Direction] {
        directions.filter { !$0.isArchived }
    }

    private var selectableDirections: [Direction] {
        activeDirections.filter { !DefaultDirections.isTaskInbox($0) }
    }

    var body: some View {
        MessengerTodoComposer(
            title: $title,
            selectedDirectionID: $selectedDirectionID,
            volume: $volume,
            priority: $priority,
            isRoomIfPossible: $isRoomIfPossible,
            dateOption: $dateOption,
            hashtags: $hashtags,
            directions: selectableDirections,
            validationMessage: validationMessage,
            allowsDateSelection: false,
            showsOuterBackground: false,
            allowsQuickInputLegend: showsQuickInputLegend,
            onCancel: { dismiss() },
            onSubmit: createTodo
        )
        .frame(width: 520)
    }

    private func createTodo() {
        let selectedDirection = selectedDirectionID.flatMap { id in
            selectableDirections.first { $0.id == id }
        }
        let draft = TodoDraft(
            title: title,
            hashtags: hashtags,
            direction: selectedDirection,
            measurement: volume.measurement,
            priority: priority,
            isRoomIfPossible: priority == .low && isRoomIfPossible,
            plannedAmount: volume.plannedAmount,
            scheduledDate: .now
        )
        let errors = validator.validate(draft)

        guard errors.isEmpty else {
            validationMessage = errors.map(\.localizedDescription).joined(separator: "\n")
            return
        }

        let direction = selectedDirection ?? resolvedOtherDirection()
        let todo = Todo(
            title: draft.trimmedTitle,
            hashtags: draft.hashtags,
            direction: direction,
            measurement: volume.measurement,
            priority: priority,
            isRoomIfPossible: priority == .low && isRoomIfPossible,
            plannedAmount: volume.plannedAmount,
            status: progressCalculator.status(
                measurement: volume.measurement,
                plannedAmount: volume.plannedAmount,
                actualProgress: 0
            ),
            scheduledDate: .now,
            sortIndex: (allTodos.map(\.sortIndex).min() ?? 0) - 1
        )
        modelContext.insert(todo)
        try? modelContext.save()
        onCreated?(todo)
        dismiss()
    }

    private func resolvedOtherDirection() -> Direction {
        if let existing = DefaultDirections.existingTaskInbox(in: activeDirections) {
            return existing
        }

        let direction = DefaultDirections.makeTaskInbox()
        modelContext.insert(direction)
        return direction
    }
}

private struct PriorityChip: View {
    @Binding var priority: TodoPriority
    @Binding var isRoomIfPossible: Bool
    @Binding var isExplicit: Bool

    var body: some View {
        Menu {
            ForEach(TodoPriority.allCases) { option in
                Button {
                    priority = option
                    isExplicit = true
                    if option != .low {
                        isRoomIfPossible = false
                    }
                } label: {
                    menuRow(text: option.displayName, isSelected: priority == option)
                }
            }

            if priority == .low {
                Divider()

                Button {
                    isRoomIfPossible.toggle()
                    isExplicit = true
                } label: {
                    menuRow(text: String(localized: "余裕があれば"), isSelected: isRoomIfPossible)
                }
            }
        } label: {
            Text(labelText)
                .chipStyle(tint: tint)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel(String(localized: "優先度を選択"))
    }

    private var labelText: String {
        isExplicit ? priority.displayName : String(localized: "優先度")
    }

    private var tint: Color {
        switch priority {
        case .high:
            .red
        case .medium:
            .secondary
        case .low:
            .green
        }
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

private struct RoomIfPossibleChip: View {
    @Binding var isSelected: Bool

    var body: some View {
        Button {
            isSelected.toggle()
        } label: {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.green, lineWidth: 1.4)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isSelected ? Color.green : Color.clear)
                    )
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 13, height: 13)

                Text(String(localized: "余裕があれば"))
            }
            .chipStyle(tint: .green)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "余裕があれば"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct DirectionChip: View {
    @Binding var selectedDirectionID: UUID?
    @Binding var isExplicit: Bool

    let directions: [Direction]

    private var selectedDirection: Direction? {
        guard let selectedDirectionID else { return nil }
        return directions.first { $0.id == selectedDirectionID }
    }

    private var labelText: String {
        guard isExplicit else {
            return String(localized: "方向")
        }
        guard let selectedDirection else {
            return String(localized: "その他")
        }

        return "\(selectedDirection.symbolName) \(selectedDirection.name)"
    }

    var body: some View {
        Menu {
            ForEach(directions) { direction in
                Button {
                    selectedDirectionID = direction.id
                    isExplicit = true
                } label: {
                    menuRow(
                        text: "\(direction.symbolName) \(direction.name)",
                        isSelected: selectedDirectionID == direction.id
                    )
                }
            }

            if !directions.isEmpty { Divider() }

            Button {
                selectedDirectionID = nil
                isExplicit = true
            } label: {
                menuRow(text: String(localized: "その他"), isSelected: selectedDirectionID == nil)
            }
        } label: {
            Text(labelText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .chipStyle(tint: chipColor)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel(String(localized: "方向を選択"))
    }

    @ViewBuilder
    private func menuRow(text: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(text, systemImage: "checkmark")
        } else {
            Text(text)
        }
    }

    private var chipColor: Color {
        guard let selectedDirection, !DefaultDirections.isTaskInbox(selectedDirection) else {
            return .secondary
        }
        return Color(hex: selectedDirection.colorHex)
    }
}

private struct VolumeChip: View {
    @Binding var volume: QuickTodoVolume

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: typeIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 13, height: 16)
                .contentTransition(.symbolEffect(.replace))

            if volume.measurement == .checkbox {
                Text(typeLabel)
                    .foregroundStyle(volume == .unspecified ? .secondary : .primary)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            } else {
                TextField("1", value: amountBinding, format: .number)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .frame(width: 25)

                Text(volume.measurement == .focusBlocks ? String(localized: "ブロック") : String(localized: "分"))
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }

            Menu {
                Button { volume = .checkbox } label: {
                    menuRow(String(localized: "チェック"), selected: volume.measurement == .checkbox && volume != .unspecified)
                }
                Button { volume = .blocks(max(1, volume.plannedAmount ?? 1)) } label: {
                    menuRow(String(localized: "ブロック"), selected: volume.measurement == .focusBlocks)
                }
                Button { volume = .minutes(max(1, volume.plannedAmount ?? 25)) } label: {
                    menuRow(String(localized: "分"), selected: volume.measurement == .minutes)
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 20)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
        .font(.caption.weight(.medium))
        .padding(.leading, 9)
        .padding(.trailing, 5)
        .frame(height: 30)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
        }
        .animation(.snappy(duration: 0.22), value: volume.measurement)
        .accessibilityLabel(String(localized: "タスクの分量を選択"))
    }

    private var typeIcon: String {
        switch volume {
        case .unspecified: "square.dashed"
        case .checkbox: "checkmark.square"
        case .blocks: "circle"
        case .minutes: "circle.lefthalf.filled"
        }
    }

    private var iconColor: Color {
        volume == .unspecified ? .secondary : .accentColor
    }

    private var typeLabel: String {
        switch volume {
        case .unspecified: String(localized: "種類")
        case .checkbox: String(localized: "チェック")
        case .blocks: String(localized: "ブロック")
        case .minutes: String(localized: "分")
        }
    }

    private var amountBinding: Binding<Int> {
        Binding(
            get: { max(1, volume.plannedAmount ?? 1) },
            set: { value in
                let amount = max(1, value)
                volume = volume.measurement == .focusBlocks ? .blocks(amount) : .minutes(amount)
            }
        )
    }

    @ViewBuilder
    private func menuRow(_ text: String, selected: Bool) -> some View {
        if selected { Label(text, systemImage: "checkmark") } else { Text(text) }
    }
}

private struct DateChip: View {
    @Binding var dateOption: QuickTodoDate
    @Binding var isExplicit: Bool

    @State private var showingCustomPicker = false
    @State private var customDate = Date.now

    var body: some View {
        Menu {
            Button {
                dateOption = .today
                isExplicit = true
            } label: {
                menuRow(text: String(localized: "今日"), isSelected: dateOption == .today)
            }

            Button {
                dateOption = .tomorrow
                isExplicit = true
            } label: {
                menuRow(text: String(localized: "明日"), isSelected: dateOption == .tomorrow)
            }

            Button {
                dateOption = .none
                isExplicit = true
            } label: {
                menuRow(text: String(localized: "日付なし"), isSelected: dateOption == .none)
            }

            Divider()

            Button(String(localized: "他の日付...")) {
                customDate = dateOption.resolvedDate ?? .now
                showingCustomPicker = true
            }
        } label: {
            Text(isExplicit ? dateOption.chipLabel : String(localized: "日付"))
                .chipStyle(tint: .secondary)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel(String(localized: "日付を選択"))
        .popover(isPresented: $showingCustomPicker) {
            VStack(spacing: 12) {
                DatePicker(String(localized: "日付"), selection: $customDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()

                Button(String(localized: "設定")) {
                    dateOption = .custom(customDate)
                    isExplicit = true
                    showingCustomPicker = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(minWidth: 280)
        }
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

private extension View {
    func chipStyle(tint: Color) -> some View {
        self
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.16))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }
}

private struct TasksTodoGroup: Identifiable {
    let type: DirectionType
    let todos: [Todo]

    var id: String { type.rawValue }

    var title: String {
        switch type {
        case .habit:
            String(localized: "習慣")
        case .neutral:
            String(localized: "通常")
        case .nice:
            String(localized: "ナイス")
        }
    }

    var tint: Color {
        switch type {
        case .habit:
            .red
        case .neutral:
            .blue
        case .nice:
            .green
        }
    }

    static let defaultOrderRaw = "habit,neutral,nice"

    static func order(from rawValue: String) -> [DirectionType] {
        let parsed = rawValue
            .split(separator: ",")
            .compactMap { DirectionType.normalized(rawValue: String($0)) }
        let missing = DirectionType.allCases.filter { !parsed.contains($0) }
        return parsed.isEmpty ? [.habit, .neutral, .nice] : parsed + missing
    }

    static func groups(for todos: [Todo], order: [DirectionType]) -> [TasksTodoGroup] {
        order.compactMap { type in
            let items = todos
                .filter { Self.type(for: $0) == type }
                .sorted(by: todoSort)
            guard !items.isEmpty else { return nil }
            return TasksTodoGroup(type: type, todos: items)
        }
    }

    static func type(for todo: Todo) -> DirectionType {
        todo.direction?.type ?? .neutral
    }

    nonisolated private static func todoSort(_ lhs: Todo, _ rhs: Todo) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted
        }

        if lhs.sortIndex != rhs.sortIndex {
            return lhs.sortIndex < rhs.sortIndex
        }

        return lhs.createdAt < rhs.createdAt
    }
}

private struct TasksSectionHeader: View {
    let group: TasksTodoGroup

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(group.tint)
                .frame(width: 7, height: 7)

            Text(group.title)
                .font(.caption.weight(.semibold))

            Text("\(group.todos.count)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
        .textCase(nil)
    }
}

private struct TasksOverdueHeader: View {
    let count: Int
    let onMoveAllToToday: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.red)
                .frame(width: 7, height: 7)

            Text(String(localized: "期限切れ"))
                .font(.caption.weight(.semibold))

            Text("\(count)")
                .font(.caption2.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12), in: Capsule())

            Spacer(minLength: 0)

            Button(String(localized: "すべて今日へ"), action: onMoveAllToToday)
                .font(.caption)
                .buttonStyle(.borderless)
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
        .textCase(nil)
    }
}

private struct TodoRow: View {
    @Environment(\.modelContext) private var modelContext

    let todo: Todo
    let summary: String

    @State private var isHovering = false
    @State private var isEditingTitle = false
    @State private var draftTitle = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            TodoProgressControl(todo: todo) {
                if todo.setManuallyCompleted(!todo.isCompleted) {
                    try? modelContext.save()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                titleEditor

                HStack(spacing: 6) {
                    if let direction = todo.direction, !DefaultDirections.isTaskInbox(direction) {
                        Text("\(direction.symbolName) \(direction.name)")
                            .foregroundStyle(checkboxTint)
                        Text("·")
                    }

                    Text(priorityLabel)

                    Text("·")

                    Text(summary)

                    ForEach(todo.hashtags, id: \.self) { hashtag in
                        Text(verbatim: "#\(hashtag)")
                            .foregroundStyle(checkboxTint)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .opacity(todo.isCompleted ? 0.55 : 1)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onAppear {
            draftTitle = todo.title
        }
        .onChange(of: todo.title) { _, newValue in
            guard !isEditingTitle else { return }
            draftTitle = newValue
        }
        .onChange(of: isTitleFocused) { _, isFocused in
            if !isFocused, isEditingTitle {
                commitTitle()
            }
        }
        .onDisappear(perform: commitTitleIfNeeded)
        .listRowInsets(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10))
        .listRowSeparator(.hidden)
        .listRowBackground(rowBackground)
    }

    @ViewBuilder
    private var titleEditor: some View {
        if isEditingTitle {
            TextField(titlePlaceholder, text: $draftTitle)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .strikethrough(todo.isCompleted)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                .focused($isTitleFocused)
                .onSubmit(commitTitle)
                .accessibilityLabel(String(localized: "タスク名"))
        } else {
            Text(TodoDisplay.title(for: todo))
                .font(titleIsPlaceholder ? .body.weight(.medium).italic() : .body.weight(.medium))
                .strikethrough(todo.isCompleted)
                .foregroundStyle(titleColor)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    beginTitleEdit()
                }
                .accessibilityLabel(String(localized: "タスク名"))
        }
    }

    private func beginTitleEdit() {
        draftTitle = todo.title
        isEditingTitle = true

        Task { @MainActor in
            isTitleFocused = true
        }
    }

    private func commitTitle() {
        let normalizedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if todo.title != normalizedTitle {
            todo.title = normalizedTitle
            todo.updatedAt = .now
        }

        isEditingTitle = false
        isTitleFocused = false
        try? modelContext.save()
    }

    private func commitTitleIfNeeded() {
        guard isEditingTitle else { return }
        commitTitle()
    }

    private var priorityLabel: String {
        if todo.priority == .low, todo.isRoomIfPossible {
            return String(localized: "余裕があれば")
        }
        return todo.priority.displayName
    }

    private var titlePlaceholder: String {
        TodoDisplay.placeholder(for: todo)
    }

    private var titleIsPlaceholder: Bool {
        todo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var titleColor: Color {
        if todo.isCompleted {
            return .secondary
        }

        return titleIsPlaceholder ? .secondary.opacity(0.7) : .primary
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(tintColor)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(isHovering ? 0.05 : 0))
            )
            .padding(.vertical, 2)
    }

    private var tintColor: Color {
        guard let direction = todo.direction, !DefaultDirections.isTaskInbox(direction) else {
            return .clear
        }

        return Color(hex: direction.colorHex).opacity(0.08)
    }

    private var checkboxTint: Color {
        guard let direction = todo.direction, !DefaultDirections.isTaskInbox(direction) else {
            return Color.secondary.opacity(0.6)
        }

        return Color(hex: direction.colorHex)
    }
}

private struct EmptyRow: View {
    let text: String

    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    TasksView()
        .environmentObject(ActiveFlowStore())
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self], inMemory: true)
}
