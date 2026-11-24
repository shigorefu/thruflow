//
//  HistoryTaskRecordForm.swift
//  ThruFlow
//
//

#if os(macOS) || os(iOS)
import SwiftData
import SwiftUI

struct HistoryTaskRecordForm: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Area.sortIndex) private var areas: [Area]
    @Query(sort: \Todo.updatedAt, order: .reverse) private var todos: [Todo]

    let context: HistoryRecordContext
    let onDismiss: () -> Void

    @State private var selectedTarget: HistoryRecordTarget?
    @State private var isChoosingTarget = false
    @State private var title = ""
    @State private var selectedAreaID: UUID?
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
                if newTarget == .newTask, selectedAreaID == nil {
                    selectedAreaID = (
                        DefaultAreas.existingTaskInbox(in: availableAreas)
                            ?? availableAreas.first
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

    private var availableAreas: [Area] {
        areas.filter { !$0.isArchived }
    }

    private var dayTodos: [Todo] {
        editor.availableTodos(on: timeDraft.startedAt, from: todos)
    }

    private var taskTodos: [Todo] {
        dayTodos.filter { $0.taskType != .habit }
    }

    private var habitOptions: [HistoryHabitOption] {
        let existingByArea = Dictionary(
            dayTodos
                .filter { $0.taskType == .habit }
                .compactMap { todo -> (UUID, Todo)? in
                    guard let areaID = todo.area?.id else { return nil }
                    return (areaID, todo)
                },
            uniquingKeysWith: { current, _ in current }
        )

        return availableAreas
            .filter { area in
                area.type == .habit
                    && area.goalUnit != nil
                    && (
                        existingByArea[area.id] != nil
                            || RequiredTodoPlanner(calendar: calendar).shouldAppearToday(
                                area,
                                on: dayBoundary.day(containing: timeDraft.startedAt, calendar: calendar)
                            )
                    )
            }
            .map { area in
                HistoryHabitOption(
                    area: area,
                    todo: existingByArea[area.id]
                )
            }
    }

    private var selectedTodo: Todo? {
        switch selectedTarget {
        case let .todo(id):
            return dayTodos.first { $0.id == id }
        case let .habit(areaID):
            return habitOptions.first { $0.id == areaID }?.todo
        case .area, .newTask, nil:
            return nil
        }
    }

    private var selectedArea: Area? {
        switch selectedTarget {
        case let .todo(id):
            return dayTodos.first { $0.id == id }?.area
        case let .habit(id), let .area(id):
            return availableAreas.first { $0.id == id }
        case .newTask:
            guard let selectedAreaID else { return nil }
            return availableAreas.first { $0.id == selectedAreaID }
        case nil:
            return nil
        }
    }

    private var activeMeasurement: TodoMeasurement? {
        if let selectedTodo {
            return selectedTodo.measurement
        }

        switch selectedTarget {
        case let .habit(areaID):
            guard let area = availableAreas.first(where: { $0.id == areaID }),
                  let goalUnit = area.goalUnit else {
                return nil
            }
            return measurement(for: goalUnit)
        case .newTask:
            return measurement
        case .todo, .area, nil:
            return nil
        }
    }

    private var activePlannedAmount: Int? {
        if let selectedTodo {
            return selectedTodo.plannedAmount
        }

        switch selectedTarget {
        case let .habit(areaID):
            guard let area = availableAreas.first(where: { $0.id == areaID }),
                  let goalUnit = area.goalUnit else {
                return nil
            }
            return plannedAmount(for: goalUnit, target: max(1, area.goalTarget ?? 1))
        case .newTask:
            return measurement == .checkbox ? nil : plannedAmount
        case .todo, .area, nil:
            return nil
        }
    }

    private var requiresFlow: Bool {
        if context != .task {
            return selectedTarget != nil
        }
        if case .area = selectedTarget {
            return true
        }
        guard let activeMeasurement else { return false }
        return activeMeasurement != .checkbox
    }

    private var canSave: Bool {
        guard selectedTarget != nil else { return false }

        if context == .flow {
            return selectedArea != nil && selectedTarget != .newTask
        }

        if context == .area {
            guard case .area = selectedTarget else { return false }
            return selectedArea != nil
        }

        if selectedTarget == .newTask {
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && selectedArea != nil
                && (measurement == .checkbox || plannedAmount > 0)
        }

        return selectedArea != nil
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

                    Text(selectedArea?.symbolName ?? "＋")
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
                areas: availableAreas,
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
        Section(String(localized: "対象タスク")) {
            TextField(String(localized: "タスク名"), text: $title, axis: .vertical)
                .lineLimit(1...3)

            Picker(String(localized: "分野"), selection: $selectedAreaID) {
                ForEach(availableAreas) { area in
                    Text("\(area.symbolName) \(area.name)")
                        .tag(Optional(area.id))
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
        case let .habit(areaID):
            guard let area = availableAreas.first(where: { $0.id == areaID }) else {
                return String(localized: "習慣")
            }
            return "(\(area.name))"
        case let .area(areaID):
            if context == .flow {
                return String(localized: "タスクなし")
            }
            guard let area = availableAreas.first(where: { $0.id == areaID }) else {
                return String(localized: "分野")
            }
            return "(\(area.name))"
        case .newTask:
            let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? String(localized: "新しいタスク") : normalized
        case .todo:
            return String(localized: "対象タスク")
        case nil:
            return context.emptyTargetTitle
        }
    }

    private var targetSubtitle: String? {
        guard selectedTarget != nil else { return nil }

        switch selectedTarget {
        case .habit:
            return selectedArea?.name ?? String(localized: "習慣")
        case .area:
            return String(localized: "タスクなし")
        case .todo, .newTask:
            return selectedArea?.name ?? String(localized: "その他")
        case nil:
            return nil
        }
    }

    private var targetProgressText: String? {
        guard let activeMeasurement else { return nil }
        if activeMeasurement == .checkbox {
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
        guard let selectedArea, !DefaultAreas.isTaskInbox(selectedArea) else {
            return .accentColor
        }
        return Color(hex: selectedArea.colorHex)
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
        case let .habit(areaID):
            if !habitOptions.contains(where: { $0.id == areaID }) {
                selectedTarget = nil
            }
        case .area, .newTask, nil:
            break
        }
    }

    private func applyDefaultTargetIfNeeded() {
        guard selectedTarget == nil else { return }

        switch context {
        case .flow:
            if let area = DefaultAreas.existingTaskInbox(in: availableAreas)
                ?? availableAreas.first {
                selectedTarget = .area(area.id)
            }
        case .task, .area:
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
                    guard let area = todo.area else { return }
                    try editor.recordFlow(
                        todo: todo,
                        area: area,
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
            case let .habit(areaID):
                guard let option = habitOptions.first(where: { $0.id == areaID }) else { return }
                if let todo = option.todo {
                    if context == .flow {
                        try editor.recordFlow(
                            todo: todo,
                            area: option.area,
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
                            area: option.area,
                            scheduledDate: timeDraft.startedAt,
                            recordedAt: recordedAt,
                            mode: mode,
                            focusSeconds: timeDraft.focusSeconds,
                            modelContext: modelContext
                        )
                    } else {
                        try editor.createHabitOccurrenceAndRecord(
                            area: option.area,
                            scheduledDate: timeDraft.startedAt,
                            recordedAt: recordedAt,
                            mode: mode,
                            focusSeconds: timeDraft.focusSeconds,
                            modelContext: modelContext
                        )
                    }
                }
            case let .area(areaID):
                guard let area = availableAreas.first(where: { $0.id == areaID }) else { return }
                try editor.record(
                    area: area,
                    recordedAt: timeDraft.startedAt,
                    mode: mode,
                    focusSeconds: timeDraft.focusSeconds,
                    modelContext: modelContext
                )
            case .newTask:
                guard let selectedArea else { return }
                try editor.createAndRecord(
                    title: title,
                    area: selectedArea,
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
            PersistenceIssueCenter.shared.report(error, operation: .historyUpdate)
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

private extension HistoryTaskRecordError {
    var localizedMessage: String {
        switch self {
        case .emptyTitle:
            return String(localized: "タスク名を入力してください。")
        case .invalidPlannedAmount:
            return String(localized: "目標値は1以上にしてください。")
        case .missingArea:
            return String(localized: "方向を選択してください。")
        }
    }
}
#endif
