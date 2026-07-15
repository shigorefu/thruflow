//
//  ManualFlowCreationView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/14.
//

import SwiftData
import SwiftUI

struct ManualFlowCreationView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Direction.sortIndex) private var directions: [Direction]
    @Query(sort: \Todo.updatedAt, order: .reverse) private var todos: [Todo]

    let onTimeChange: (Date, Date) -> Void
    let onDismiss: () -> Void

    @State private var selectedTodoID: UUID?
    @State private var selectedDirectionID: UUID?
    @State private var mode: FlowMode = .twentyFiveFive
    @State private var timeDraft: FlowHistoryTimeDraft
    @State private var errorMessage: String?

    private let editor = FlowHistoryEditor()
    private let lockedTodoID: UUID?

    init(
        startedAt: Date,
        todo: Todo? = nil,
        locksTodo: Bool = false,
        onTimeChange: @escaping (Date, Date) -> Void = { _, _ in },
        onDismiss: @escaping () -> Void
    ) {
        self.onTimeChange = onTimeChange
        self.onDismiss = onDismiss
        lockedTodoID = locksTodo ? todo?.id : nil
        _selectedTodoID = State(initialValue: todo?.id)
        _selectedDirectionID = State(initialValue: todo?.direction?.id)
        _timeDraft = State(initialValue: FlowHistoryTimeDraft(
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(25 * 60),
            focusSeconds: 25 * 60
        ))
    }

    private var availableDirections: [Direction] {
        directions.filter { !$0.isArchived }
    }

    private var availableTodos: [Todo] {
        todos
            .filter { todo in
                guard !todo.isDeleted, !todo.isArchived else { return false }
                return TodayTodoFilter().includes(todo, on: timeDraft.startedAt)
            }
            .sorted {
                if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
                if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
                return $0.createdAt < $1.createdAt
            }
    }

    private var selectedTodo: Todo? {
        guard let selectedTodoID else { return nil }
        return todos.first { $0.id == selectedTodoID }
    }

    private var selectedDirection: Direction? {
        if let direction = selectedTodo?.direction {
            return direction
        }
        guard let selectedDirectionID else { return availableDirections.first }
        return availableDirections.first { $0.id == selectedDirectionID }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    field("タスク") {
                        if let selectedTodo, lockedTodoID != nil {
                            Label {
                                Text(TodoDisplay.title(for: selectedTodo))
                            } icon: {
                                Text(selectedTodo.direction?.symbolName ?? "📥")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                        } else {
                            Picker("タスク", selection: $selectedTodoID) {
                                Text("タスクなし").tag(UUID?.none)
                                ForEach(availableTodos) { todo in
                                    Text("\(todo.direction?.symbolName ?? "📥") \(TodoDisplay.title(for: todo))")
                                        .tag(Optional(todo.id))
                                }
                            }
                            .labelsHidden()
                        }
                    }

                    field("方向") {
                        Picker("方向", selection: directionSelection) {
                            ForEach(availableDirections) { direction in
                                Text("\(direction.symbolName) \(direction.name)")
                                    .tag(Optional(direction.id))
                            }
                        }
                        .labelsHidden()
                        .disabled(selectedTodo != nil || lockedTodoID != nil)
                    }

                    field("Flow") {
                        Picker("Flow", selection: $mode) {
                            ForEach(manualModes) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    field("時間") {
                        HStack(alignment: .bottom, spacing: 10) {
                            timeField("開始") {
                                DatePicker(
                                    "開始",
                                    selection: Binding(
                                        get: { timeDraft.startedAt },
                                        set: { timeDraft.setStartedAt($0) }
                                    ),
                                    displayedComponents: [.hourAndMinute]
                                )
                                .labelsHidden()
                            }

                            Text("–")
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 5)

                            timeField("終了") {
                                DatePicker(
                                    "終了",
                                    selection: Binding(
                                        get: { timeDraft.endedAt },
                                        set: { timeDraft.setEndedAt($0) }
                                    ),
                                    displayedComponents: [.hourAndMinute]
                                )
                                .labelsHidden()
                            }

                            Spacer(minLength: 6)

                            timeField("集中") {
                                HStack(spacing: 4) {
                                    TextField(
                                        "分",
                                        value: Binding(
                                            get: { timeDraft.focusMinutes },
                                            set: { timeDraft.setFocusMinutes($0) }
                                        ),
                                        format: .number
                                    )
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 62)
                                    .multilineTextAlignment(.trailing)

                                    Text("分")
                                        .foregroundStyle(.secondary)
                                }
                                .monospacedDigit()
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(18)
            }

            Divider()
            footer
        }
        .frame(minWidth: 300, idealWidth: 440, minHeight: 390)
        .onAppear {
            if let directionID = selectedTodo?.direction?.id {
                selectedDirectionID = directionID
            } else if selectedDirectionID == nil {
                selectedDirectionID = availableDirections.first?.id
            }
        }
        .onChange(of: selectedTodoID) { _, _ in
            if let directionID = selectedTodo?.direction?.id {
                selectedDirectionID = directionID
            }
        }
        .onChange(of: mode) { _, newMode in
            timeDraft.setFocusMinutes(newMode.initialFocusDurationSeconds / 60)
        }
        .onChange(of: timeDraft) { _, newValue in
            onTimeChange(newValue.startedAt, newValue.endedAt)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Flowを追加")
                    .font(.title3.weight(.semibold))
                Text(timeDraft.startedAt.formatted(.dateTime.locale(Locale(identifier: "ja_JP")).month().day().weekday()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("閉じる")
        }
        .padding(18)
    }

    private var footer: some View {
        HStack {
            Button("キャンセル", action: onDismiss)
            Spacer()
            Button("追加", action: save)
                .buttonStyle(.borderedProminent)
                .disabled(selectedDirection == nil)
        }
        .padding(14)
    }

    private var directionSelection: Binding<UUID?> {
        Binding(
            get: { selectedDirection?.id ?? selectedDirectionID },
            set: { selectedDirectionID = $0 }
        )
    }

    private var manualModes: [FlowMode] {
        [.twelveThree, .twentyFiveFive, .fiftyTen]
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func timeField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func save() {
        guard let selectedDirection else {
            errorMessage = "方向を選択してください"
            return
        }

        editor.createManual(
            todo: selectedTodo,
            direction: selectedDirection,
            mode: mode,
            startedAt: timeDraft.startedAt,
            focusSeconds: timeDraft.focusSeconds,
            modelContext: modelContext
        )

        do {
            try modelContext.save()
            onDismiss()
        } catch {
            errorMessage = "Flowを保存できませんでした"
        }
    }
}
