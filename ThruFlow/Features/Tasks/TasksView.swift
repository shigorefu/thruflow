//
//  TasksView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import SwiftData
import SwiftUI

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Direction.name, order: .forward) private var directions: [Direction]
    @Query(sort: \Todo.sortIndex, order: .forward) private var todos: [Todo]

    @State private var editingTodo: Todo?
    @State private var newTodoTitle = ""
    @State private var newTodoDirectionID: UUID?
    @State private var newTodoVolume: QuickTodoVolume = .checkbox
    @State private var newTodoPriority: TodoPriority = .medium
    @State private var newTodoIsRoomIfPossible = false
    @State private var newTodoDateOption: QuickTodoDate = .today
    @State private var newTodoError: String?
    @State private var anchorDate = Calendar.current.startOfDay(for: .now)
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var calendarRange: TaskCalendarRange = .oneDay
    @State private var taskFilter: TaskCalendarFilter = .all
    @State private var moveError: String?
    @AppStorage("today.groupOrder") private var groupOrderRaw = TasksTodoGroup.defaultOrderRaw

    private let filter = TodayTodoFilter()
    private let requiredPlanner = RequiredTodoPlanner()
    private let calendarBuilder = TaskCalendarBuilder()
    private let rescheduleService = TaskRescheduleService()
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

    var body: some View {
        VStack(spacing: 0) {
            TaskCalendarToolbar(
                range: $calendarRange,
                filter: $taskFilter,
                onToday: moveToToday
            )

            Divider()

            tasksWorkspace
        }
        .navigationTitle("タスク")
        .safeAreaInset(edge: .bottom) {
            MessengerTodoComposer(
                title: $newTodoTitle,
                selectedDirectionID: $newTodoDirectionID,
                volume: $newTodoVolume,
                priority: $newTodoPriority,
                isRoomIfPossible: $newTodoIsRoomIfPossible,
                dateOption: $newTodoDateOption,
                directions: visibleDirections,
                validationMessage: newTodoError,
                onSubmit: createInlineTodo
            )
        }
        .sheet(item: $editingTodo) { todo in
            TodoFormView(mode: .edit(todo))
        }
        .alert("移動できません", isPresented: moveErrorIsPresented) {
            Button("OK", role: .cancel) {
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
            NSApp.keyWindow?.makeFirstResponder(nil)
#endif
        }
    }

    @ViewBuilder
    private var tasksWorkspace: some View {
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

    @ViewBuilder
    private var taskPeriodPicker: some View {
        switch calendarRange {
        case .oneDay:
            HistoryMiniCalendar(selectedDate: selectedDateBinding)
        case .sevenDays:
            HistoryMiniCalendar(selectedDate: selectedDateBinding, selectionMode: .week)
        case .month:
            HistoryYearMonthPicker(selectedDate: selectedDateBinding)
        }
    }

    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: { selectedDate },
            set: { date in
                let day = Calendar.current.startOfDay(for: date)
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
                onMove: moveTodo
            )
        case .month:
            TaskMonthGrid(
                anchorDate: anchorDate,
                dates: visibleDates,
                selectedDate: selectedDate,
                todos: todos.filter { !$0.isArchived && !$0.isDeleted },
                filter: taskFilter,
                onSelectDate: openDay
            )
        }
    }

    private var oneDayList: some View {
        List {
            if selectedDateGroups.isEmpty {
                EmptyRow(text: "この日のタスクはありません。")
                    .listRowSeparator(.hidden)
            } else {
                ForEach(selectedDateGroups) { group in
                    Section {
                        ForEach(group.todos) { todo in
                            todoRow(todo)
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
        let today = Calendar.current.startOfDay(for: .now)
        anchorDate = today
        selectedDate = today
    }

    private func selectDate(_ date: Date) {
        selectedDate = Calendar.current.startOfDay(for: date)
    }

    private func openDay(_ date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        selectedDate = day
        anchorDate = day
        calendarRange = .oneDay
    }

    private func selectComposerDate(_ date: Date) {
        let calendar = Calendar.current
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

    private func moveTodo(_ todo: Todo, to date: Date) {
        switch rescheduleService.validate(todo, movingTo: date, among: todos) {
        case .success:
            todo.reschedule(to: Calendar.current.startOfDay(for: date))
            todo.setSortIndex((todos.map(\.sortIndex).min() ?? 0) - 1)
            try? modelContext.save()
        case .failure(let failure):
            moveError = failure.message
        }
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
            Button("編集", systemImage: "pencil") {
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

            Button("Flowを開始", systemImage: "play.fill") {
                activeFlowStore.configure(direction: todo.direction, todo: todo)
            }

            Divider()

            Button("削除", systemImage: "trash", role: .destructive) {
                todo.softDelete()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("削除", systemImage: "trash", role: .destructive) {
                todo.softDelete()
            }
        }
    }

    @ViewBuilder
    private func standardMoveMenu(for todo: Todo) -> some View {
        Menu("移動") {
            Button("今日") {
                reschedule(todo, to: .now)
            }
            Button("明日") {
                reschedule(todo, to: Calendar.current.date(byAdding: .day, value: 1, to: .now))
            }
            Button("日付なし") {
                reschedule(todo, to: nil)
            }
        }
    }

    @ViewBuilder
    private func weeklyHabitMoveMenu(for todo: Todo) -> some View {
        let options = requiredPlanner.weeklyRescheduleOptions(for: todo, in: todos)

        Menu("移動") {
            ForEach(options, id: \.date) { option in
                Button(rescheduleLabel(for: option.date)) {
                    reschedule(todo, to: option.date)
                }
                .disabled(!option.isAllowed)
                .help(option.isAllowed ? "" : "週間目標を達成できなくなるため移動できません")
            }
        }
    }

    private func reschedule(_ todo: Todo, to date: Date?) {
        todo.reschedule(to: date)
        try? modelContext.save()
    }

    private func rescheduleLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今日"
        }
        if calendar.isDateInTomorrow(date) {
            return "明日"
        }

        return Self.rescheduleDateFormatter.string(from: date)
    }

    private static let rescheduleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d（E）"
        return formatter
    }()

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
        if newTodoPriority != .low {
            newTodoIsRoomIfPossible = false
        }
        newTodoError = nil
    }

    private func ensureRequiredTodosForVisibleDates(now: Date = .now) {
        let calendar = Calendar.current
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
    case checkbox
    case blocks(Int)
    case minutes(Int)

    static let options: [QuickTodoVolume] = [
        .checkbox,
        .blocks(1),
        .blocks(2),
        .blocks(3),
        .minutes(15),
        .minutes(25),
        .minutes(50)
    ]

    var measurement: TodoMeasurement {
        switch self {
        case .checkbox:
            .checkbox
        case .blocks:
            .focusBlocks
        case .minutes:
            .minutes
        }
    }

    var plannedAmount: Int? {
        switch self {
        case .checkbox:
            nil
        case .blocks(let count), .minutes(let count):
            count
        }
    }

    var menuLabel: String {
        switch self {
        case .checkbox:
            "チェックのみ"
        case .blocks(let count):
            count == 1 ? "1 Block" : "\(count) Blocks"
        case .minutes(let count):
            "\(count)分"
        }
    }

    var chipLabel: String {
        switch self {
        case .checkbox:
            "チェック"
        case .blocks(let count):
            count == 1 ? "1 Block" : "\(count) Blocks"
        case .minutes(let count):
            "\(count)分"
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
            "今日"
        case .tomorrow:
            "明日"
        case .none:
            "日付なし"
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

    let directions: [Direction]
    let validationMessage: String?
    var allowsDateSelection = true
    var showsOuterBackground = true
    var onCancel: (() -> Void)?
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                TextField("タスクを入力してください", text: $title, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .lineLimit(2...5)
                    .focused($isFocused)
                    .onSubmit(submit)

                if let onCancel {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("閉じる")
                    .accessibilityLabel("タスク作成を閉じる")
                }
            }

            HStack(spacing: 10) {
                VolumeChip(volume: $volume)

                DirectionChip(selectedDirectionID: $selectedDirectionID, directions: directions)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(3)

                PriorityChip(priority: $priority, isRoomIfPossible: $isRoomIfPossible)

                if priority == .low {
                    RoomIfPossibleChip(isSelected: $isRoomIfPossible)
                }

                if allowsDateSelection {
                    DateChip(dateOption: $dateOption)
                } else {
                    Text("今日")
                        .chipStyle(tint: .secondary)
                        .accessibilityLabel("日付 今日")
                }

                Spacer(minLength: 0)

                Button(action: submit) {
                    Image(systemName: "arrow.up")
                        .font(.headline.weight(.semibold))
                        .frame(width: 38, height: 38)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("タスクを追加")
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .background {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.primary.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.primary.opacity(0.12))
        }
        .padding(.horizontal, showsOuterBackground ? 12 : 0)
        .padding(.vertical, showsOuterBackground ? 8 : 0)
        .background {
            if showsOuterBackground {
                Rectangle().fill(.bar)
            }
        }
    }

    private func submit() {
        onSubmit()
        isFocused = true
    }
}

struct QuickTodoCreationPopover: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Todo.sortIndex, order: .forward) private var allTodos: [Todo]

    let directions: [Direction]
    var onCreated: ((Todo) -> Void)?

    @State private var title = ""
    @State private var selectedDirectionID: UUID?
    @State private var volume: QuickTodoVolume = .checkbox
    @State private var priority: TodoPriority = .medium
    @State private var isRoomIfPossible = false
    @State private var dateOption: QuickTodoDate = .today
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
            directions: selectableDirections,
            validationMessage: validationMessage,
            allowsDateSelection: false,
            showsOuterBackground: false,
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

    var body: some View {
        Menu {
            ForEach(TodoPriority.allCases) { option in
                Button {
                    priority = option
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
                } label: {
                    menuRow(text: "余裕があれば", isSelected: isRoomIfPossible)
                }
            }
        } label: {
            Text(labelText)
                .chipStyle(tint: tint)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("優先度を選択")
    }

    private var labelText: String {
        return priority.displayName
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

                Text("余裕があれば")
            }
            .chipStyle(tint: .green)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("余裕があれば")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct DirectionChip: View {
    @Binding var selectedDirectionID: UUID?

    let directions: [Direction]

    private var selectedDirection: Direction? {
        guard let selectedDirectionID else { return nil }
        return directions.first { $0.id == selectedDirectionID }
    }

    private var labelText: String {
        guard let selectedDirection else {
            return "その他"
        }

        return "\(selectedDirection.symbolName) \(selectedDirection.name)"
    }

    var body: some View {
        Menu {
            Button {
                selectedDirectionID = nil
            } label: {
                menuRow(text: "自動: その他", isSelected: selectedDirectionID == nil)
            }

            if !directions.isEmpty {
                Divider()

                ForEach(directions) { direction in
                    Button {
                        selectedDirectionID = direction.id
                    } label: {
                        menuRow(
                            text: "\(direction.symbolName) \(direction.name)",
                            isSelected: selectedDirectionID == direction.id
                        )
                    }
                }
            }
        } label: {
            Text(labelText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .chipStyle(tint: chipColor)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("方向を選択")
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
        Menu {
            ForEach(QuickTodoVolume.options, id: \.self) { option in
                Button {
                    volume = option
                } label: {
                    if option == volume {
                        Label(option.menuLabel, systemImage: "checkmark")
                    } else {
                        Text(option.menuLabel)
                    }
                }
            }
        } label: {
            Text(volume.chipLabel)
                .chipStyle(tint: .secondary)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("タスクの分量を選択")
    }
}

private struct DateChip: View {
    @Binding var dateOption: QuickTodoDate

    @State private var showingCustomPicker = false
    @State private var customDate = Date.now

    var body: some View {
        Menu {
            Button {
                dateOption = .today
            } label: {
                menuRow(text: "今日", isSelected: dateOption == .today)
            }

            Button {
                dateOption = .tomorrow
            } label: {
                menuRow(text: "明日", isSelected: dateOption == .tomorrow)
            }

            Button {
                dateOption = .none
            } label: {
                menuRow(text: "日付なし", isSelected: dateOption == .none)
            }

            Divider()

            Button("他の日付...") {
                customDate = dateOption.resolvedDate ?? .now
                showingCustomPicker = true
            }
        } label: {
            Text(dateOption.chipLabel)
                .chipStyle(tint: .secondary)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("日付を選択")
        .popover(isPresented: $showingCustomPicker) {
            VStack(spacing: 12) {
                DatePicker("日付", selection: $customDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()

                Button("設定") {
                    dateOption = .custom(customDate)
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
            "習慣"
        case .neutral:
            "通常"
        case .nice:
            "ナイス"
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
                .accessibilityLabel("タスク名")
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
                .accessibilityLabel("タスク名")
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
            return "余裕があれば"
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
