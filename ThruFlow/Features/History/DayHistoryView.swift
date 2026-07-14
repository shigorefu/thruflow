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
        case .calendar: "カレンダー"
        case .tasks: "タスク"
        case .directions: "方向"
        }
    }
}

struct DayHistoryView: View {
    @Query(sort: \FlowSession.startedAt, order: .reverse) private var sessions: [FlowSession]
    @Query(sort: \FlowBreak.startedAt, order: .reverse) private var breaks: [FlowBreak]
    @Query(sort: \Todo.updatedAt, order: .reverse) private var todos: [Todo]

    @State private var selectedDate: Date
    @State private var selectedMode: DayHistoryMode = .calendar
    @State private var selectedRange: HistoryCalendarRange = .week

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
        VStack(alignment: .leading, spacing: 14) {
            responsiveHeader
            responsiveControls

            modeContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .navigationTitle("履歴")
    }

    private var responsiveHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 20) {
                historyIdentity
                Spacer(minLength: 20)
                dateNavigation
            }

            VStack(alignment: .leading, spacing: 10) {
                historyIdentity
                dateNavigation
                    .frame(maxWidth: .infinity, alignment: .trailing)
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
        }
        .buttonStyle(.borderless)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var responsiveControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 20) {
                modePicker.frame(width: 360)
                Spacer(minLength: 20)
                if selectedMode == .calendar {
                    rangePicker.frame(width: 180)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                modePicker.frame(maxWidth: .infinity)
                if selectedMode == .calendar {
                    rangePicker.frame(maxWidth: .infinity)
                }
            }
        }
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
        .accessibilityLabel("カレンダー期間")
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
                value: "\(snapshot.flowCount)",
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
        case .calendar:
            HistoryCalendarView(
                selectedDate: $selectedDate,
                range: $selectedRange,
                sessions: sessions,
                breaks: breaks,
                todos: todos
            )
        case .tasks:
            aggregateScroll { tasksContent }
        case .directions:
            aggregateScroll { directionsContent }
        }
    }

    private func aggregateScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                summary
                content()
            }
            .frame(maxWidth: 980, alignment: .leading)
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
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self], inMemory: true)
}
