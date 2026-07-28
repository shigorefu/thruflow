//
//  TodoFormView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
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

    @Query(sort: \Direction.name, order: .forward) private var directions: [Direction]

    let mode: Mode
    private let fixedDirection: Direction?
    private let onSave: ((Todo) -> Void)?

    @State private var draft: TodoDraft
    @State private var selectedDirectionID: UUID?
    @State private var usesScheduledDate: Bool
    @State private var usesDeadline: Bool
    @State private var validationErrors: [TodoValidationError] = []
    @FocusState private var isTitleFocused: Bool

    private let validator = TodoValidator()

    private var activeDirections: [Direction] {
        directions.filter { !$0.isArchived }
    }

    private var visibleDirections: [Direction] {
        activeDirections.filter { !DefaultDirections.isTaskInbox($0) }
    }

    private var editedTodo: Todo? {
        if case .edit(let todo) = mode {
            return todo
        }

        return nil
    }

    private var isHabitTodoEdit: Bool {
        editedTodo?.direction?.type == .habit
    }

    init(
        mode: Mode,
        fixedDirection: Direction? = nil,
        scheduledDate: Date? = nil,
        onSave: ((Todo) -> Void)? = nil
    ) {
        self.mode = mode
        self.fixedDirection = fixedDirection
        self.onSave = onSave

        switch mode {
        case .create:
            var draft = TodoDraft()
            draft.direction = fixedDirection
            draft.scheduledDate = scheduledDate ?? .now
            _draft = State(initialValue: draft)
            _selectedDirectionID = State(initialValue: fixedDirection?.id)
            _usesScheduledDate = State(initialValue: true)
            _usesDeadline = State(initialValue: false)
        case .edit(let todo):
            let draft = TodoDraft(todo: todo)
            _draft = State(initialValue: draft)
            _selectedDirectionID = State(initialValue: todo.direction?.id)
            _usesScheduledDate = State(initialValue: todo.scheduledDate != nil)
            _usesDeadline = State(initialValue: todo.deadline != nil)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    taskContentCard
                    classificationCard

                    if !isHabitTodoEdit {
                        scheduleCard
                    }

                    validationCard
                }
                .padding(24)
                .frame(maxWidth: 680)
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
        .frame(minWidth: 620, idealWidth: 680, minHeight: 620, idealHeight: 700)
        .onAppear {
            selectInitialDirectionIfNeeded()
            isTitleFocused = true
        }
        .onChange(of: draft.measurement) { _, measurement in
            if measurement != .checkbox, draft.plannedAmount == nil {
                draft.plannedAmount = 1
            }
        }
    }

    private var taskContentCard: some View {
        TodoEditorCard {
            HStack(alignment: .center, spacing: 14) {
                Text(selectedDirection?.symbolName ?? "📝")
                    .font(.system(size: 30))
                    .frame(width: 52, height: 52)
                    .background(editorTint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                TextField(String(localized: "タスク名"), text: $draft.title)
                    .font(.title2.weight(.semibold))
                    .textFieldStyle(.plain)
                    .focused($isTitleFocused)
                    .accessibilityLabel(String(localized: "タスク名"))
            }

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                Label(String(localized: "メモ"), systemImage: "note.text")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField(String(localized: "メモ"), text: $draft.notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }

            VStack(alignment: .leading, spacing: 7) {
                Label(String(localized: "ハッシュタグ"), systemImage: "number")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField(String(localized: "ハッシュタグ"), text: hashtagsBinding)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var classificationCard: some View {
        TodoEditorCard(title: String(localized: "基本")) {
            editorRow(
                title: String(localized: "方向"),
                systemImage: "point.3.connected.trianglepath.dotted"
            ) {
                directionControl
            }

            Divider()

            if isHabitTodoEdit {
                readOnlyMeasurementRow
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Label(String(localized: "種類"), systemImage: "square.stack.3d.up")
                        .font(.subheadline.weight(.medium))

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
                Divider()
                progressControls
            }

            if !isHabitTodoEdit {
                Divider()
                priorityControls
            }
        }
    }

    private var scheduleCard: some View {
        TodoEditorCard(title: String(localized: "日付")) {
            dateControlRow(
                title: String(localized: "予定日"),
                systemImage: "calendar",
                isEnabled: $usesScheduledDate,
                selection: scheduledDateBinding
            )

            Divider()

            dateControlRow(
                title: String(localized: "期限"),
                systemImage: "calendar.badge.exclamationmark",
                isEnabled: $usesDeadline,
                selection: deadlineBinding
            )
        }
    }

    @ViewBuilder
    private var validationCard: some View {
        if !validationErrors.isEmpty {
            TodoEditorCard {
                ForEach(validationErrors, id: \.self) { error in
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    @ViewBuilder
    private var directionControl: some View {
        if let fixedDirection {
            readOnlyValue(
                "\(fixedDirection.symbolName) \(fixedDirection.name)",
                tint: Color(hex: fixedDirection.colorHex)
            )
        } else if isHabitTodoEdit, let direction = editedTodo?.direction {
            readOnlyValue(
                "\(direction.symbolName) \(direction.name)",
                tint: Color(hex: direction.colorHex)
            )
        } else {
            Picker(String(localized: "方向"), selection: selectedDirectionBinding) {
                Text(String(localized: "未選択")).tag(UUID?.none)

                ForEach(visibleDirections) { direction in
                    Text("\(direction.symbolName) \(direction.name)")
                        .tag(Optional(direction.id))
                }
            }
            .labelsHidden()
            .frame(width: 240)
            .accessibilityLabel(String(localized: "方向"))
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
            HStack(spacing: 14) {
                Label(String(localized: "優先度"), systemImage: "flag")
                    .font(.subheadline.weight(.medium))

                Spacer(minLength: 0)

                Picker(String(localized: "優先度"), selection: $draft.priority) {
                    ForEach(TodoPriority.allCases) { priority in
                        Text(priority.displayName).tag(priority)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
                .accessibilityLabel(String(localized: "優先度"))
            }

            if draft.priority == .low {
                Toggle(String(localized: "余裕があれば"), isOn: $draft.isRoomIfPossible)
                    .toggleStyle(.switch)
            }
        }
    }

    private var selectedDirection: Direction? {
        fixedDirection ?? direction(for: selectedDirectionID) ?? editedTodo?.direction
    }

    private var editorTint: Color {
        guard let selectedDirection else { return .secondary }
        return Color(hex: selectedDirection.colorHex)
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
        }
    }

    private func dateControlRow(
        title: String,
        systemImage: String,
        isEnabled: Binding<Bool>,
        selection: Binding<Date>
    ) -> some View {
        HStack(spacing: 14) {
            Toggle(isOn: isEnabled) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.medium))
            }
            .toggleStyle(.switch)

            Spacer(minLength: 20)

            DatePicker(title, selection: selection, displayedComponents: .date)
                .labelsHidden()
                .disabled(!isEnabled.wrappedValue)
                .opacity(isEnabled.wrappedValue ? 1 : 0.45)
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

    private var selectedDirectionBinding: Binding<UUID?> {
        Binding(
            get: { selectedDirectionID },
            set: {
                selectedDirectionID = $0
                draft.direction = direction(for: $0)
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

    private func selectInitialDirectionIfNeeded() {
        if let fixedDirection {
            selectedDirectionID = fixedDirection.id
            draft.direction = fixedDirection
        } else if draft.direction == nil {
            draft.direction = direction(for: selectedDirectionID)
        }
    }

    private func direction(for id: UUID?) -> Direction? {
        guard let id else { return nil }
        return visibleDirections.first { $0.id == id }
    }

    private func save() {
        if !isHabitTodoEdit {
            draft.direction = fixedDirection ?? direction(for: selectedDirectionID)
            draft.scheduledDate = usesScheduledDate ? draft.scheduledDate ?? .now : nil
            draft.deadline = usesDeadline ? draft.deadline ?? .now : nil
        }

        validationErrors = validator.validate(draft)
        guard validationErrors.isEmpty else { return }

        let direction = fixedDirection ?? (isHabitTodoEdit ? editedTodo?.direction ?? resolvedDirection(for: selectedDirectionID) : resolvedDirection(for: selectedDirectionID))
        let measurement = isHabitTodoEdit ? editedTodo?.measurement ?? draft.measurement : draft.measurement
        let priority = isHabitTodoEdit ? editedTodo?.priority ?? draft.priority : draft.priority
        let isRoomIfPossible = isHabitTodoEdit ? editedTodo?.isRoomIfPossible ?? false : draft.priority == .low && draft.isRoomIfPossible
        let scheduledDate = isHabitTodoEdit ? editedTodo?.scheduledDate : draft.scheduledDate
        let deadline = isHabitTodoEdit ? editedTodo?.deadline : draft.deadline
        draft.direction = direction

        let plannedAmount = measurement == .checkbox ? nil : isHabitTodoEdit ? editedTodo?.plannedAmount : draft.plannedAmount
        let actualProgress = measurement == .checkbox ? min(max(draft.actualProgress, 0), 1) : max(0, draft.actualProgress)

        switch mode {
        case .create:
            let todo = Todo(
                title: draft.trimmedTitle,
                notes: draft.trimmedNotes,
                hashtags: draft.hashtags,
                direction: direction,
                measurement: measurement,
                priority: priority,
                isRoomIfPossible: isRoomIfPossible,
                plannedAmount: plannedAmount,
                actualProgress: actualProgress,
                status: TodoProgressCalculator().status(
                    measurement: measurement,
                    plannedAmount: plannedAmount,
                    actualProgress: actualProgress
                ),
                scheduledDate: scheduledDate,
                deadline: deadline
            )
            modelContext.insert(todo)
            onSave?(todo)
        case .edit(let todo):
            todo.update(
                title: draft.trimmedTitle,
                notes: draft.trimmedNotes,
                hashtags: draft.hashtags,
                direction: direction,
                measurement: measurement,
                priority: priority,
                isRoomIfPossible: isRoomIfPossible,
                plannedAmount: plannedAmount,
                actualProgress: actualProgress,
                scheduledDate: scheduledDate,
                deadline: deadline
            )
            onSave?(todo)
        }

        dismiss()
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

    private var hashtagsBinding: Binding<String> {
        Binding(
            get: { draft.hashtags.map { "#\($0)" }.joined(separator: " ") },
            set: { value in
                draft.hashtags = TodoHashtagNormalizer.normalize(
                    value.split(whereSeparator: { $0.isWhitespace || $0 == "," }).map(String.init)
                )
            }
        )
    }
}

private struct TodoEditorCard<Content: View>: View {
    let title: String?
    private let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title)
                    .font(.headline)
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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

#Preview(String(localized: "タスクを作成")) {
    TodoFormView(mode: .create)
        .modelContainer(for: [Direction.self, Todo.self], inMemory: true)
}
