import SwiftData
import SwiftUI

struct IOSTasksView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Todo.sortIndex) private var todos: [Todo]
    @Query(sort: \Direction.sortIndex) private var directions: [Direction]

    let close: () -> Void

    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var range = TaskCalendarRange.oneDay
    @State private var filter = TaskCalendarFilter.all
    @State private var editorMode: IOSTaskEditorMode?
    @State private var backlogMode: IOSBacklogMode?
    @State private var showsComposer = false
    @State private var isClosing = false

    init(close: @escaping () -> Void = {}) {
        self.close = close
    }

    private var calendarBuilder: TaskCalendarBuilder { TaskCalendarBuilder(calendar: calendar) }
    private var requiredPlanner: RequiredTodoPlanner { RequiredTodoPlanner(calendar: calendar) }

    private var activeDirections: [Direction] {
        directions.filter { !$0.isArchived }
    }

    private var visibleDates: [Date] {
        calendarBuilder.dates(for: range, anchoredAt: selectedDate)
    }

    private var selectedTodos: [Todo] {
        todos(on: selectedDate)
    }

    private var backlog: TaskBacklogSnapshot {
        TaskBacklogBuilder(calendar: calendar).build(todos: todos)
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            taskContent
        }
        .background(Color.primary.opacity(0.025).ignoresSafeArea())
        .navigationTitle(String(localized: "タスク"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: closeTasks) {
                    Label(String(localized: "Flow"), systemImage: "chevron.left")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsComposer {
                IOSTaskComposer(directions: activeDirections)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $editorMode) { mode in
            NavigationStack {
                IOSTaskEditorView(mode: mode, directions: activeDirections)
            }
        }
        .sheet(item: $backlogMode) { mode in
            NavigationStack {
                IOSBacklogView(
                    mode: mode,
                    todos: mode == .overdue ? backlog.overdue : backlog.unscheduled,
                    edit: { todo in
                        backlogMode = nil
                        editorMode = .edit(todo)
                    }
                )
            }
        }
        .task {
            ensureRequiredTodos()
            await presentComposer()
        }
        .onDisappear { showsComposer = false }
        .onChange(of: range) { _, _ in ensureRequiredTodos() }
        .onChange(of: selectedDate) { _, _ in ensureRequiredTodos() }
        .onChange(of: directions.map(\.updatedAt)) { _, _ in ensureRequiredTodos() }
    }

    @MainActor
    private func presentComposer() async {
        guard !showsComposer else { return }

        do {
            try await Task.sleep(for: .milliseconds(220))
        } catch {
            return
        }

        withAnimation(.easeOut(duration: 0.28)) {
            showsComposer = true
        }
    }

    private func closeTasks() {
        guard !isClosing else { return }
        isClosing = true

        withAnimation(.easeIn(duration: 0.24)) {
            showsComposer = false
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            close()
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Picker(String(localized: "フィルター"), selection: $filter) {
                    ForEach(TaskCalendarFilter.allCases) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                .pickerStyle(.segmented)

                Picker(String(localized: "表示範囲"), selection: $range) {
                    ForEach(TaskCalendarRange.allCases) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 150)
            }

            HStack(spacing: 8) {
                Button(String(localized: "今日")) {
                    selectedDate = calendar.startOfDay(for: .now)
                }
                .buttonStyle(.borderedProminent)

                backlogButton(
                    String(localized: "期限切れ"),
                    count: backlog.overdue.count,
                    systemImage: "exclamationmark.circle",
                    mode: .overdue
                )
                backlogButton(
                    String(localized: "日付なし"),
                    count: backlog.unscheduled.count,
                    systemImage: "tray",
                    mode: .unscheduled
                )

                Spacer(minLength: 0)
            }

            if range == .oneDay {
                IOSWeekDateStrip(
                    selectedDate: $selectedDate,
                    todos: todos,
                    filter: filter
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func backlogButton(
        _ title: String,
        count: Int,
        systemImage: String,
        mode: IOSBacklogMode
    ) -> some View {
        Button {
            backlogMode = mode
        } label: {
            Label {
                HStack(spacing: 4) {
                    Text(title)
                    Text("\(count)")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.14), in: Capsule())
                }
            } icon: {
                Image(systemName: systemImage)
            }
        }
        .buttonStyle(.bordered)
        .foregroundStyle(count == 0 ? .secondary : .primary)
    }

    @ViewBuilder
    private var taskContent: some View {
        switch range {
        case .oneDay:
            groupedList(for: selectedDate, todos: selectedTodos)
        case .sevenDays:
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(visibleDates, id: \.self) { date in
                        daySection(date: date, todos: todos(on: date))
                    }
                }
                .padding(12)
            }
        case .month:
            ScrollView {
                VStack(spacing: 14) {
                    DatePicker(
                        String(localized: "日付"),
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                    daySection(date: selectedDate, todos: selectedTodos)
                }
                .padding(12)
            }
        }
    }

    private func groupedList(for date: Date, todos: [Todo]) -> some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                daySection(date: date, todos: todos)
            }
            .padding(12)
        }
    }

    private func daySection(date: Date, todos: [Todo]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(date, format: .dateTime.month().day().weekday())
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            let grouped = IOSGroupedTodos(todos: todos)
            taskGroup(title: String(localized: "習慣"), todos: grouped.habits)
            taskGroup(title: String(localized: "タスク"), todos: grouped.tasks)
            if !grouped.nice.isEmpty {
                taskGroup(title: String(localized: "ナイス"), todos: grouped.nice)
            }

            if todos.isEmpty {
                ContentUnavailableView(
                    String(localized: "今日の項目はありません"),
                    systemImage: "checkmark.circle"
                )
                .frame(maxWidth: .infinity, minHeight: 150)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func taskGroup(title: String, todos: [Todo]) -> some View {
        if !todos.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(todos) { todo in
                    IOSTaskRow(todo: todo) {
                        editorMode = .edit(todo)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func todos(on date: Date) -> [Todo] {
        todos
            .filter { TodayTodoFilter(calendar: calendar).includes($0, on: date) }
            .filter(filter.includes)
            .sorted(by: taskSort)
    }

    private func ensureRequiredTodos(now: Date = .now) {
        if DefaultDirections.existingTaskInbox(in: directions) == nil {
            modelContext.insert(DefaultDirections.makeTaskInbox())
        }

        let today = calendar.startOfDay(for: now)
        let dates = visibleDates
            .filter { $0 >= today }
            .filter { range != .month || calendarBuilder.isDate($0, inMonthContaining: selectedDate) }
            .sorted()

        var knownTodos = todos
        var changed = false
        var nextSortIndex = (todos.map(\.sortIndex).min() ?? 0) - 1

        for date in dates {
            for direction in activeDirections where direction.type == .habit {
                if direction.goalSchedule == .weeklyCount && !calendar.isDate(date, inSameDayAs: today) {
                    continue
                }
                guard let todo = requiredPlanner.makeRequiredTodo(
                    for: direction,
                    existingTodos: knownTodos,
                    on: date,
                    sortIndex: nextSortIndex
                ) else { continue }
                modelContext.insert(todo)
                knownTodos.append(todo)
                nextSortIndex -= 1
                changed = true
            }
        }

        if changed { try? modelContext.save() }
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

private struct IOSWeekDateStrip: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    @Binding var selectedDate: Date
    let todos: [Todo]
    let filter: TaskCalendarFilter

    private var dates: [Date] {
        TaskCalendarBuilder(calendar: calendar).dates(for: .sevenDays, anchoredAt: selectedDate)
    }

    var body: some View {
        HStack(spacing: 5) {
            ForEach(dates, id: \.self) { date in
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                Button {
                    selectedDate = calendar.startOfDay(for: date)
                } label: {
                    VStack(spacing: 4) {
                        Text(date.formatted(.dateTime.locale(locale).weekday(.narrow)))
                            .font(.caption2.weight(.semibold))
                        Text(date.formatted(.dateTime.day()))
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                        HStack(spacing: 2) {
                            ForEach(indicatorColors(on: date), id: \.self) { colorHex in
                                Circle()
                                    .fill(Color(hex: colorHex))
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .frame(maxWidth: .infinity, minHeight: 55)
                    .background(isSelected ? Color.accentColor : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func indicatorColors(on date: Date) -> [String] {
        var seen = Set<String>()
        return todos
            .filter { TodayTodoFilter(calendar: calendar).includes($0, on: date) && filter.includes($0) }
            .compactMap { $0.direction?.colorHex }
            .filter { seen.insert($0.lowercased()).inserted }
            .prefix(4)
            .map { $0 }
    }
}

private struct IOSGroupedTodos {
    let habits: [Todo]
    let tasks: [Todo]
    let nice: [Todo]

    init(todos: [Todo]) {
        habits = todos.filter { $0.direction?.type == .habit }
        tasks = todos.filter { todo in
            guard let direction = todo.direction else { return true }
            return direction.type == .neutral || DefaultDirections.isTaskInbox(direction)
        }
        nice = todos.filter { $0.direction?.type == .nice }
    }
}

private enum IOSBacklogMode: String, Identifiable {
    case overdue
    case unscheduled
    var id: String { rawValue }
}

private struct IOSBacklogView: View {
    @Environment(\.dismiss) private var dismiss
    let mode: IOSBacklogMode
    let todos: [Todo]
    let edit: (Todo) -> Void

    var body: some View {
        List(todos) { todo in
            IOSTaskRow(todo: todo) { edit(todo) }
        }
        .overlay {
            if todos.isEmpty {
                ContentUnavailableView(
                    mode == .overdue ? String(localized: "期限切れ") : String(localized: "日付なし"),
                    systemImage: mode == .overdue ? "checkmark.circle" : "tray"
                )
            }
        }
        .navigationTitle(mode == .overdue ? String(localized: "期限切れ") : String(localized: "日付なし"))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "完了")) { dismiss() }
            }
        }
    }
}

struct IOSTaskRow: View {
    @Environment(\.modelContext) private var modelContext

    let todo: Todo
    let edit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TodoProgressControl(todo: todo) {
                if todo.setManuallyCompleted(!todo.isCompleted) {
                    try? modelContext.save()
                }
            }

            Text(todo.direction?.symbolName ?? DefaultDirections.taskInboxSymbol)
                .font(.title3)

            VStack(alignment: .leading, spacing: 3) {
                Text(TodoDisplay.title(for: todo))
                    .font(.body.weight(.medium))
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)

                HStack(spacing: 5) {
                    if let direction = todo.direction, !DefaultDirections.isTaskInbox(direction) {
                        Text(direction.name)
                            .foregroundStyle(Color(hex: direction.colorHex))
                    }
                    Text(todo.priority.displayName)
                    Text(progressText)
                    if let firstTag = todo.hashtags.first {
                        Text("#\(firstTag)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: edit)
    }

    private var progressText: String {
        TodoProgressCalculator().summary(
            measurement: todo.measurement,
            plannedAmount: todo.plannedAmount,
            actualProgress: todo.actualProgress,
            focusDurationSeconds: todo.recordedFocusSeconds
        )
    }
}

enum IOSTaskEditorMode: Identifiable {
    case create
    case edit(Todo)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let todo): todo.id.uuidString
        }
    }
}
