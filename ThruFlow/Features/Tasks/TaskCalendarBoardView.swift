//
//  TaskCalendarBoardView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/10.
//

import SwiftUI

struct TaskCalendarToolbar: View {
    @Binding var range: TaskCalendarRange
    @Binding var filter: TaskCalendarFilter

    let onToday: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ZStack {
                Picker("フィルター", selection: $filter) {
                    ForEach(TaskCalendarFilter.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)

                HStack(spacing: 10) {
                    Spacer()
                    Button("今日", action: onToday)
                        .buttonStyle(.borderedProminent)

                    rangePicker
                        .frame(width: 150)
                }
            }

            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    Button("今日", action: onToday)
                        .buttonStyle(.borderedProminent)
                    rangePicker.frame(width: 150)
                }

                Picker("フィルター", selection: $filter) {
                    ForEach(TaskCalendarFilter.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var rangePicker: some View {
        Picker("表示範囲", selection: $range) {
            ForEach(TaskCalendarRange.allCases) { option in
                Text(option.displayName).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }
}

struct TaskMultiDayBoard: View {
    let dates: [Date]
    let selectedDate: Date
    let todos: [Todo]
    let filter: TaskCalendarFilter
    let columnWidth: CGFloat
    let onSelectDate: (Date) -> Void
    let onToggle: (Todo) -> Void
    let onEdit: (Todo) -> Void
    let onStartFlow: (Todo) -> Void
    let onDelete: (Todo) -> Void
    let onMove: (Todo, Date) -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(dates, id: \.self) { date in
                        TaskDayColumn(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            todos: todosForDate(date),
                            width: columnWidth,
                            onSelect: { onSelectDate(date) },
                            onToggle: onToggle,
                            onEdit: onEdit,
                            onStartFlow: onStartFlow,
                            onDelete: onDelete,
                            onMove: { todoID in
                                guard let todo = todos.first(where: { $0.id == todoID }) else { return }
                                onMove(todo, date)
                            }
                        )
                        .frame(height: max(320, proxy.size.height - 16))
                    }
                }
                .padding(12)
            }
            .scrollIndicators(.visible)
        }
    }

    private func todosForDate(_ date: Date) -> [Todo] {
        todos
            .filter { todo in
                guard let scheduledDate = todo.scheduledDate else { return false }
                return Calendar.current.isDate(scheduledDate, inSameDayAs: date) && filter.includes(todo)
            }
            .sorted(by: TaskBoardSort.areInIncreasingOrder)
    }
}

private struct TaskDayColumn: View {
    let date: Date
    let isSelected: Bool
    let todos: [Todo]
    let width: CGFloat
    let onSelect: () -> Void
    let onToggle: (Todo) -> Void
    let onEdit: (Todo) -> Void
    let onStartFlow: (Todo) -> Void
    let onDelete: (Todo) -> Void
    let onMove: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onSelect) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.weekdayFormatter.string(from: date))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        Text(Self.dayFormatter.string(from: date))
                            .font(.title3.weight(.semibold))
                    }

                    Spacer(minLength: 0)

                    Text("\(todos.filter { !$0.isCompleted }.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if todos.isEmpty {
                        Text("タスクはありません")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else {
                        ForEach(TaskBoardGroup.groups(for: todos)) { group in
                            TaskBoardGroupHeader(group: group)

                            ForEach(group.todos) { todo in
                                taskCard(todo)
                            }
                        }
                    }
                }
                .padding(10)
            }
        }
        .frame(width: width)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.08))
        }
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first,
                  let uuid = UUID(uuidString: id) else {
                return false
            }
            onMove(uuid)
            return true
        }
    }

    @ViewBuilder
    private func taskCard(_ todo: Todo) -> some View {
        let card = TaskBoardCard(
            todo: todo,
            onToggle: { onToggle(todo) },
            onEdit: { onEdit(todo) },
            onStartFlow: { onStartFlow(todo) },
            onDelete: { onDelete(todo) }
        )

        if canDrag(todo) {
            card.draggable(todo.id.uuidString)
        } else {
            card
        }
    }

    private func canDrag(_ todo: Todo) -> Bool {
        guard !todo.isCompleted else { return false }
        guard todo.direction?.type == .habit else { return true }
        return todo.direction?.goalSchedule == .weeklyCount
    }

    private static let weekdayFormatter = makeFormatter("EEEE")
    private static let dayFormatter = makeFormatter("M月d日")

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = format
        return formatter
    }
}

