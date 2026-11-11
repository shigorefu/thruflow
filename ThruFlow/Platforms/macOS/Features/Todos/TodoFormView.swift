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
    @State private var showsAreaPicker = false
    @State private var usesScheduledDate: Bool
    @State private var usesDeadline: Bool
    @State private var validationErrors: [TodoValidationError] = []
    @State private var saveErrorMessage: String?
    @FocusState private var isTitleFocused: Bool

    private let editingService = TaskEditingService()

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
            VStack(spacing: 0) {
                taskTitleRow
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                Form {
                    Section {
                        areaControl
                        TextField(String(localized: "メモ"), text: $draft.notes, axis: .vertical)
                            .lineLimit(2...5)
                        TextField(String(localized: "ハッシュタグ"), text: $hashtagsText)
                        if let todo = editedTodo, todo.externalTaskLinkRawValue != nil {
                            ExternalTaskSourceLink(todo: todo)
                        }
                    }

                    classificationSection
                    scheduleSection
                    validationSection
                }
                .formStyle(.grouped)
            }
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
        HStack(spacing: 14) {
            areaBadgeControl

            TextField(String(localized: "タスク名"), text: $draft.title)
                .font(.title2.weight(.semibold))
                .textFieldStyle(.plain)
                .focused($isTitleFocused)
                .accessibilityLabel(String(localized: "タスク名"))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var areaBadgeControl: some View {
        if fixedArea != nil || (isHabitTodoEdit && editedTodo?.area != nil) {
            areaBadge.accessibilityHidden(true)
        } else {
            Button {
                showsAreaPicker = true
            } label: {
                areaBadge
            }
            .buttonStyle(.plain)
            .help(selectedArea?.name ?? String(localized: "未選択"))
            .accessibilityLabel(String(localized: "分野"))
            .accessibilityValue(selectedArea?.name ?? String(localized: "未選択"))
            .popover(isPresented: $showsAreaPicker, arrowEdge: .bottom) {
                areaPickerPopover
            }
        }
    }

    @ViewBuilder
    private var areaControl: some View {
        if let fixedArea {
            LabeledContent(String(localized: "分野"), value: "\(fixedArea.symbolName) \(fixedArea.name)")
        } else if isHabitTodoEdit, let area = editedTodo?.area {
            LabeledContent(
                String(localized: "分野"),
                value: "\(area.symbolName) \(TodoDisplay.flowContextName(for: editedTodo, area: area))"
            )
        } else {
            Picker(String(localized: "分野"), selection: selectedAreaBinding) {
                Text(String(localized: "未選択")).tag(UUID?.none)

                ForEach(visibleAreas) { area in
                    Text("\(area.symbolName) \(area.name)").tag(Optional(area.id))
                }
            }
        }
    }

    private var areaPickerPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "分野"))
                    .font(.headline.weight(.semibold))

                Spacer(minLength: 0)

                Button {
                    showsAreaPicker = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(String(localized: "閉じる"))
            }

            ScrollView {
                MacAreaPickerGrid(
                    areas: visibleAreas,
                    defaultArea: nil,
                    defaultTitle: String(localized: "未選択"),
                    defaultSymbol: "📝",
                    selectedAreaID: selectedAreaID
                ) { area in
                    selectedAreaBinding.wrappedValue = area?.id
                    showsAreaPicker = false
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(14)
        .frame(width: 420, height: 340)
        .background(.bar)
    }

    private var areaBadge: some View {
        Text(selectedArea?.symbolName ?? "📝")
            .font(.system(size: 30))
            .frame(width: 52, height: 52)
            .background(editorTint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
    }

    private var classificationSection: some View {
        Section(String(localized: "基本")) {
            if isHabitTodoEdit {
                LabeledContent(String(localized: "種類"), value: draft.measurement.displayName)
            } else {
                TaskProjectPicker(
                    area: selectedArea,
                    selection: $draft.project,
                    currentProject: editedTodo?.project,
                    animatesVisibility: true
                )

                Picker(String(localized: "種類"), selection: $draft.measurement) {
                    ForEach(TodoMeasurement.allCases) { measurement in
                        Label(measurement.displayName, systemImage: measurement.editorSymbolName)
                            .tag(measurement)
                    }
                }
                .pickerStyle(.segmented)
            }

            if draft.measurement != .checkbox {
                progressRows
            }

            if !isHabitTodoEdit {
                Picker(String(localized: "優先度"), selection: $draft.priority) {
                    ForEach(TodoPriority.allCases) { priority in
                        Text(priority.displayName).tag(priority)
                    }
                }
                .pickerStyle(.segmented)

                if draft.priority == .low {
                    Toggle(String(localized: "余裕があれば"), isOn: $draft.isRoomIfPossible)
                        .toggleStyle(.switch)
                        .transition(.opacity)
                }
            }
        }
        .animation(fieldVisibilityAnimation, value: draft.measurement != .checkbox)
        .animation(fieldVisibilityAnimation, value: draft.priority == .low)
    }

    private var scheduleSection: some View {
        Section(isHabitTodoEdit ? String(localized: "時刻") : String(localized: "日付")) {
            if !isHabitTodoEdit {
                dateControlRow(
                    title: String(localized: "予定日"),
                    systemImage: "calendar",
                    isEnabled: $usesScheduledDate,
                    selection: scheduledDateBinding
                )
            }

            TaskTimingControls(
                scheduledDate: usesScheduledDate ? draft.scheduledDate : nil,
                timeMinutes: $draft.scheduledTimeMinutes,
                reminderEnabled: $draft.reminderEnabled,
                showsTrailingTimeSwitch: true,
                animatesVisibility: true
            )

            if !isHabitTodoEdit {
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
    private var validationSection: some View {
        if !validationErrors.isEmpty || saveErrorMessage != nil {
            Section {
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
    private var progressRows: some View {
        if isHabitTodoEdit {
            LabeledContent(
                String(localized: "目標"),
                value: "\((draft.plannedAmount ?? 1).formatted()) \(measurementUnit)"
            )
            .transition(.opacity)
        } else {
            metricRow(title: String(localized: "目標"), binding: plannedAmountBinding, range: 1...999)
                .transition(.opacity)
        }

        metricRow(title: String(localized: "進捗"), binding: actualProgressBinding, range: 0...999)
            .transition(.opacity)
    }

    private var fieldVisibilityAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.18)
    }

    private var selectedArea: Area? {
        fixedArea ?? area(for: selectedAreaID)
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

    private func dateControlRow(
        title: String,
        systemImage: String,
        isEnabled: Binding<Bool>,
        selection: Binding<Date>
    ) -> some View {
        LabeledContent {
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
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    private func metricRow(title: String, binding: Binding<Int>, range: ClosedRange<Int>) -> some View {
        LabeledContent(title) {
            HStack(spacing: 7) {
                TextField(title, value: binding, format: .number)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 58)

                Stepper(title, value: binding, in: range)
                    .labelsHidden()
                    .fixedSize()

                Text(measurementUnit)
                    .foregroundStyle(.secondary)
            }
        }
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
