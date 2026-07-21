import SwiftData
import SwiftUI

struct IOSStatisticsView: View {
    @Environment(\.calendar) private var calendar

    @Query(sort: \Direction.sortIndex) private var directions: [Direction]
    @Query(sort: \Todo.updatedAt) private var todos: [Todo]
    @Query(sort: \FlowSession.startedAt) private var sessions: [FlowSession]

    @State private var mode = IOSStatisticsMode.flow
    @State private var range = StatisticsRange.currentMonth
    @State private var directionID: UUID?

    private var filter: StatisticsFilter {
        StatisticsFilter(range: range, directionID: directionID)
    }

    private var flowResult: StatisticsHeatmapResult {
        StatisticsHeatmapBuilder(calendar: calendar).build(sessions: sessions, filter: filter)
    }

    private var taskResult: AchievementHeatmapResult {
        AchievementHeatmapBuilder(calendar: calendar).build(todos: todos, filter: filter)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker(String(localized: "表示"), selection: $mode) {
                    ForEach(IOSStatisticsMode.allCases) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                .pickerStyle(.segmented)

                Picker(String(localized: "期間"), selection: $range) {
                    ForEach(StatisticsRange.allCases) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                .pickerStyle(.segmented)

                summaryCard
                contributionCard
            }
            .padding(16)
        }
        .background(Color.primary.opacity(0.025).ignoresSafeArea())
        .navigationTitle(String(localized: "統計"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                directionFilter
            }
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 0) {
            if mode == .flow {
                metric(focusText(flowResult.summary.totalFocusSeconds), String(localized: "集中時間"))
                metric(blockText(flowResult.summary.totalBlocks), String(localized: "ブロック"))
                metric("\(flowResult.summary.activeDayCount)", String(localized: "活動日"))
            } else {
                metric("\(taskResult.summary.completedCount)", String(localized: "タスク"))
                metric("\(taskResult.summary.activeDayCount)", String(localized: "活動日"))
                metric("\(taskResult.summary.directionCount)", String(localized: "方向"))
            }
        }
        .padding(.vertical, 18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var contributionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(range.summaryText)
                    .font(.headline)
                Spacer()
                Text(mode == .flow ? String(localized: "Flow") : String(localized: "タスク"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: heatmapRows, spacing: 5) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(day.color)
                            .frame(width: cellSize, height: cellSize)
                            .accessibilityLabel(day.accessibilityLabel)
                    }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 5) {
                Text(String(localized: "少ない"))
                ForEach(1...4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor.opacity(Double(level) / 4))
                        .frame(width: 12, height: 12)
                }
                Text(String(localized: "多い"))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var days: [IOSStatisticsCell] {
        switch mode {
        case .flow:
            let maximum = max(1, flowResult.days.map(\.totalFocusSeconds).max() ?? 1)
            return flowResult.days.map { day in
                IOSStatisticsCell(
                    color: day.isEmpty
                        ? Color.primary.opacity(0.06)
                        : Color(hex: day.mixedColorHex ?? "#007AFF")
                            .opacity(0.25 + 0.75 * Double(day.totalFocusSeconds) / Double(maximum)),
                    accessibilityLabel: "\(day.date.formatted(date: .abbreviated, time: .omitted)), \(focusText(day.totalFocusSeconds))"
                )
            }
        case .tasks:
            let maximum = max(1, taskResult.days.map(\.completedCount).max() ?? 1)
            return taskResult.days.map { day in
                IOSStatisticsCell(
                    color: day.isEmpty
                        ? Color.primary.opacity(0.06)
                        : Color(hex: day.mixedColorHex ?? "#34C759")
                            .opacity(0.25 + 0.75 * Double(day.completedCount) / Double(maximum)),
                    accessibilityLabel: "\(day.date.formatted(date: .abbreviated, time: .omitted)), \(day.completedCount)"
                )
            }
        }
    }

    private var cellSize: CGFloat {
        range == .currentMonth ? 26 : 16
    }

    private var heatmapRows: [GridItem] {
        Array(repeating: GridItem(.fixed(cellSize), spacing: 5), count: 7)
    }

    private var directionFilter: some View {
        Menu {
            Button(String(localized: "すべて")) { directionID = nil }
            Divider()
            ForEach(directions.filter { !$0.isArchived }) { direction in
                Button("\(direction.symbolName) \(direction.name)") {
                    directionID = direction.id
                }
            }
        } label: {
            Image(systemName: directionID == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
        .accessibilityLabel(String(localized: "方向で絞り込む"))
    }

    private func focusText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private func blockText(_ blocks: Double) -> String {
        blocks.formatted(.number.precision(.fractionLength(blocks.rounded() == blocks ? 0 : 1)))
    }
}

private enum IOSStatisticsMode: String, CaseIterable, Identifiable {
    case flow
    case tasks

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flow: String(localized: "Flow")
        case .tasks: String(localized: "タスク")
        }
    }
}

private struct IOSStatisticsCell {
    let color: Color
    let accessibilityLabel: String
}