struct TaskMonthGrid: View {
    let anchorDate: Date
    let dates: [Date]
    let selectedDate: Date
    let todos: [Todo]
    let filter: TaskCalendarFilter
    let onSelectDate: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(minimum: 72), spacing: 6), count: 7)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(dates, id: \.self) { date in
                    monthCell(date)
                }
            }
            .padding(12)
        }
    }

    private func monthCell(_ date: Date) -> some View {
        let dayTodos = todosForDate(date)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isCurrentMonth = Calendar.current.isDate(date, equalTo: anchorDate, toGranularity: .month)

        return Button {
            onSelectDate(date)
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(Self.dayFormatter.string(from: date))
                        .font(.caption.weight(isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? Color.white : isCurrentMonth ? Color.primary : Color.secondary)
                        .frame(width: 24, height: 24)
                        .background(isSelected ? Color.accentColor : Color.clear)
                        .clipShape(Circle())

                    Spacer(minLength: 0)

                    if !dayTodos.isEmpty {
                        Text("\(dayTodos.filter(\.isCompleted).count)/\(dayTodos.count)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 4) {
                    ForEach(directionDots(dayTodos), id: \.id) { direction in
                        Circle()
                            .fill(Color(hex: direction.colorHex))
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(height: 8)

                if dayTodos.contains(where: { $0.direction?.type == .habit && !$0.isCompleted }) {
                    Label("習慣", systemImage: "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else {
                    Text(dayTodos.isEmpty ? "" : "残り \(dayTodos.filter { !$0.isCompleted }.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
            .background(isCurrentMonth ? Color.primary.opacity(0.04) : Color.primary.opacity(0.018))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.07))
            }
            .opacity(isCurrentMonth ? 1 : 0.55)
        }
        .buttonStyle(.plain)
    }

    private func todosForDate(_ date: Date) -> [Todo] {
        todos.filter { todo in
            guard let scheduledDate = todo.scheduledDate else { return false }
            return Calendar.current.isDate(scheduledDate, inSameDayAs: date) && filter.includes(todo)
        }
    }

    private func directionDots(_ todos: [Todo]) -> [Direction] {
        var seen = Set<UUID>()
        return todos.compactMap(\.direction).filter { direction in
            !DefaultDirections.isTaskInbox(direction) && seen.insert(direction.id).inserted
        }.prefix(5).map { $0 }
    }

    private var weekdaySymbols: [String] {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        let first = max(0, Calendar.current.firstWeekday - 1)
        return Array(symbols[first...] + symbols[..<first])
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
}

private struct TaskBoardCard: View {
    let todo: Todo
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onStartFlow: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(tint)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 5) {
                Text(TodoDisplay.title(for: todo))
                    .font(titleIsPlaceholder ? .subheadline.weight(.medium).italic() : .subheadline.weight(.medium))
                    .foregroundStyle(titleIsPlaceholder ? Color.secondary.opacity(0.7) : Color.primary)
                    .strikethrough(todo.isCompleted)
                    .lineLimit(3)

                HStack(spacing: 5) {
                    if let direction = todo.direction, !DefaultDirections.isTaskInbox(direction) {
                        Text("\(direction.symbolName) \(direction.name)")
                            .foregroundStyle(tint)
                    }

                    Spacer(minLength: 0)

                    Text(summary)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .opacity(todo.isCompleted ? 0.55 : 1)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onEdit)
        .contextMenu {
            Button("編集", systemImage: "pencil", action: onEdit)
            Button("Flowを開始", systemImage: "play.fill", action: onStartFlow)
            Divider()
            Button("削除", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    private var titleIsPlaceholder: Bool {
        todo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var tint: Color {
        guard let direction = todo.direction, !DefaultDirections.isTaskInbox(direction) else {
            return .secondary
        }
        return Color(hex: direction.colorHex)
    }

    private var summary: String {
        TodoProgressCalculator().summary(
            measurement: todo.measurement,
            plannedAmount: todo.plannedAmount,
            actualProgress: todo.actualProgress,
            focusDurationSeconds: todo.focusDurationSeconds
        )
    }
}

private struct TaskBoardGroupHeader: View {
    let group: TaskBoardGroup

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(group.tint)
                .frame(width: 6, height: 6)
            Text(group.title)
                .font(.caption.weight(.semibold))
            Text("\(group.todos.count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }
}

private struct TaskBoardGroup: Identifiable {
    let type: DirectionType
    let todos: [Todo]

    var id: String { type.rawValue }
    var title: String { type.displayName }

    var tint: Color {
        switch type {
        case .habit: .red
        case .neutral: .blue
        case .nice: .green
        }
    }

    static func groups(for todos: [Todo]) -> [TaskBoardGroup] {
        let order: [DirectionType] = [.habit, .neutral, .nice]
        return order.compactMap { type in
            let matching = todos.filter { ($0.direction?.type ?? .neutral) == type }
            return matching.isEmpty ? nil : TaskBoardGroup(type: type, todos: matching)
        }
    }
}

private enum TaskBoardSort {
    nonisolated static func areInIncreasingOrder(_ lhs: Todo, _ rhs: Todo) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted
        }
        if lhs.sortIndex != rhs.sortIndex {
            return lhs.sortIndex < rhs.sortIndex
        }
        return lhs.createdAt < rhs.createdAt
    }
}
