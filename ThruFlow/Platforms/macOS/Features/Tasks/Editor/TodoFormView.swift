//
//  TodoFormView.swift
//  ThruFlow
//
//

import SwiftData
import SwiftUI

struct TodoFormView: View {
    enum Mode {
        case create
        case edit(Todo)

        var title: String {
            switch self {
            case .create:
                String(localized: "新しいタスク")
            case .edit:
                String(localized: "タスクを編集")
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: \Area.name, order: .forward) private var areas: [Area]

    let mode: Mode
    private let fixedArea: Area?
    private let onSave: ((Todo) -> Void)?

    @State private var draft: TodoDraft
    @State private var hashtagsText: String
    @State private var selectedAreaID: UUID?
    @State private var usesScheduledDate: Bool
    @State private var usesDeadline: Bool
    @State private var validationErrors: [TodoValidationError] = []
    @State private var saveErrorMessage: String?
    @FocusState private var isTitleFocused: Bool

    private let editingService = TaskEditingService()
    private let controlColumnWidth: CGFloat = 290

    private var activeAreas: [Area] {
        areas.filter { !$0.isArchived }
    }

    private var visibleAreas: [Area] {
        var result = activeAreas.filter { !DefaultAreas.isTaskInbox($0) }
        if let currentArea = editedTodo?.area,
           !result.contains(where: { $0.id == currentArea.id }) {
            result.append(currentArea)
        }
        return result
    }

    private var editedTodo: Todo? {
        if case .edit(let todo) = mode {
            return todo
        }

        return nil
    }

    private var isHabitTodoEdit: Bool {
        editedTodo?.taskType == .habit
    }

    init(
        mode: Mode,
        fixedArea: Area? = nil,
        project: Project? = nil,
        scheduledDate: Date? = nil,
        onSave: ((Todo) -> Void)? = nil
    ) {
        self.mode = mode
        self.fixedArea = fixedArea
        self.onSave = onSave

        switch mode {
        case .create:
            var draft = TodoDraft()
            draft.area = fixedArea ?? project?.area
            draft.project = project
            draft.scheduledDate = scheduledDate ?? .now
            _draft = State(initialValue: draft)
            _hashtagsText = State(initialValue: draft.hashtags.map { "#\($0)" }.joined(separator: " "))
            _selectedAreaID = State(initialValue: draft.area?.id)
            _usesScheduledDate = State(initialValue: true)
            _usesDeadline = State(initialValue: false)
        case .edit(let todo):
            let draft = TodoDraft(todo: todo)
            _draft = State(initialValue: draft)
            _hashtagsText = State(initialValue: draft.hashtags.map { "#\($0)" }.joined(separator: " "))
            _selectedAreaID = State(initialValue: todo.area?.id)
            _usesScheduledDate = State(initialValue: todo.scheduledDate != nil)
            _usesDeadline = State(initialValue: todo.deadline != nil)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    taskTitleRow
                    if let todo = editedTodo, todo.externalTaskLinkRawValue != nil {
                        ExternalTaskSourceLink(todo: todo)
                    }
                    classificationCard
                    scheduleCard
                    TodoNotesCard(notes: $draft.notes, hashtagsText: $hashtagsText)
                    validationCard
                }
                .padding(16)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle(mode.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "キャンセル")) {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "保存"), action: save)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(minWidth: 580, idealWidth: 620, minHeight: 520, idealHeight: 650)
        .onAppear {
            selectInitialAreaIfNeeded()
            isTitleFocused = true
        }
        .taskTimingDefaults(timeMinutes: $draft.scheduledTimeMinutes, reminderEnabled: $draft.reminderEnabled)
        .onChange(of: usesScheduledDate) { _, hasDate in
            if hasDate {
                draft.scheduledDate = draft.scheduledDate ?? .now
            } else {
                draft.scheduledTimeMinutes = nil
                draft.reminderEnabled = false
            }
        }
        .onChange(of: draft.measurement) { _, measurement in
            if measurement != .checkbox, draft.plannedAmount == nil {
                draft.plannedAmount = 1
            }
        }
    }

