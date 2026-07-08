//
//  TodayView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Direction.name, order: .forward) private var directions: [Direction]
    @Query(sort: \Todo.sortIndex, order: .forward) private var todos: [Todo]

    @State private var editingTodo: Todo?
    @State private var newTodoTitle = ""
    @State private var newTodoDirectionID: UUID?
    @State private var newTodoVolume: QuickTodoVolume = .checkbox
    @State private var newTodoDateOption: QuickTodoDate = .today
    @State private var newTodoError: String?

    private let filter = TodayTodoFilter()
    private let requiredPlanner = RequiredTodoPlanner()
    private let progress = TodoProgressCalculator()
    private let validator = TodoValidator()

    private var activeDirections: [Direction] {
        directions.filter { !$0.isArchived }
    }

    private var todayTodos: [Todo] {
        todos.filter { filter.includes($0) }
    }

    var body: some View {
        List {
            if todayTodos.isEmpty {
                EmptyRow(text: "今日のタスクはまだありません。")
                    .listRowSeparator(.hidden)
            } else {
                ForEach(todayTodos) { todo in
                    TodoRow(
                        todo: todo,
                        summary: progress.summary(
                            measurement: todo.measurement,
                            plannedAmount: todo.plannedAmount,
                            actualProgress: todo.actualProgress,
                            focusDurationSeconds: todo.focusDurationSeconds
                        )
                    )
                    .onTapGesture(count: 2) {
                        editingTodo = todo
                    }
                    .contextMenu {
                        Button("編集", systemImage: "pencil") {
                            editingTodo = todo
                        }

                        Menu("移動") {
                            Button("今日") {
                                todo.reschedule(to: .now)
                            }
                            Button("明日") {
                                todo.reschedule(to: Calendar.current.date(byAdding: .day, value: 1, to: .now))
                            }
                            Button("日付なし") {
                                todo.reschedule(to: nil)
                            }
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
                .onMove(perform: moveTodos)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(.default, value: todayTodos.map(\.id))
        .navigationTitle("今日")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                MessengerTodoComposer(
                    title: $newTodoTitle,
                    selectedDirectionID: $newTodoDirectionID,
                    volume: $newTodoVolume,
                    dateOption: $newTodoDateOption,
                    directions: activeDirections,
                    validationMessage: newTodoError,
                    onSubmit: createInlineTodo
                )

                FlowMiniPlayerView()
            }
        }
        .sheet(item: $editingTodo) { todo in
            TodoFormView(mode: .edit(todo))
        }
        .onAppear {
            ensureRequiredTodosForToday()
        }
        .onChange(of: directions.map(\.updatedAt)) { _, _ in
            ensureRequiredTodosForToday()
        }
    }

    private func moveTodos(from source: IndexSet, to destination: Int) {
        var reordered = todayTodos
        reordered.move(fromOffsets: source, toOffset: destination)

        for (index, todo) in reordered.enumerated() {
            todo.setSortIndex(index)
        }

        try? modelContext.save()
    }

    private func createInlineTodo() {
        let draft = TodoDraft(
            title: newTodoTitle,
            direction: direction(for: newTodoDirectionID),
            measurement: newTodoVolume.measurement,
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
        newTodoError = nil
    }

    private func ensureRequiredTodosForToday(now: Date = .now) {
        let requiredDirections = activeDirections.filter {
            requiredPlanner.shouldAppearToday($0, on: now)
        }

        guard !requiredDirections.isEmpty else { return }

        var inserted = false
        let minimumSortIndex = todos.map(\.sortIndex).min() ?? 0

        for (offset, direction) in requiredDirections.enumerated() {
            guard requiredPlanner.existingRequiredTodo(for: direction, in: todos, on: now) == nil,
                  let todo = requiredPlanner.makeRequiredTodo(
                    for: direction,
                    on: now,
                    sortIndex: minimumSortIndex - offset - 1
                  ) else {
                continue
            }

            modelContext.insert(todo)
            inserted = true
        }

        if inserted {
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
        return activeDirections.first { $0.id == id }
    }
}

/// Quick-add volume selection for the composer. `checkbox` means "no target amount",
/// `blocks(n)` targets `n` focus blocks (1 Block = 25 focused minutes).
enum QuickTodoVolume: Hashable {
    case checkbox
    case blocks(Int)

    static let options: [QuickTodoVolume] = [.checkbox, .blocks(1), .blocks(2), .blocks(3), .blocks(4)]

    var measurement: TodoMeasurement {
        switch self {
        case .checkbox:
            .checkbox
        case .blocks:
            .focusBlocks
        }
    }

    var plannedAmount: Int? {
        if case .blocks(let count) = self { count } else { nil }
    }

    var menuLabel: String {
        switch self {
        case .checkbox:
            "チェックのみ"
        case .blocks(let count):
            count == 1 ? "1 Block" : "\(count) Blocks"
        }
    }

    var chipLabel: String {
        switch self {
        case .checkbox:
            "チェック"
        case .blocks(let count):
            count == 1 ? "1 Block" : "\(count) Blocks"
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

/// Compact, chip-based quick-add composer pinned to the bottom of Today.
private struct MessengerTodoComposer: View {
    @Binding var title: String
    @Binding var selectedDirectionID: UUID?
    @Binding var volume: QuickTodoVolume
    @Binding var dateOption: QuickTodoDate

    let directions: [Direction]
    let validationMessage: String?
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1.6)
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)

                TextField("タスクを追加", text: $title)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit(submit)

                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(trimmedTitle.isEmpty ? Color.secondary.opacity(0.4) : Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(trimmedTitle.isEmpty)
                .accessibilityLabel("タスクを追加")
            }

            HStack(spacing: 8) {
                DirectionChip(selectedDirectionID: $selectedDirectionID, directions: directions)
                VolumeChip(volume: $volume)
                DateChip(dateOption: $dateOption)
                Spacer(minLength: 0)
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private func submit() {
        guard !trimmedTitle.isEmpty else { return }
        onSubmit()
        isFocused = true
    }
}

private struct DirectionChip: View {
    @Binding var selectedDirectionID: UUID?

    let directions: [Direction]

    private var selectedDirection: Direction? {
        guard let selectedDirectionID else { return nil }
        return directions.first { $0.id == selectedDirectionID }
    }

    var body: some View {
        Menu {
            Button {
                selectedDirectionID = nil
            } label: {
                menuRow(text: "自動: 📝 タスク", isSelected: selectedDirectionID == nil)
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
            HStack(spacing: 4) {
                Text(selectedDirection?.symbolName ?? "📝")
                Text(selectedDirection?.name ?? "タスク")
            }
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

private struct TodoRow: View {
    @Environment(\.modelContext) private var modelContext

    let todo: Todo
    let summary: String

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                todo.setCompleted(!todo.isCompleted)
                try? modelContext.save()
            } label: {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(checkboxTint, lineWidth: 1.6)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(todo.isCompleted ? checkboxTint : Color.clear)
                    )
                    .overlay {
                        if todo.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 20, height: 20)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isCompleted ? "未完了に戻す" : "完了にする")

            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .font(.body.weight(.medium))
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)

                HStack(spacing: 6) {
                    if let direction = todo.direction {
                        Text("\(direction.symbolName) \(direction.name)")
                            .foregroundStyle(checkboxTint)
                        Text("·")
                    }

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
        .listRowInsets(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10))
        .listRowSeparator(.hidden)
        .listRowBackground(rowBackground)
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
    TodayView()
        .environmentObject(ActiveFlowStore())
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self], inMemory: true)
}
