//
//  HistoryTaskRecordForm.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/24.
//

import SwiftData
import SwiftUI

struct HistoryTaskRecordForm: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Direction.sortIndex) private var directions: [Direction]
    @Query(sort: \Todo.updatedAt, order: .reverse) private var todos: [Todo]

    let context: HistoryRecordContext
    let onDismiss: () -> Void

    @State private var selectedTarget: HistoryRecordTarget?
    @State private var isChoosingTarget = false
    @State private var title = ""
    @State private var selectedDirectionID: UUID?
    @State private var measurement: TodoMeasurement = .checkbox
    @State private var priority: TodoPriority = .medium
    @State private var isRoomIfPossible = false
    @State private var plannedAmount = 1
    @State private var mode: FlowMode = .twentyFiveFive
    @State private var timeDraft: FlowHistoryTimeDraft
    @State private var specifiesCheckTime = false
    @State private var errorMessage: String?

    private let editor = HistoryTaskRecordEditor()

    init(
        startedAt: Date,
        context: HistoryRecordContext,
        onDismiss: @escaping () -> Void
    ) {
        self.context = context
        self.onDismiss = onDismiss
        _timeDraft = State(initialValue: FlowHistoryTimeDraft(
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(25 * 60),
            focusSeconds: 25 * 60
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(context.targetSectionTitle) {
                    targetPickerButton
                }

                if selectedTarget == .newTask {
                    newTaskSections
                }

                if selectedTarget != nil {
                    timingSection
                }

                if requiresFlow {
                    flowSection
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(String(localized: "記録を追加"))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                recordActions
            }
            .onChange(of: timeDraft.startedAt) { _, _ in
                validateSelectionForCurrentDay()
            }
            .onChange(of: selectedTarget) { _, newTarget in
                errorMessage = nil
                if newTarget == .newTask, selectedDirectionID == nil {
                    selectedDirectionID = (
                        DefaultDirections.existingTaskInbox(in: availableDirections)
                            ?? availableDirections.first
                    )?.id
                }
            }
            .onChange(of: mode) { _, newMode in
                timeDraft.setFocusMinutes(newMode.initialFocusDurationSeconds / 60)
            }
            .task {
                applyDefaultTargetIfNeeded()
            }
        }
    }

    private var recordActions: some View {
        HStack(spacing: 12) {
            Button(String(localized: "キャンセル"), role: .cancel, action: onDismiss)

            Spacer(minLength: 0)

            Button(String(localized: "記録"), action: save)
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var availableDirections: [Direction] {
        directions.filter { !$0.isArchived }
    }

    private var dayTodos: [Todo] {
        editor.availableTodos(on: timeDraft.startedAt, from: todos)
    }

    private var taskTodos: [Todo] {
        dayTodos.filter { $0.direction?.type != .habit }
    }

    private var habitOptions: [HistoryHabitOption] {
        let existingByDirection = Dictionary(
            dayTodos
                .filter { $0.direction?.type == .habit }
                .compactMap { todo -> (UUID, Todo)? in
                    guard let directionID = todo.direction?.id else { return nil }
                    return (directionID, todo)
                },
            uniquingKeysWith: { current, _ in current }
        )

        return availableDirections
            .filter { direction in
                direction.type == .habit
                    && direction.goalUnit != nil
                    && (
                        existingByDirection[direction.id] != nil
                            || RequiredTodoPlanner(calendar: calendar).shouldAppearToday(
                                direction,
                                on: dayBoundary.day(containing: timeDraft.startedAt, calendar: calendar)
                            )
                    )
            }
            .map { direction in
                HistoryHabitOption(
                    direction: direction,
                    todo: existingByDirection[direction.id]
                )
            }
    }

    private var selectedTodo: Todo? {
        switch selectedTarget {
        case let .todo(id):
            return dayTodos.first { $0.id == id }
        case let .habit(directionID):
            return habitOptions.first { $0.id == directionID }?.todo
        case .direction, .newTask, nil:
            return nil
        }
    }

    private var selectedDirection: Direction? {
        switch selectedTarget {
        case let .todo(id):
            return dayTodos.first { $0.id == id }?.direction
        case let .habit(id), let .direction(id):
            return availableDirections.first { $0.id == id }
        case .newTask:
            guard let selectedDirectionID else { return nil }
            return availableDirections.first { $0.id == selectedDirectionID }
        case nil:
            return nil
        }
    }

    private var activeMeasurement: TodoMeasurement? {
        if let selectedTodo {
            return selectedTodo.measurement
        }

        switch selectedTarget {
        case let .habit(directionID):
            guard let direction = availableDirections.first(where: { $0.id == directionID }),
                  let goalUnit = direction.goalUnit else {
                return nil
            }
            return measurement(for: goalUnit)
        case .newTask:
            return measurement
        case .todo, .direction, nil:
            return nil
        }
    }

    private var activePlannedAmount: Int? {
        if let selectedTodo {
            return selectedTodo.plannedAmount
        }

        switch selectedTarget {
        case let .habit(directionID):
            guard let direction = availableDirections.first(where: { $0.id == directionID }),
                  let goalUnit = direction.goalUnit else {
                return nil
            }
            return plannedAmount(for: goalUnit, target: max(1, direction.goalTarget ?? 1))
        case .newTask:
            return measurement == .checkbox ? nil : plannedAmount
        case .todo, .direction, nil:
            return nil
        }
    }

    private var requiresFlow: Bool {
        if context != .task {
            return selectedTarget != nil
        }
        if case .direction = selectedTarget {
            return true
        }
        guard let activeMeasurement else { return false }
        return activeMeasurement != .checkbox
    }

    private var canSave: Bool {
        guard selectedTarget != nil else { return false }

        if context == .flow {
            return selectedDirection != nil && selectedTarget != .newTask
        }

        if context == .direction {
            guard case .direction = selectedTarget else { return false }
            return selectedDirection != nil
        }

        if selectedTarget == .newTask {
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && selectedDirection != nil
                && (measurement == .checkbox || plannedAmount > 0)
        }

        return selectedDirection != nil
    }

    private var targetPickerButton: some View {
        Button {
            isChoosingTarget = true
        } label: {
            HStack(spacing: 12) {
                targetProgress

                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(targetTint.opacity(0.16))

                    Text(selectedDirection?.symbolName ?? "＋")
                        .font(.title2)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(targetTitle)
                        .font(.headline)
                        .foregroundStyle(selectedTarget == nil ? .secondary : .primary)
                        .lineLimit(1)

                    if let subtitle = targetSubtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let progressText = targetProgressText {
                        Text(progressText)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(targetTint)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isChoosingTarget, arrowEdge: .bottom) {
            HistoryRecordTargetPicker(
                context: context,
                taskTodos: taskTodos,
                habitOptions: habitOptions,
                directions: availableDirections,
                selectedTarget: selectedTarget,
                onSelect: { target in
                    selectedTarget = target
                    isChoosingTarget = false
                }
            )
#if os(macOS)
            .frame(width: 520, height: 460)
#else
            .presentationCompactAdaptation(.sheet)
#endif
        }
        .accessibilityLabel(context.targetPickerLabel)
    }

    @ViewBuilder
    private var targetProgress: some View {
        if let activeMeasurement,
           !(context == .flow && activeMeasurement == .checkbox) {
            HistoryRecordProgressPreview(
                measurement: activeMeasurement,
                plannedAmount: activePlannedAmount,
                currentFocusSeconds: selectedTodo?.recordedFocusSeconds ?? 0,
                currentActualProgress: selectedTodo?.actualProgress ?? 0,
                addedFocusSeconds: requiresFlow ? timeDraft.focusSeconds : 0,
                tint: targetTint
            )
        }
    }

    @ViewBuilder
    private var newTaskSections: some View {
        Section(String(localized: "タスク")) {
            TextField(String(localized: "タスク名"), text: $title, axis: .vertical)
                .lineLimit(1...3)

            Picker(String(localized: "方向"), selection: $selectedDirectionID) {
                ForEach(availableDirections) { direction in
                    Text("\(direction.symbolName) \(direction.name)")
                        .tag(Optional(direction.id))
                }
            }
        }

        Section(String(localized: "設定")) {
            Picker(String(localized: "種類"), selection: $measurement) {
                ForEach(TodoMeasurement.allCases) { measurement in
                    Text(measurement.displayName).tag(measurement)
                }
            }

            if measurement != .checkbox {
                Stepper(value: $plannedAmount, in: 1...999) {
                    LabeledContent(String(localized: "目標"), value: targetText)
                }
            }

            Picker(String(localized: "優先度"), selection: $priority) {
                ForEach(TodoPriority.allCases) { priority in
                    Text(priority.displayName).tag(priority)
                }
            }

            if priority == .low {
                Toggle(String(localized: "余裕があれば"), isOn: $isRoomIfPossible)
            }
        }
    }

    private var timingSection: some View {
        Section(String(localized: "日時")) {
            if requiresFlow {
                DatePicker(
                    String(localized: "開始"),
                    selection: Binding(
                        get: { timeDraft.startedAt },
                        set: { timeDraft.setStartedAt($0) }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )

                DatePicker(
                    String(localized: "終了"),
                    selection: Binding(
                        get: { timeDraft.endedAt },
                        set: { timeDraft.setEndedAt($0) }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
            } else {
                DatePicker(
                    String(localized: "日付"),
                    selection: Binding(
                        get: { timeDraft.startedAt },
                        set: { timeDraft.setStartedAt($0) }
                    ),
                    displayedComponents: .date
                )

                Toggle(String(localized: "時刻を指定"), isOn: $specifiesCheckTime)

                if specifiesCheckTime {
                    DatePicker(
                        String(localized: "時刻"),
                        selection: Binding(
                            get: { timeDraft.startedAt },
                            set: { timeDraft.setStartedAt($0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
            }
        }
    }

    private var flowSection: some View {
        Section(String(localized: "集中設定")) {
            Picker(String(localized: "Flowタイプ"), selection: $mode) {
                ForEach(manualModes) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            LabeledContent(
                String(localized: "集中"),
                value: String(localized: "\(timeDraft.focusMinutes)分")
            )
        }
    }

    private var targetTitle: String {
        if let selectedTodo {
            return TodoDisplay.title(for: selectedTodo)
        }

        switch selectedTarget {
        case let .habit(directionID):
            guard let direction = availableDirections.first(where: { $0.id == directionID }) else {
                return String(localized: "習慣")
            }
            return "(\(direction.name))"
        case let .direction(directionID):
            if context == .flow {
                return String(localized: "タスクなし")
            }
            guard let direction = availableDirections.first(where: { $0.id == directionID }) else {
                return String(localized: "方向")
            }
            return "(\(direction.name))"
        case .newTask:
            let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? String(localized: "新しいタスク") : normalized
        case .todo:
            return String(localized: "タスク")
        case nil:
            return context.emptyTargetTitle
        }
    }

    private var targetSubtitle: String? {
        guard selectedTarget != nil else { return nil }

        switch selectedTarget {
        case .habit:
            return selectedDirection?.name ?? String(localized: "習慣")
        case .direction:
            return String(localized: "タスクなし")
        case .todo, .newTask:
            return selectedDirection?.name ?? String(localized: "その他")
        case nil:
            return nil
        }
    }

    private var targetProgressText: String? {
        guard let activeMeasurement else { return nil }
        if context == .flow, activeMeasurement == .checkbox {
            return nil
        }

        let currentFocusSeconds = selectedTodo?.recordedFocusSeconds ?? 0
        let addedFocusSeconds = requiresFlow ? timeDraft.focusSeconds : 0
        let actualProgress: Int
        let focusSeconds: Int?

        switch activeMeasurement {
        case .checkbox:
            actualProgress = 1
            focusSeconds = nil
        case .focusBlocks:
            actualProgress = selectedTodo?.actualProgress ?? 0
            focusSeconds = currentFocusSeconds + addedFocusSeconds
        case .minutes:
            actualProgress = (selectedTodo?.actualProgress ?? 0) + addedFocusSeconds / 60
            focusSeconds = nil
        }

        return TodoProgressCalculator().summary(
            measurement: activeMeasurement,
            plannedAmount: activePlannedAmount,
            actualProgress: actualProgress,
            focusDurationSeconds: focusSeconds
        )
    }

    private var targetTint: Color {
        guard let selectedDirection, !DefaultDirections.isTaskInbox(selectedDirection) else {
            return .accentColor
        }
        return Color(hex: selectedDirection.colorHex)
    }

    private var targetText: String {
        switch measurement {
        case .checkbox:
            return ""
        case .focusBlocks:
            return "\(plannedAmount) \(String(localized: "ブロック"))"
        case .minutes:
            return "\(plannedAmount) \(String(localized: "分"))"
        }
    }

    private var manualModes: [FlowMode] {
        [.sprint, .twentyFiveFive, .fiftyTen]
    }

    private var checkboxRecordedAt: Date {
        guard !specifiesCheckTime else { return timeDraft.startedAt }
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: timeDraft.startedAt)
            ?? calendar.startOfDay(for: timeDraft.startedAt)
    }

    private func validateSelectionForCurrentDay() {
        switch selectedTarget {
        case let .todo(id):
            if !dayTodos.contains(where: { $0.id == id }) {
                selectedTarget = nil
            }
        case let .habit(directionID):
            if !habitOptions.contains(where: { $0.id == directionID }) {
                selectedTarget = nil
            }
        case .direction, .newTask, nil:
            break
        }
    }

    private func applyDefaultTargetIfNeeded() {
        guard selectedTarget == nil else { return }

        switch context {
        case .flow:
            if let direction = DefaultDirections.existingTaskInbox(in: availableDirections)
                ?? availableDirections.first {
                selectedTarget = .direction(direction.id)
            }
        case .task, .direction:
            break
        }
    }

    private func save() {
        errorMessage = nil
        let recordedAt = requiresFlow ? timeDraft.startedAt : checkboxRecordedAt

        do {
            switch selectedTarget {
            case let .todo(id):
                guard let todo = dayTodos.first(where: { $0.id == id }) else { return }
                if context == .flow {
                    guard let direction = todo.direction else { return }
                    editor.recordFlow(
                        todo: todo,
                        direction: direction,
                        recordedAt: recordedAt,
                        mode: mode,
                        focusSeconds: timeDraft.focusSeconds,
                        modelContext: modelContext
                    )
                } else {
                    try editor.record(
                        todo: todo,
                        recordedAt: recordedAt,
                        mode: mode,
                        focusSeconds: timeDraft.focusSeconds,
                        modelContext: modelContext
                    )
                }
            case let .habit(directionID):
                guard let option = habitOptions.first(where: { $0.id == directionID }) else { return }
                if let todo = option.todo {
                    if context == .flow {
                        editor.recordFlow(
                            todo: todo,
                            direction: option.direction,
                            recordedAt: recordedAt,
                            mode: mode,
                            focusSeconds: timeDraft.focusSeconds,
                            modelContext: modelContext
                        )
                    } else {
                        try editor.record(
                            todo: todo,
                            recordedAt: recordedAt,
                            mode: mode,
                            focusSeconds: timeDraft.focusSeconds,
                            modelContext: modelContext
                        )
                    }
                } else {
                    if context == .flow {
                        try editor.createHabitOccurrenceAndRecordFlow(
                            direction: option.direction,
                            scheduledDate: timeDraft.startedAt,
                            recordedAt: recordedAt,
                            mode: mode,
                            focusSeconds: timeDraft.focusSeconds,
                            modelContext: modelContext
                        )
                    } else {
                        try editor.createHabitOccurrenceAndRecord(
                            direction: option.direction,
                            scheduledDate: timeDraft.startedAt,
                            recordedAt: recordedAt,
                            mode: mode,
                            focusSeconds: timeDraft.focusSeconds,
                            modelContext: modelContext
                        )
                    }
                }
            case let .direction(directionID):
                guard let direction = availableDirections.first(where: { $0.id == directionID }) else { return }
                editor.record(
                    direction: direction,
                    recordedAt: timeDraft.startedAt,
                    mode: mode,
                    focusSeconds: timeDraft.focusSeconds,
                    modelContext: modelContext
                )
            case .newTask:
                guard let selectedDirection else { return }
                try editor.createAndRecord(
                    title: title,
                    direction: selectedDirection,
                    measurement: measurement,
                    priority: priority,
                    isRoomIfPossible: isRoomIfPossible,
                    plannedAmount: measurement == .checkbox ? nil : plannedAmount,
                    scheduledDate: timeDraft.startedAt,
                    recordedAt: recordedAt,
                    mode: mode,
                    focusSeconds: timeDraft.focusSeconds,
                    modelContext: modelContext
                )
            case nil:
                return
            }

            try modelContext.save()
            onDismiss()
        } catch let error as HistoryTaskRecordError {
            modelContext.rollback()
            errorMessage = error.localizedMessage
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "記録を保存できませんでした。")
        }
    }

    private func measurement(for goalUnit: GoalUnit) -> TodoMeasurement {
        switch goalUnit {
        case .occurrences:
            .checkbox
        case .focusBlocks:
            .focusBlocks
        case .minutes, .hours:
            .minutes
        }
    }

    private func plannedAmount(for goalUnit: GoalUnit, target: Int) -> Int? {
        switch goalUnit {
        case .occurrences:
            nil
        case .focusBlocks, .minutes:
            target
        case .hours:
            target * 60
        }
    }
}

enum HistoryRecordContext: Equatable {
    case flow
    case task
    case direction

    init(_ mode: DayHistoryMode) {
        switch mode {
        case .calendar:
            self = .flow
        case .tasks:
            self = .task
        case .directions:
            self = .direction
        }
    }

    var targetSectionTitle: String {
        switch self {
        case .flow, .task:
            String(localized: "タスク")
        case .direction:
            String(localized: "方向")
        }
    }

    var targetPickerLabel: String {
        switch self {
        case .flow:
            String(localized: "タスク・習慣・方向を選択")
        case .task:
            String(localized: "タスクを選択")
        case .direction:
            String(localized: "方向を選択")
        }
    }

    var emptyTargetTitle: String {
        switch self {
        case .flow:
            String(localized: "タスクなし")
        case .task:
            String(localized: "タスクを選択")
        case .direction:
            String(localized: "方向を選択")
        }
    }
}

private enum HistoryRecordTarget: Equatable {
    case todo(UUID)
    case habit(UUID)
    case direction(UUID)
    case newTask
}

private struct HistoryHabitOption: Identifiable {
    let direction: Direction
    let todo: Todo?

    var id: UUID { direction.id }
}

private enum HistoryRecordPickerTab: String, CaseIterable, Identifiable {
    case tasks
    case habits
    case directions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tasks:
            String(localized: "タスク")
        case .habits:
            String(localized: "習慣")
        case .directions:
            String(localized: "方向")
        }
    }
}

private struct HistoryRecordTargetPicker: View {
    let context: HistoryRecordContext
    let taskTodos: [Todo]
    let habitOptions: [HistoryHabitOption]
    let directions: [Direction]
    let selectedTarget: HistoryRecordTarget?
    let onSelect: (HistoryRecordTarget) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: HistoryRecordPickerTab

    init(
        context: HistoryRecordContext,
        taskTodos: [Todo],
        habitOptions: [HistoryHabitOption],
        directions: [Direction],
        selectedTarget: HistoryRecordTarget?,
        onSelect: @escaping (HistoryRecordTarget) -> Void
    ) {
        self.context = context
        self.taskTodos = taskTodos
        self.habitOptions = habitOptions
        self.directions = directions
        self.selectedTarget = selectedTarget
        self.onSelect = onSelect

        let initialTab: HistoryRecordPickerTab
        switch selectedTarget {
        case .habit:
            initialTab = .habits
        case .direction:
            initialTab = .directions
        case .todo, .newTask, nil:
            initialTab = context == .direction ? .directions : .tasks
        }
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "記録対象"))
                    .font(.headline)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if availableTabs.count > 1 {
                Picker(String(localized: "記録対象"), selection: $selectedTab) {
                    ForEach(availableTabs) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            ScrollView {
                switch selectedTab {
                case .tasks:
                    taskTab
                case .habits:
                    habitTab
                case .directions:
                    directionTab
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(16)
        .background(.bar)
    }

    private var availableTabs: [HistoryRecordPickerTab] {
        switch context {
        case .flow:
            [.tasks, .habits, .directions]
        case .task:
            [.tasks, .habits]
        case .direction:
            [.directions]
        }
    }

    private var taskTab: some View {
        VStack(spacing: 8) {
            if context == .task {
                targetRow(
                    emoji: "＋",
                    title: String(localized: "新しいタスク"),
                    subtitle: String(localized: "選択した日にタスクを作成"),
                    tint: .accentColor,
                    isSelected: selectedTarget == .newTask
                ) {
                    onSelect(.newTask)
                }
            }

            if taskTodos.isEmpty {
                emptyState(String(localized: "この日のタスクはありません"))
            } else {
                ForEach(taskTodos) { todo in
                    targetRow(
                        emoji: todo.direction?.symbolName ?? DefaultDirections.taskInboxSymbol,
                        title: TodoDisplay.title(for: todo),
                        subtitle: todo.direction?.name ?? String(localized: "その他"),
                        tint: directionColor(todo.direction),
                        isSelected: selectedTarget == .todo(todo.id)
                    ) {
                        onSelect(.todo(todo.id))
                    }
                }
            }
        }
    }

    private var habitTab: some View {
        VStack(spacing: 8) {
            if habitOptions.isEmpty {
                emptyState(String(localized: "この日の習慣はありません"))
            } else {
                ForEach(habitOptions) { option in
                    targetRow(
                        emoji: option.direction.symbolName,
                        title: TodoDisplay.title(for: option.todo, direction: option.direction),
                        subtitle: habitSubtitle(option),
                        tint: directionColor(option.direction),
                        isSelected: selectedTarget == .habit(option.id)
                    ) {
                        onSelect(.habit(option.id))
                    }
                }
            }
        }
    }

    private var directionTab: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 120, maximum: 170), spacing: 10)],
            spacing: 10
        ) {
            ForEach(directions) { direction in
                Button {
                    onSelect(.direction(direction.id))
                } label: {
                    VStack(spacing: 8) {
                        Text(direction.symbolName)
                            .font(.system(size: 28))
                            .frame(width: 46, height: 46)
                            .background(directionColor(direction).opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text(direction.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(height: 32, alignment: .top)
                    }
                    .frame(maxWidth: .infinity, minHeight: 92)
                    .padding(8)
                    .background(
                        selectedTarget == .direction(direction.id)
                            ? directionColor(direction).opacity(0.14)
                            : Color.primary.opacity(0.05)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                selectedTarget == .direction(direction.id)
                                    ? directionColor(direction).opacity(0.65)
                                    : .clear,
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func targetRow(
        emoji: String,
        title: String,
        subtitle: String,
        tint: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(emoji)
                    .font(.title3)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .padding(10)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func habitSubtitle(_ option: HistoryHabitOption) -> String {
        guard let todo = option.todo else {
            return String(localized: "この日に記録なし")
        }
        return TodoProgressCalculator().summary(
            measurement: todo.measurement,
            plannedAmount: todo.plannedAmount,
            actualProgress: todo.actualProgress,
            focusDurationSeconds: todo.recordedFocusSeconds
        )
    }

    private func directionColor(_ direction: Direction?) -> Color {
        guard let direction, !DefaultDirections.isTaskInbox(direction) else {
            return .secondary
        }
        return Color(hex: direction.colorHex)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 220)
    }
}

private struct HistoryRecordProgressPreview: View {
    let measurement: TodoMeasurement
    let plannedAmount: Int?
    let currentFocusSeconds: Int
    let currentActualProgress: Int
    let addedFocusSeconds: Int
    let tint: Color

    var body: some View {
        ZStack {
            switch measurement {
            case .checkbox:
                RoundedRectangle(cornerRadius: 5)
                    .fill(tint)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
            case .focusBlocks:
                Circle()
                    .stroke(tint.opacity(0.22), lineWidth: 3)
                    .overlay {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
            case .minutes:
                Circle()
                    .fill(tint.opacity(0.16))
                    .overlay {
                        HistoryRecordProgressPie(progress: progress)
                            .fill(tint)
                    }
                    .overlay {
                        Image(systemName: "timer")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(progress > 0.52 ? Color.white : tint)
                    }
            }
        }
        .frame(width: 22, height: 22)
        .frame(width: 34, height: 34)
        .accessibilityHidden(true)
    }

    private var progress: Double {
        switch measurement {
        case .checkbox:
            return 1
        case .focusBlocks:
            guard let plannedAmount, plannedAmount > 0 else { return 0 }
            return min(
                BlockUnit.blocks(forFocusedSeconds: currentFocusSeconds + addedFocusSeconds)
                    / Double(plannedAmount),
                1
            )
        case .minutes:
            guard let plannedAmount, plannedAmount > 0 else { return 0 }
            let actualMinutes = currentActualProgress + addedFocusSeconds / 60
            return min(Double(actualMinutes) / Double(plannedAmount), 1)
        }
    }
}

private struct HistoryRecordProgressPie: Shape {
    let progress: Double

    func path(in rect: CGRect) -> Path {
        let value = min(max(progress, 0), 1)
        guard value > 0 else { return Path() }
        if value >= 1 { return Path(ellipseIn: rect) }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * value),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

private extension TodoDisplay {
    static func title(for todo: Todo?, direction: Direction) -> String {
        guard let todo else { return "(\(direction.name))" }
        return title(for: todo)
    }
}

private extension HistoryTaskRecordError {
    var localizedMessage: String {
        switch self {
        case .emptyTitle:
            return String(localized: "タスク名を入力してください。")
        case .invalidPlannedAmount:
            return String(localized: "目標値は1以上にしてください。")
        case .missingDirection:
            return String(localized: "方向を選択してください。")
        }
    }
}
