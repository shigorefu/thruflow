//
//  DayHistoryView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/11.
//

import SwiftData
import SwiftUI

enum DayHistoryMode: String, CaseIterable, Identifiable {
    case timeline
    case tasks
    case directions

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .timeline: "タイムライン"
        case .tasks: "タスク"
        case .directions: "方向"
        }
    }
}

struct DayHistoryView: View {
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \FlowSession.startedAt, order: .reverse) private var sessions: [FlowSession]
    @Query(sort: \Todo.updatedAt, order: .reverse) private var todos: [Todo]

    @State private var selectedDate: Date
    @State private var selectedMode: DayHistoryMode = .timeline
    @State private var inspectedSession: FlowSession?

    private let onClose: (() -> Void)?
    private let calendar = Calendar.current
    private let builder = DayHistoryBuilder()

    init(initialDate: Date = .now, onClose: (() -> Void)? = nil) {
        _selectedDate = State(initialValue: Calendar.current.startOfDay(for: initialDate))
        self.onClose = onClose
    }

    private var snapshot: DayHistorySnapshot {
        builder.build(date: selectedDate, sessions: sessions, todos: todos)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                summary

                Picker("表示", selection: $selectedMode) {
                    ForEach(DayHistoryMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("履歴表示")

                modeContent
            }
            .frame(maxWidth: 980, alignment: .leading)
            .padding(20)
        }
        .navigationTitle("履歴")
        .sheet(item: $inspectedSession) { session in
            FlowHistoryInspectorView(session: session)
        }
    }

    private var header: some View {
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

            Spacer()

            HStack(spacing: 4) {
                Button {
                    moveDay(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .help("前の日")

                DatePicker("日付", selection: $selectedDate, in: ...Date.now, displayedComponents: .date)
                    .labelsHidden()
                    .accessibilityLabel("履歴の日付")

                Button {
                    moveDay(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(calendar.isDateInToday(selectedDate))
                .help("次の日")

                Button("今日") {
                    selectedDate = calendar.startOfDay(for: .now)
                }
                .disabled(calendar.isDateInToday(selectedDate))
            }
            .buttonStyle(.borderless)
        }
    }

    private var summary: some View {
        HStack(spacing: 10) {
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
                value: "\(snapshot.flows.count)",
                systemImage: "waveform.path.ecg"
            )
            HistorySummaryTile(
                title: "達成",
                value: "\(snapshot.completedTaskCount)",
                systemImage: "checkmark.circle"
            )
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        switch selectedMode {
        case .timeline:
            timelineContent
        case .tasks:
            tasksContent
        case .directions:
            directionsContent
        }
    }

    private var timelineContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("1日の流れ")
                .font(.headline)

            if timelineItems.isEmpty && untimedTasks.isEmpty {
                emptyState
            } else {
                ForEach(timelineItems) { item in
                    switch item {
                    case let .flow(flow):
                        Button {
                            guard activeFlowStore.activeSession?.id != flow.id else { return }
                            inspectedSession = flow.session
                        } label: {
                            FlowHistoryRow(flow: flow)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(
                            activeFlowStore.activeSession?.id == flow.id
                                ? "実行中のFlowは編集できません"
                                : "Flowの詳細を編集"
                        )
                    case let .task(task):
                        CompletedTaskHistoryRow(task: task)
                    }
                }

                if !untimedTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("完了時刻なし")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(untimedTasks) { task in
                            CompletedTaskHistoryRow(task: task)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private var tasksContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("タスク別")
                .font(.headline)

            if snapshot.taskSummaries.isEmpty && snapshot.completedTasks.isEmpty {
                emptyState
            } else {
                ForEach(snapshot.taskSummaries) { task in
                    HistoryAggregateRow(
                        symbol: task.directionSymbol,
                        title: task.title,
                        subtitle: "\(task.directionName) ・ \(task.flowCount) Flow",
                        value: durationText(task.focusSeconds),
                        colorHex: task.directionColorHex
                    )
                }

                if !snapshot.completedTasks.isEmpty {
                    Text("達成")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)

                    ForEach(snapshot.completedTasks) { task in
                        CompletedTaskHistoryRow(task: task)
                    }
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
                    HistoryAggregateRow(
                        symbol: direction.symbol,
                        title: direction.name,
                        subtitle: "\(direction.flowCount) Flow ・ \(BlockUnit.displayText(forFocusedSeconds: direction.focusSeconds))",
                        value: durationText(direction.focusSeconds),
                        colorHex: direction.colorHex
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "記録なし",
            systemImage: "clock.arrow.circlepath",
            description: Text("この日のFlowと達成タスクはありません。")
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var timelineItems: [DayTimelineItem] {
        let flows = snapshot.flows.map(DayTimelineItem.flow)
        let tasks = snapshot.completedTasks
            .filter(\.hasExactCompletionTime)
            .map(DayTimelineItem.task)
        return (flows + tasks).sorted { $0.date < $1.date }
    }

    private var untimedTasks: [DayHistoryTask] {
        snapshot.completedTasks.filter { !$0.hasExactCompletionTime }
    }

    private var dateTitle: String {
        if calendar.isDateInToday(selectedDate) {
            return "今日 ・ \(fullDateFormatter.string(from: selectedDate))"
        }
        return fullDateFormatter.string(from: selectedDate)
    }

    private var fullDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日（E）"
        return formatter
    }

    private func moveDay(by value: Int) {
        guard let next = calendar.date(byAdding: .day, value: value, to: selectedDate) else { return }
        selectedDate = min(calendar.startOfDay(for: next), calendar.startOfDay(for: .now))
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        if minutes < 60 { return "\(minutes)分" }
        return "\(minutes / 60)時間\(minutes % 60)分"
    }
}

private enum DayTimelineItem: Identifiable {
    case flow(DayHistoryFlow)
    case task(DayHistoryTask)

    var id: String {
        switch self {
        case let .flow(flow): "flow-\(flow.id.uuidString)"
        case let .task(task): "task-\(task.id.uuidString)"
        }
    }

    var date: Date {
        switch self {
        case let .flow(flow): flow.startedAt
        case let .task(task): task.completedAt ?? .distantFuture
        }
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

private struct FlowHistoryRow: View {
    let flow: DayHistoryFlow

    var body: some View {
        HStack(spacing: 12) {
            Text(timeFormatter.string(from: flow.startedAt))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: flow.directionColorHex))
                .frame(width: 4, height: 42)

            Text(flow.directionSymbol)
                .font(.title2)

            VStack(alignment: .leading, spacing: 3) {
                Text(flow.taskTitle)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(flow.directionName)
                    if let memo = flow.memo, !memo.isEmpty {
                        Text("・")
                        Text(memo).lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text(durationText(flow.focusSeconds))
                    .font(.callout.weight(.semibold).monospacedDigit())
                Text("\(timeFormatter.string(from: flow.startedAt))–\(timeFormatter.string(from: flow.endedAt))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        return minutes < 60 ? "\(minutes)分" : "\(minutes / 60)時間\(minutes % 60)分"
    }
}

private struct CompletedTaskHistoryRow: View {
    let task: DayHistoryTask

    var body: some View {
        HStack(spacing: 12) {
            Text(task.completedAt.map(timeText) ?? "--:--")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(hex: task.directionColorHex))
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .strikethrough()
                    .lineLimit(1)
                Text("\(task.directionSymbol) \(task.directionName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("達成")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private struct HistoryAggregateRow: View {
    let symbol: String
    let title: String
    let subtitle: String
    let value: String
    let colorHex: String

    var body: some View {
        HStack(spacing: 12) {
            Text(symbol)
                .font(.title2)
                .frame(width: 34, height: 34)
                .background(Color(hex: colorHex).opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(value)
                .font(.callout.weight(.semibold).monospacedDigit())
        }
        .padding(12)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    DayHistoryView()
        .environmentObject(ActiveFlowStore())
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self], inMemory: true)
}
