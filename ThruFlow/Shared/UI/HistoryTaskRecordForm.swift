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
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Direction.sortIndex) private var directions: [Direction]
    @Query(sort: \Todo.updatedAt, order: .reverse) private var todos: [Todo]

    let onDismiss: () -> Void

    @State private var source: RecordSource = .existing
    @State private var selectedTodoID: UUID?
    @State private var title = ""
    @State private var selectedDirectionID: UUID?
    @State private var measurement: TodoMeasurement = .checkbox
    @State private var priority: TodoPriority = .medium
    @State private var isRoomIfPossible = false
    @State private var plannedAmount = 1
    @State private var mode: FlowMode = .twentyFiveFive
    @State private var timeDraft: FlowHistoryTimeDraft
    @State private var errorMessage: String?

    private let editor = HistoryTaskRecordEditor()

    init(startedAt: Date, onDismiss: @escaping () -> Void) {
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
                Section {
                    Picker(String(localized: "記録方法"), selection: $source) {
                        ForEach(RecordSource.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(String(localized: "日時")) {
                    DatePicker(
                        String(localized: "記録日時"),
                        selection: startedAtBinding,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                switch source {
                case .existing:
                    existingTaskSection
                case .new:
                    newTaskSections
                }

                if activeMeasurement != .checkbox {
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "キャンセル"), action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "記録"), action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: prepareSelections)
            .onChange(of: timeDraft.startedAt) { _, _ in
                selectFirstAvailableTodoIfNeeded()
            }
            .onChange(of: source) { _, _ in
                errorMessage = nil
            }
            .onChange(of: mode) { _, newMode in
                timeDraft.setFocusMinutes(newMode.initialFocusDurationSeconds / 60)
            }
        }
    }

    private var availableDirections: [Direction] {
        directions.filter { !$0.isArchived }
    }

    private var availableTodos: [Todo] {
        editor.availableTodos(on: timeDraft.startedAt, from: todos)
    }

    private var selectedTodo: Todo? {
        guard let selectedTodoID else { return nil }
        return availableTodos.first { $0.id == selectedTodoID }
    }

    private var selectedDirection: Direction? {
        guard let selectedDirectionID else { return nil }
        return availableDirections.first { $0.id == selectedDirectionID }
    }

    private var activeMeasurement: TodoMeasurement {
        source == .existing ? selectedTodo?.measurement ?? .checkbox : measurement
    }

    private var canSave: Bool {
        switch source {
        case .existing:
            return selectedTodo != nil
        case .new:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && selectedDirection != nil
                && (measurement == .checkbox || plannedAmount > 0)
        }
    }

    private var startedAtBinding: Binding<Date> {
        Binding(
            get: { timeDraft.startedAt },
            set: { timeDraft.setStartedAt($0) }
        )
    }

    private var existingTaskSection: some View {
        Section(String(localized: "タスク")) {
            if availableTodos.isEmpty {
                ContentUnavailableView(
                    String(localized: "この日のタスクはありません"),
                    systemImage: "checklist",
                    description: Text(String(localized: "新しいタスクを作成して記録できます。"))
                )

                Button(String(localized: "新しいタスクを作成")) {
                    source = .new
                }
            } else {
                Picker(String(localized: "タスク"), selection: $selectedTodoID) {
                    ForEach(availableTodos) { todo in
                        Text("\(todo.direction?.symbolName ?? "📥") \(TodoDisplay.title(for: todo))")
                            .tag(Optional(todo.id))
                    }
                }

                if let selectedTodo {
                    LabeledContent(String(localized: "種類"), value: selectedTodo.measurement.displayName)
                    LabeledContent(
                        String(localized: "方向"),
                        value: "\(selectedTodo.direction?.symbolName ?? "📥") \(selectedTodo.direction?.name ?? String(localized: "その他"))"
                    )
                }
            }
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

    private var flowSection: some View {
        Section(String(localized: "Flow")) {
            Picker(String(localized: "Flowタイプ"), selection: $mode) {
                ForEach(manualModes) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            DatePicker(
                String(localized: "終了"),
                selection: Binding(
                    get: { timeDraft.endedAt },
                    set: { timeDraft.setEndedAt($0) }
                ),
                displayedComponents: [.date, .hourAndMinute]
            )

            Stepper(value: focusMinutesBinding, in: 1...720) {
                LabeledContent(
                    String(localized: "集中"),
                    value: String(localized: "\(timeDraft.focusMinutes)分")
                )
            }
        }
    }

    private var focusMinutesBinding: Binding<Int> {
        Binding(
            get: { timeDraft.focusMinutes },
            set: { timeDraft.setFocusMinutes($0) }
        )
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

    private func prepareSelections() {
        if selectedDirectionID == nil {
            selectedDirectionID = (
                DefaultDirections.existingTaskInbox(in: availableDirections)
                    ?? availableDirections.first
            )?.id
        }
        selectFirstAvailableTodoIfNeeded()
    }

    private func selectFirstAvailableTodoIfNeeded() {
        guard !availableTodos.contains(where: { $0.id == selectedTodoID }) else { return }
        selectedTodoID = availableTodos.first?.id
    }

    private func save() {
        errorMessage = nil

        do {
            switch source {
            case .existing:
                guard let selectedTodo else { return }
                try editor.record(
                    todo: selectedTodo,
                    recordedAt: timeDraft.startedAt,
                    mode: mode,
                    focusSeconds: timeDraft.focusSeconds,
                    modelContext: modelContext
                )
            case .new:
                guard let selectedDirection else { return }
                try editor.createAndRecord(
                    title: title,
                    direction: selectedDirection,
                    measurement: measurement,
                    priority: priority,
                    isRoomIfPossible: isRoomIfPossible,
                    plannedAmount: measurement == .checkbox ? nil : plannedAmount,
                    scheduledDate: timeDraft.startedAt,
                    recordedAt: timeDraft.startedAt,
                    mode: mode,
                    focusSeconds: timeDraft.focusSeconds,
                    modelContext: modelContext
                )
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
}

private enum RecordSource: String, CaseIterable, Identifiable {
    case existing
    case new

    var id: String { rawValue }

    var title: String {
        switch self {
        case .existing:
            return String(localized: "既存のタスク")
        case .new:
            return String(localized: "新しいタスク")
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
        case .missingDirection:
            return String(localized: "方向を選択してください。")
        }
    }
}
