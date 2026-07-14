//
//  DayHistoryView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/11.
//

import SwiftData
import SwiftUI

enum DayHistoryMode: String, CaseIterable, Identifiable {
    case calendar
    case tasks
    case directions

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .calendar: "Flow"
        case .tasks: "タスク"
        case .directions: "方向"
        }
    }
}

struct DayHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FlowSession.startedAt, order: .reverse) private var sessions: [FlowSession]
    @Query(sort: \FlowBreak.startedAt, order: .reverse) private var breaks: [FlowBreak]
    @Query(sort: \Todo.updatedAt, order: .reverse) private var todos: [Todo]

    @State private var selectedDate: Date
    @State private var selectedMode: DayHistoryMode = .calendar
    @State private var selectedRange: HistoryCalendarRange = .week
    @State private var expandedTaskIDs: Set<String> = []
    @State private var expandedDirectionIDs: Set<UUID> = []
    @State private var editingTodo: Todo?

    private let onClose: (() -> Void)?
    private let calendar = Calendar.current
    private let builder = DayHistoryBuilder()

    init(initialDate: Date = .now, onClose: (() -> Void)? = nil) {
        _selectedDate = State(initialValue: Calendar.current.startOfDay(for: initialDate))
        self.onClose = onClose
    }

    private var snapshot: DayHistorySnapshot {
        builder.build(
            interval: selectedRange.interval(containing: selectedDate, calendar: calendar),
            sessions: sessions,
            todos: todos
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            historyToolbar

            modeContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .navigationTitle("履歴")
        .popover(item: $editingTodo) { todo in
            TodoFormView(mode: .edit(todo))
                .frame(minWidth: 430, idealWidth: 470, minHeight: 580, idealHeight: 650)
        }
    }

    private var historyToolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                historyIdentity
                Spacer(minLength: 12)
                modePicker.frame(width: 330)
                Spacer(minLength: 12)
                dateNavigation
                rangePicker.frame(width: 150)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    historyIdentity
                    Spacer()
                    dateNavigation
                }
                HStack(spacing: 12) {
                    modePicker.frame(maxWidth: .infinity)
                    rangePicker.frame(width: 150)
                }
            }
        }
    }

    private var historyIdentity: some View {
        HStack(spacing: 10) {
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .help("統計に戻る")
                .accessibilityLabel("統計に戻る")
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("履歴")
                    .font(.title2.weight(.semibold))
                Text(dateTitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var dateNavigation: some View {
        HStack(spacing: 4) {
            Button {
                moveDay(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .help("前の期間")

            DatePicker("日付", selection: $selectedDate, displayedComponents: .date)
                .labelsHidden()
                .accessibilityLabel("履歴の日付")

            Button {
                moveDay(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .help("次の期間")

            Button("今日") {
                selectedDate = calendar.startOfDay(for: .now)
            }
            .buttonStyle(.bordered)
            .tint(.accentColor)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var modePicker: some View {
        Picker("表示", selection: $selectedMode) {
            ForEach(DayHistoryMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("履歴表示")
    }

    private var rangePicker: some View {
        Picker("期間", selection: $selectedRange) {
            ForEach(HistoryCalendarRange.allCases) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("履歴の期間")
    }

    private var summary: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            HistorySummaryTile(
                title: "集中",
                value: durationText(snapshot.totalFocusSeconds),
                systemImage: "timer"
            )
            HistorySummaryTile(
                title: "ブロック",
                value: BlockUnit.displayText(forFocusedSeconds: snapshot.totalFocusSeconds),
                systemImage: "square.stack.3d.up"
            )
            HistorySummaryTile(
                title: "Flow",
                value: "\(snapshot.flowCount)",
                systemImage: "waveform.path.ecg"
            )
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        switch selectedMode {
        case .calendar:
            HistoryCalendarView(
                selectedDate: $selectedDate,
                range: $selectedRange,
                sessions: sessions,
                breaks: breaks
            )
        case .tasks:
            aggregateWorkspace { tasksContent }
        case .directions:
            aggregateWorkspace { directionsContent }
        }
    }

    private func aggregateWorkspace<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        GeometryReader { geometry in
            if geometry.size.width >= 900 {
                HStack(spacing: 0) {
                    aggregateList(content: content)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    aggregateInspector
                        .frame(width: min(390, max(310, geometry.size.width * 0.30)))
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        aggregatePeriodPicker
                        summary
                        content()
                    }
                    .padding(16)
                }
            }
        }
    }

    private func aggregateList<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .frame(maxWidth: 920, alignment: .leading)
                .padding(16)
        }
    }

    private var aggregateInspector: some View {
        VStack(spacing: 0) {
            aggregatePeriodPicker
                .padding(16)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text(periodSummaryTitle)
                    .font(.headline)
                summary
            }
            .padding(16)

            Spacer(minLength: 0)
        }
        .background(Color.secondary.opacity(0.035))
    }

    private var tasksContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("タスク別")
                .font(.headline)

            if snapshot.taskSummaries.isEmpty {
                emptyState
            } else {
                ForEach(snapshot.taskSummaries) { task in
                    HistoryExpandableTaskRow(
                        task: task,
                        flows: flows(for: task),
                        isExpanded: expandedTaskIDs.contains(task.id),
                        onToggleExpansion: { toggleTaskExpansion(task.id) },
                        onToggleCompletion: { todo in toggleTodo(todo) },
                        onEdit: { todo in editingTodo = todo }
                    )
                }
            }
        }
    }

    private var directionsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("方向別")
                .font(.headline)

            if snapshot.directionSummaries.isEmpty {
                emptyState
            } else {
                ForEach(snapshot.directionSummaries) { direction in
                    HistoryExpandableDirectionRow(
                        direction: direction,
                        tasks: tasks(for: direction),
                        isExpanded: expandedDirectionIDs.contains(direction.id),
                        onToggleExpansion: { toggleDirectionExpansion(direction.id) },
                        onEditTask: { todo in editingTodo = todo }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "記録なし",
            systemImage: "clock.arrow.circlepath",
            description: Text("この期間のFlowとタスクはありません。")
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var dateTitle: String {
        switch selectedRange {
        case .day:
            if calendar.isDateInToday(selectedDate) {
                return "今日 ・ \(fullDateFormatter.string(from: selectedDate))"
            }
            return fullDateFormatter.string(from: selectedDate)
        case .week:
            let interval = selectedRange.interval(containing: selectedDate, calendar: calendar)
            let end = interval.end.addingTimeInterval(-1)
            return "\(shortDateFormatter.string(from: interval.start))–\(shortDateFormatter.string(from: end))"
        case .month:
            return selectedDate.formatted(.dateTime.locale(Locale(identifier: "ja_JP")).year().month(.wide))
        }
    }

    private var fullDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日（E）"
        return formatter
    }

    private var shortDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter
    }

    private func moveDay(by value: Int) {
        selectedDate = calendar.startOfDay(for: selectedRange.moving(selectedDate, by: value, calendar: calendar))
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        if minutes < 60 { return "\(minutes)分" }
        return "\(minutes / 60)時間\(minutes % 60)分"
    }

    @ViewBuilder
    private var aggregatePeriodPicker: some View {
        switch selectedRange {
        case .day:
            HistoryMiniCalendar(selectedDate: $selectedDate)
        case .week:
            HistoryMiniCalendar(selectedDate: $selectedDate, selectionMode: .week)
        case .month:
            HistoryYearMonthPicker(selectedDate: $selectedDate)
        }
    }

    private var periodSummaryTitle: String {
        switch selectedRange {
        case .day: "この日の記録"
        case .week: "この週の記録"
        case .month: "この月の記録"
        }
    }

    private func flows(for task: DayHistoryTaskSummary) -> [DayHistoryFlow] {
        snapshot.flows.filter { flow in
            if let todoID = task.todoID { return flow.todoID == todoID }
            return flow.todoID == nil && flow.directionID == task.directionID
        }
    }

    private func tasks(for direction: DayHistoryDirectionSummary) -> [DayHistoryTaskSummary] {
        snapshot.taskSummaries.filter { $0.directionID == direction.directionID && $0.todo != nil }
    }

    private func toggleTaskExpansion(_ id: String) {
        withAnimation(.snappy(duration: 0.2)) {
            if expandedTaskIDs.remove(id) == nil { expandedTaskIDs.insert(id) }
        }
    }

    private func toggleDirectionExpansion(_ id: UUID) {
        withAnimation(.snappy(duration: 0.2)) {
            if expandedDirectionIDs.remove(id) == nil { expandedDirectionIDs.insert(id) }
        }
    }

    private func toggleTodo(_ todo: Todo) {
        todo.setCompleted(!todo.isCompleted)
        try? modelContext.save()
    }
}

private struct HistorySummaryTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Color.secondary.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct HistoryExpandableTaskRow: View {
    let task: DayHistoryTaskSummary
    let flows: [DayHistoryFlow]
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let onToggleCompletion: (Todo) -> Void
    let onEdit: (Todo) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let todo = task.todo {
                    TodoProgressControl(todo: todo) {
                        onToggleCompletion(todo)
                    }
                } else {
                    Circle()
                        .stroke(Color(hex: task.directionColorHex), lineWidth: 2)
                        .frame(width: 20, height: 20)
                        .frame(width: 34, height: 34)
                }

                HStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Text(task.directionSymbol)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.body.weight(.medium))
                                .strikethrough(task.todo?.isCompleted == true)
                                .lineLimit(1)
                            Text("\(task.directionName) ・ \(task.flowCount) Flow")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        if let todo = task.todo { onEdit(todo) }
                    }

                    Spacer(minLength: 8)

                    Text(durationText(task.focusSeconds))
                        .font(.callout.weight(.semibold).monospacedDigit())

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onToggleExpansion)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            if isExpanded {
                Divider().padding(.leading, 54)
                if flows.isEmpty {
                    Text("この期間のFlowはありません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 56)
                        .padding(.vertical, 10)
                } else {
                    ForEach(flows) { flow in
                        HistoryFlowDisclosureRow(flow: flow)
                    }
                }
            }
        }
        .background(Color.secondary.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        return minutes < 60 ? "\(minutes)分" : "\(minutes / 60)時間\(minutes % 60)分"
    }
}

private struct HistoryExpandableDirectionRow: View {
    let direction: DayHistoryDirectionSummary
    let tasks: [DayHistoryTaskSummary]
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let onEditTask: (Todo) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(direction.symbol)
                    .font(.title2)
                    .frame(width: 34, height: 34)
                    .background(Color(hex: direction.colorHex).opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 3) {
                    Text(direction.name)
                        .font(.body.weight(.medium))
                    Text("\(direction.taskCount) タスク ・ \(direction.flowCount) Flow")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(durationText(direction.focusSeconds))
                    .font(.callout.weight(.semibold).monospacedDigit())

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(12)
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggleExpansion)

            if isExpanded {
                Divider().padding(.leading, 54)
                if tasks.isEmpty {
                    Text("この期間のタスクはありません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 56)
                        .padding(.vertical, 10)
                } else {
                    ForEach(tasks) { task in
                        HStack(spacing: 10) {
                            if let todo = task.todo {
                                TodoProgressControl(todo: todo) {}
                                    .allowsHitTesting(false)
                            }
                            Text(task.directionSymbol)
                            Text(task.title)
                                .strikethrough(task.todo?.isCompleted == true)
                                .lineLimit(1)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    if let todo = task.todo { onEditTask(todo) }
                                }
                            Spacer()
                            Text(durationText(task.focusSeconds))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.trailing, 12)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .background(Color.secondary.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        return minutes < 60 ? "\(minutes)分" : "\(minutes / 60)時間\(minutes % 60)分"
    }
}

private struct HistoryFlowDisclosureRow: View {
    let flow: DayHistoryFlow

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: flow.directionColorHex))
                .frame(width: 4, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(flow.taskTitle)
                    .font(.callout)
                    .lineLimit(1)
                Text("\(time(flow.startedAt))–\(time(flow.endedAt))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(duration(flow.focusSeconds))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 56)
        .padding(.trailing, 12)
        .padding(.vertical, 7)
    }

    private func time(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "ja_JP")).hour().minute())
    }

    private func duration(_ seconds: Int) -> String {
        "\(max(0, seconds) / 60)分"
    }
}

#Preview {
    DayHistoryView()
        .environmentObject(ActiveFlowStore())
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self], inMemory: true)
}