    private var taskTitleRow: some View {
        HStack(spacing: 12) {
            Text(selectedArea?.symbolName ?? "📝")
                .font(.system(size: 24))
                .frame(width: 40, height: 40)
                .background(editorTint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            TextField(String(localized: "タスク名"), text: $draft.title)
                .font(.title3.weight(.semibold))
                .textFieldStyle(.roundedBorder)
                .focused($isTitleFocused)
                .accessibilityLabel(String(localized: "タスク名"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }

    private var classificationCard: some View {
        TodoEditorCard(title: String(localized: "基本")) {
            editorRow(
                title: String(localized: "分野"),
                systemImage: ProductSymbol.area
            ) {
                areaControl
            }

            if !isHabitTodoEdit {
                TaskProjectPicker(
                    area: selectedArea,
                    selection: $draft.project,
                    currentProject: editedTodo?.project,
                    showsDivider: true,
                    animatesVisibility: true
                )
            }

            Divider()

            if isHabitTodoEdit {
                readOnlyMeasurementRow
            } else {
                editorRow(title: String(localized: "種類"), systemImage: "square.stack.3d.up") {
                    Picker(String(localized: "種類"), selection: $draft.measurement) {
                        ForEach(TodoMeasurement.allCases) { measurement in
                            Label(measurement.displayName, systemImage: measurement.editorSymbolName)
                                .tag(measurement)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel(String(localized: "種類"))
                }
            }

            if draft.measurement != .checkbox {
                Group {
                    Divider()
                    progressControls
                }
                .transition(.opacity)
            }

            if !isHabitTodoEdit {
                Divider()
                priorityControls
            }
        }
        .animation(fieldVisibilityAnimation, value: draft.measurement != .checkbox)
    }

    private var scheduleCard: some View {
        TodoEditorCard(title: isHabitTodoEdit ? String(localized: "時刻") : String(localized: "日付")) {
            if !isHabitTodoEdit {
                dateControlRow(
                    title: String(localized: "予定日"),
                    systemImage: "calendar",
                    isEnabled: $usesScheduledDate,
                    selection: scheduledDateBinding
                )

                Divider()
            }

            TaskTimingControls(
                scheduledDate: usesScheduledDate ? draft.scheduledDate : nil,
                timeMinutes: $draft.scheduledTimeMinutes,
                reminderEnabled: $draft.reminderEnabled,
                showsTrailingTimeSwitch: true,
                animatesVisibility: true
            )

            if !isHabitTodoEdit {
                Divider()

                dateControlRow(
                    title: String(localized: "期限"),
                    systemImage: "calendar.badge.exclamationmark",
                    isEnabled: $usesDeadline,
                    selection: deadlineBinding
                )
            }
        }
    }

    @ViewBuilder
    private var validationCard: some View {
        if !validationErrors.isEmpty || saveErrorMessage != nil {
            TodoEditorCard {
                ForEach(validationErrors, id: \.self) { error in
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
                if let saveErrorMessage {
                    Label(saveErrorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    @ViewBuilder
    private var areaControl: some View {
        if let fixedArea {
            readOnlyValue(
                "\(fixedArea.symbolName) \(fixedArea.name)",
                tint: Color(hex: fixedArea.colorHex)
            )
        } else if isHabitTodoEdit, let area = editedTodo?.area {
            readOnlyValue(
                "\(area.symbolName) \(TodoDisplay.flowContextName(for: editedTodo, area: area))",
                tint: Color(hex: area.colorHex)
            )
        } else {
            Picker(String(localized: "分野"), selection: selectedAreaBinding) {
                Text(String(localized: "未選択")).tag(UUID?.none)

                ForEach(visibleAreas) { area in
                    Text("\(area.symbolName) \(area.name)")
                        .tag(Optional(area.id))
                }
            }
            .labelsHidden()
            .accessibilityLabel(String(localized: "分野"))
        }
    }

    private var readOnlyMeasurementRow: some View {
        editorRow(
            title: String(localized: "種類"),
            systemImage: draft.measurement.editorSymbolName
        ) {
            readOnlyValue(draft.measurement.displayName, tint: editorTint)
        }
    }

    private var progressControls: some View {
        HStack(alignment: .center, spacing: 28) {
            if isHabitTodoEdit {
                metricControl(
                    title: String(localized: "目標"),
                    value: draft.plannedAmount ?? 1,
                    range: 1...999,
                    isEditable: false,
                    binding: plannedAmountBinding
                )
            } else {
                metricControl(
                    title: String(localized: "目標"),
                    value: draft.plannedAmount ?? 1,
                    range: 1...999,
                    isEditable: true,
                    binding: plannedAmountBinding
                )
            }

            metricControl(
                title: String(localized: "進捗"),
                value: draft.actualProgress,
                range: 0...999,
                isEditable: true,
                binding: actualProgressBinding
            )

            Spacer(minLength: 0)
        }
    }

    private var priorityControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            editorRow(title: String(localized: "優先度"), systemImage: "flag") {
                Picker(String(localized: "優先度"), selection: $draft.priority) {
                    ForEach(TodoPriority.allCases) { priority in
                        Text(priority.displayName).tag(priority)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel(String(localized: "優先度"))
            }

            if draft.priority == .low {
                Toggle(String(localized: "余裕があれば"), isOn: $draft.isRoomIfPossible)
                    .toggleStyle(.switch)
                    .transition(.opacity)
            }
        }
        .animation(fieldVisibilityAnimation, value: draft.priority == .low)
    }

    private var fieldVisibilityAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.18)
    }

    private var selectedArea: Area? {
        fixedArea ?? area(for: selectedAreaID) ?? editedTodo?.area
    }

    private var editorTint: Color {
        guard let selectedArea else { return .secondary }
        return Color(hex: selectedArea.colorHex)
    }

    private var measurementUnit: String {
        switch draft.measurement {
        case .checkbox:
            ""
        case .focusBlocks:
            String(localized: "ブロック")
        case .minutes:
            String(localized: "分")
        }
    }

    private func editorRow<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))

            Spacer(minLength: 20)
            content()
                .frame(width: controlColumnWidth, alignment: .trailing)
        }
    }

    private func dateControlRow(
        title: String,
        systemImage: String,
        isEnabled: Binding<Bool>,
        selection: Binding<Date>
    ) -> some View {
        editorRow(title: title, systemImage: systemImage) {
            HStack(spacing: 10) {
                if isEnabled.wrappedValue {
                    DatePicker(title, selection: selection, displayedComponents: .date)
                        .datePickerStyle(.field)
                        .labelsHidden()
                        .fixedSize()
                        .transition(.opacity)
                }

                Toggle(title, isOn: isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .animation(fieldVisibilityAnimation, value: isEnabled.wrappedValue)
        }
    }

    private func metricControl(
        title: String,
        value: Int,
        range: ClosedRange<Int>,
        isEditable: Bool,
        binding: Binding<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 7) {
                if isEditable {
                    TextField(title, value: binding, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 58)

                    Stepper(title, value: binding, in: range)
                        .labelsHidden()
                        .fixedSize()
                } else {
                    Text(value.formatted())
                        .font(.body.monospacedDigit().weight(.semibold))
                }

                Text(measurementUnit)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func readOnlyValue(_ value: String, tint: Color) -> some View {
        Text(value)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var selectedAreaBinding: Binding<UUID?> {
        Binding(
            get: { selectedAreaID },
            set: {
                if selectedAreaID != $0 { draft.project = nil }
                selectedAreaID = $0
                draft.area = area(for: $0)
            }
        )
    }

    private var plannedAmountBinding: Binding<Int> {
        Binding(
            get: { draft.plannedAmount ?? 1 },
            set: { draft.plannedAmount = $0 }
        )
    }

    private var actualProgressBinding: Binding<Int> {
        Binding(
            get: { draft.actualProgress },
            set: { draft.actualProgress = $0 }
        )
    }

    private var scheduledDateBinding: Binding<Date> {
        Binding(
            get: { draft.scheduledDate ?? .now },
            set: { draft.scheduledDate = $0 }
        )
    }

    private var deadlineBinding: Binding<Date> {
        Binding(
            get: { draft.deadline ?? .now },
            set: { draft.deadline = $0 }
        )
    }

    private func selectInitialAreaIfNeeded() {
        if let fixedArea {
            selectedAreaID = fixedArea.id
            draft.area = fixedArea
        } else if draft.area == nil {
            draft.area = area(for: selectedAreaID)
        }
    }

    private func area(for id: UUID?) -> Area? {
        guard let id else { return nil }
        return visibleAreas.first { $0.id == id }
    }

    private func save() {
        saveErrorMessage = nil
        draft.hashtags = TodoHashtagNormalizer.normalize(
            hashtagsText.split(whereSeparator: { $0.isWhitespace || $0 == "," }).map(String.init)
        )
        if !isHabitTodoEdit {
            draft.area = fixedArea ?? area(for: selectedAreaID)
            draft.scheduledDate = usesScheduledDate ? draft.scheduledDate ?? .now : nil
            draft.deadline = usesDeadline ? draft.deadline ?? .now : nil
        }

        validationErrors = editingService.validationErrors(for: draft, editing: editedTodo)
        guard validationErrors.isEmpty else { return }

        do {
            let todo = try editingService.save(
                draft: draft,
                editing: editedTodo,
                modelContext: modelContext
            )
            onSave?(todo)
            dismiss()
        } catch TaskEditingError.validation(let errors) {
            validationErrors = errors
        } catch {
            saveErrorMessage = String(localized: "記録を保存できませんでした。")
        }
    }


}

private extension TodoMeasurement {
    var editorSymbolName: String {
        switch self {
        case .checkbox:
            "checkmark.square"
        case .focusBlocks:
            "circle"
        case .minutes:
            "timer"
        }
    }
}

#Preview("Create Task") {
    TodoFormView(mode: .create)
        .modelContainer(for: [Area.self, Todo.self], inMemory: true)
}
