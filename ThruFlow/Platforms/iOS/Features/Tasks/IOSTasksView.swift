import SwiftData
import SwiftUI

struct IOSTasksView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Todo.sortIndex) private var todos: [Todo]
    @Query(sort: \Direction.sortIndex) private var directions: [Direction]

    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var range = TaskCalendarRange.oneDay
    @State private var filter = TaskCalendarFilter.all
    @State private var editorMode: IOSTaskEditorMode?
    @State private var backlogMode: IOSBacklogMode?
    @State private var pendingBacklogMode: IOSBacklogMode?
    @State private var showsBacklogMenu = false
    @State private var searchText = ""
    @State private var showsComposer = false
    @State private var backlogMoveError: String?

    private var calendarBuilder: TaskCalendarBuilder { TaskCalendarBuilder(calendar: calendar) }
    private var rescheduleService: TaskRescheduleService {
        TaskRescheduleService(calendar: calendar, dayBoundary: dayBoundary)
    }
    private var searchBuilder: DatabaseSearchBuilder { DatabaseSearchBuilder(calendar: calendar) }

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
        TaskBacklogBuilder(
            calendar: calendar,
            dayBoundary: dayBoundary
        ).build(todos: todos)
    }

    private var backlogCount: Int {
        backlog.overdue.count + backlog.unscheduled.count
    }

    var body: some View {
        VStack(spacing: 0) {
            if isSearching {
                globalSearchContent
            } else {
                controls
                Divider()
                taskContent
                    .iosPeriodSwipeNavigation(
                        pageID: selectedPeriodPageID
                    ) { offset in
                        navigatePeriod(by: offset)
                    }
            }
        }
        .background(Color.primary.opacity(0.025).ignoresSafeArea())
        .navigationTitle(String(localized: "タスク"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(String(localized: "検索"))
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ZStack(alignment: .topTrailing) {
                    Button {
                        showsBacklogMenu.toggle()
                    } label: {
                        IOSMoreMenuLabel()
                    }
                    .accessibilityLabel(String(localized: "その他"))
                    .accessibilityValue("\(backlogCount)")

                    IOSNotificationBadge(count: backlogCount)
                        .allowsHitTesting(false)
                }
                .frame(width: 44, height: 44)
                .popover(isPresented: $showsBacklogMenu, arrowEdge: .top) {
                    backlogMenuContent
                        .presentationCompactAdaptation(.popover)
                        .onDisappear(perform: presentPendingBacklog)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsComposer {
                IOSTaskComposer(
                    directions: activeDirections,
                    onClose: dismissComposer
                )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .background(Color.primary.opacity(0.025).ignoresSafeArea())
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !showsComposer {
                addTaskButton
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
        .task {
            alignInitialSelectionWithCurrentAppDay()
            ensureRequiredTodos(reconcilesDuplicates: true)
        }
        .task(id: requiredTodoMaterializationID) {
            do {
                try await Task.sleep(for: .milliseconds(180))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            ensureRequiredTodos(reconcilesDuplicates: false)
        }
        .onDisappear {
            showsComposer = false
        }
        .onChange(of: directions.map(\.updatedAt)) { _, _ in
            ensureRequiredTodos(reconcilesDuplicates: true)
        }
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
        }
    }

    private func navigatePeriod(by offset: Int) {
        let date = calendarBuilder.advancedDate(
            from: selectedDate,
            range: range,
            direction: offset
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

    private var backlogMenuContent: some View {
        VStack(spacing: 4) {
            backlogMenuButton(
                String(localized: "期限切れ"),
                count: backlog.overdue.count,
                systemImage: "exclamationmark.circle",
                mode: .overdue
            )
            backlogMenuButton(
                String(localized: "日付なし"),
                count: backlog.unscheduled.count,
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

    private var controls: some View {
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
                    todos: searchFilteredTodos,
                    filter: filter
                )
            } else if range == .sevenDays {
                IOSWeekCardStrip(
                    selectedDate: $selectedDate,
                    todos: searchFilteredTodos,
                    filter: filter
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ViewBuilder
    private var taskContent: some View {
        switch range {
        case .oneDay:
            groupedList(for: selectedDate, todos: selectedTodos)
        case .sevenDays:
            weekList(anchorDate: selectedDate)
        case .month:
            ScrollView {
                VStack(spacing: 14) {
                    IOSTaskMonthCalendar(
                        selectedDate: $selectedDate,
                        todos: searchFilteredTodos,
                        filter: filter
                    )

                    daySection(date: selectedDate, todos: selectedTodos)
                }
                .padding(12)
            }
        }
    }

    private func weekList(anchorDate: Date) -> some View {
        let dates = calendarBuilder
            .dates(for: .sevenDays, anchoredAt: anchorDate)
            .filter { !todos(on: $0).isEmpty }

        return ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(dates, id: \.self) { date in
                    daySection(date: date, todos: todos(on: date))
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

    private func groupedList(for date: Date, todos: [Todo]) -> some View {
        let overdueTodos = visibleOverdueTodos(on: date)

        return ScrollView {
            LazyVStack(spacing: 14) {
                overdueTaskCard(overdueTodos)
                daySection(
                    date: date,
                    todos: todos,
                    suppressesEmptyState: !overdueTodos.isEmpty
                )
            }
            .padding(12)
        }
    }

    private func daySection(
        date: Date,
        todos: [Todo],
        suppressesEmptyState: Bool = false
    ) -> some View {
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

            if todos.isEmpty && !suppressesEmptyState {
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
    private func overdueTaskCard(_ todos: [Todo]) -> some View {
        if !todos.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(.red)
                        .frame(width: 7, height: 7)

                    Text(String(localized: "期限切れ"))
                        .font(.caption.weight(.semibold))

                    Text("\(todos.count)")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.14), in: Capsule())

                    Spacer(minLength: 0)

                    Button(String(localized: "すべて今日へ")) {
                        moveTodosToToday(todos)
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }

                ForEach(todos) { todo in
                    IOSTaskRow(todo: todo) {
                        editorMode = .edit(todo)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(14)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
        }
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

    @ViewBuilder
    private var globalSearchContent: some View {
        if searchSections.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(searchSections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            searchSectionTitle(section)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(section.todos) { todo in
                                IOSTaskRow(todo: todo) {
                                    editorMode = .edit(todo)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 9)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(14)
                        .background(
                            Color.primary.opacity(0.035),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                }
                .padding(12)
            }
        }
    }

    @ViewBuilder
    private func searchSectionTitle(_ section: DatabaseTaskSearchSection) -> some View {
        if let date = section.date {
            Text(date, format: .dateTime.year().month().day().weekday())
        } else {
            Label(String(localized: "日付なし"), systemImage: "tray")
        }
    }

    private func todos(on date: Date) -> [Todo] {
        todos
            .filter { TodayTodoFilter(calendar: calendar).includes($0, on: date) }
            .filter(filter.includes)
            .filter(matchesSearch)
            .sorted(by: taskSort)
    }

    private func visibleOverdueTodos(on date: Date) -> [Todo] {
        let today = dayBoundary.day(containing: .now, calendar: calendar)
        guard range == .oneDay,
              calendar.isDate(date, inSameDayAs: today) else {
            return []
        }
        return backlog.overdue
            .filter(filter.includes)
            .filter(matchesSearch)
            .sorted(by: taskSort)
    }

    private var searchFilteredTodos: [Todo] {
        todos.filter(matchesSearch)
    }

    private func matchesSearch(_ todo: Todo) -> Bool {
        DatabaseSearchQuery(text: searchText).matchesTask(todo)
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

    private var requiredTodoMaterializationID: RequiredTodoMaterializationID {
        RequiredTodoMaterializationID(
            selectedDate: calendar.startOfDay(for: selectedDate),
            rangeRawValue: range.rawValue,
            todoCount: todos.count
        )
    }

    private func ensureRequiredTodos(
        now: Date = .now,
        reconcilesDuplicates: Bool
    ) {
        if DefaultDirections.existingTaskInbox(in: directions) == nil {
            modelContext.insert(DefaultDirections.makeTaskInbox())
        }

        let today = dayBoundary.day(containing: now, calendar: calendar)
        let dates = visibleDates
            .filter { $0 >= today }
            .filter { range != .month || calendarBuilder.isDate($0, inMonthContaining: selectedDate) }
            .sorted()

        _ = try? HabitTodoMaterializer(
            calendar: calendar,
            dayBoundary: dayBoundary
        ).materialize(
            directions: activeDirections,
            dates: dates,
            modelContext: modelContext,
            now: now,
            knownTodos: todos,
            reconcilesDuplicates: reconcilesDuplicates
        )
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

private struct IOSWeekDateStrip: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    @Binding var selectedDate: Date
    let todos: [Todo]
    let filter: TaskCalendarFilter

    var body: some View {
        let colorsByDay = indicatorColorsByDay

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
                    Text("\(calendar.component(.day, from: date))")
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                    HStack(spacing: 2) {
                        ForEach(colorsByDay[calendar.startOfDay(for: date)] ?? [], id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 4, height: 4)
                        }
                    }
                    .frame(height: 4)
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

    private var indicatorColorsByDay: [Date: [String]] {
        let palette = TaskCalendarIndicatorPalette(calendar: calendar)
        return Dictionary(
            uniqueKeysWithValues: Set(
                todos.compactMap(\.scheduledDate)
                    .map(calendar.startOfDay(for:))
            )
                .map { day in
                    (day, palette.colors(on: day, todos: todos, filter: filter))
                }
        )
    }
}

private struct IOSWeekCardStrip: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    @Binding var selectedDate: Date
    let todos: [Todo]
    let filter: TaskCalendarFilter

    var body: some View {
        let colorsByWeek = indicatorColorsByWeek

        IOSScrollablePeriodStrip(
            selectedDate: $selectedDate,
            unit: .week,
            visibleItemCount: 3,
            spacing: 6,
            height: 58
        ) { anchor, isSelected in
            let dates = weekDates(containing: anchor)

            Button {
                selectedDate = calendar.startOfDay(for: anchor)
            } label: {
                VStack(spacing: 3) {
                    Text(monthText(for: dates))
                        .font(.caption.weight(.semibold))
                    Text(dayRangeText(for: dates))
                        .font(.body.monospacedDigit().weight(.semibold))

                    HStack(spacing: 2) {
                        ForEach(colorsByWeek[weekStart(for: anchor)] ?? [], id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 4, height: 4)
                        }
                    }
                    .frame(height: 4)
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

    private func weekDates(containing date: Date) -> [Date] {
        TaskCalendarBuilder(calendar: calendar).dates(for: .sevenDays, anchoredAt: date)
    }


    private func monthText(for dates: [Date]) -> String {
        guard let first = dates.first else { return "" }
        return first.formatted(.dateTime.locale(locale).month(.abbreviated))
    }

    private func dayRangeText(for dates: [Date]) -> String {
        guard let first = dates.first, let last = dates.last else { return "" }
        return "\(calendar.component(.day, from: first))–\(calendar.component(.day, from: last))"
    }

    private var indicatorColorsByWeek: [Date: [String]] {
        let palette = TaskCalendarIndicatorPalette(calendar: calendar)
        return Dictionary(
            uniqueKeysWithValues: Set(
                todos.compactMap(\.scheduledDate)
                    .map(weekStart(for:))
            )
                .map { week in
                    (
                        week,
                        palette.colors(
                            inWeekContaining: week,
                            todos: todos,
                            filter: filter
                        )
                    )
                }
        )
    }

    private func weekStart(for date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }
}

private struct IOSTaskMonthCalendar: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    @Binding var selectedDate: Date
    let todos: [Todo]
    let filter: TaskCalendarFilter

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 4),
        count: 7
    )

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(selectedDate.formatted(.dateTime.locale(locale).year().month(.wide)))
                    .font(.headline)

                Spacer()

                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(CalendarWeekdaySymbols.orderedAbbreviated(calendar: calendar), id: \.self) {
                    Text($0)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(monthDates, id: \.self) { date in
                    dayCell(date)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isCurrentMonth = calendar.isDate(date, equalTo: selectedDate, toGranularity: .month)
        let colors = TaskCalendarIndicatorPalette(calendar: calendar)
            .colors(on: date, todos: todos, filter: filter, limit: 3)

        return Button {
            selectedDate = calendar.startOfDay(for: date)
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.callout.monospacedDigit())

                HStack(spacing: 2) {
                    ForEach(colors, id: \.self) { colorHex in
                        Circle()
                            .fill(Color(hex: colorHex))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .foregroundStyle(isSelected ? Color.white : isCurrentMonth ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 9))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isCurrentMonth ? 1 : 0.5)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var monthDates: [Date] {
        TaskCalendarBuilder(calendar: calendar).dates(for: .month, anchoredAt: selectedDate)
    }

    private func moveMonth(by value: Int) {
        guard let date = calendar.date(byAdding: .month, value: value, to: selectedDate) else {
            return
        }
        selectedDate = calendar.startOfDay(for: date)
    }
}

private struct RequiredTodoMaterializationID: Hashable {
    let selectedDate: Date
    let rangeRawValue: String
    let todoCount: Int
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
