import SwiftData
import SwiftUI

struct IOSStatisticsView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Direction.updatedAt, order: .reverse) private var directions: [Direction]

    @State private var mode = IOSStatisticsMode.flow
    @State private var range = StatisticsRange.currentMonth
    @State private var directionID: UUID?
    @State private var selectedDate: Date?

    @Binding private var cachedFlowResult: StatisticsHeatmapResult?
    @Binding private var cachedTaskResult: AchievementHeatmapResult?
    let isVisible: Bool
    let onOpenHistoryDate: (Date) -> Void

    init(
        isVisible: Bool = true,
        cachedFlowResult: Binding<StatisticsHeatmapResult?>,
        cachedTaskResult: Binding<AchievementHeatmapResult?>,
        onOpenHistoryDate: @escaping (Date) -> Void = { _ in }
    ) {
        self.isVisible = isVisible
        _cachedFlowResult = cachedFlowResult
        _cachedTaskResult = cachedTaskResult
        self.onOpenHistoryDate = onOpenHistoryDate
    }

    private var filter: StatisticsFilter {
        StatisticsFilter(range: range, directionID: directionID)
    }

    private var flowResult: StatisticsHeatmapResult {
        cachedFlowResult ?? Self.emptyFlowResult
    }

    private var taskResult: AchievementHeatmapResult {
        cachedTaskResult ?? Self.emptyTaskResult
    }

    private var activeDirections: [Direction] {
        directions
            .filter { !$0.isArchived }
            .sorted {
                if $0.sortIndex != $1.sortIndex {
                    return $0.sortIndex < $1.sortIndex
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
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
        .onChange(of: mode) { _, _ in
            selectedDate = nil
        }
        .onChange(of: range) { _, _ in
            selectedDate = nil
        }
        .onChange(of: directionID) { _, _ in
            selectedDate = nil
        }
        .task(id: statisticsRefreshID) {
            await refreshStatisticsWhileVisible()
        }
    }

    @MainActor
    private func refreshStatisticsWhileVisible() async {
        while isVisible, !Task.isCancelled {
            await refreshStatisticsCache()
            try? await Task.sleep(for: .seconds(5))
        }
    }

    private static let emptyFlowResult = StatisticsHeatmapResult(
        days: [],
        summary: StatisticsSummary(totalFocusSeconds: 0, activeDayCount: 0, sessionCount: 0)
    )

    private static let emptyTaskResult = AchievementHeatmapResult(
        days: [],
        summary: AchievementSummary(completedCount: 0, activeDayCount: 0, directionCount: 0)
    )

    private var statisticsRefreshID: IOSStatisticsRefreshID {
        IOSStatisticsRefreshID(
            isVisible: isVisible,
            range: range.rawValue,
            directionID: directionID,
            directionCount: directions.count,
            latestDirectionUpdate: directions.first?.updatedAt
        )
    }

    @MainActor
    private func refreshStatisticsCache() async {
        guard isVisible else { return }

        try? await Task.sleep(for: .milliseconds(100))
        guard !Task.isCancelled, isVisible else { return }

        let loader = StatisticsProjectionActor(modelContainer: modelContext.container)
        guard let projection = try? await loader.load(
            filter: filter,
            calendar: calendar,
            dayBoundary: dayBoundary,
            now: .now
        ) else { return }

        guard !Task.isCancelled, isVisible else { return }
        cachedFlowResult = projection.flow
        cachedTaskResult = projection.achievement
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
                    ForEach(days) { day in
                        statisticsCell(day)
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

    private func selectedDayPopover(_ day: IOSStatisticsCell) -> some View {
        Button {
            openHistory(for: day.date)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(day.date.formatted(.dateTime.month().day().weekday(.abbreviated)))
                    .font(.subheadline.weight(.semibold))

                Text(String(localized: "タスク \(day.completedTaskCount) ・ Flow \(day.flowCount)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if day.flowSeconds > 0 {
                    Text("\(BlockUnit.displayText(forFocusedSeconds: day.flowSeconds)) ・ \(focusText(day.flowSeconds))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(String(localized: "この日の履歴を開く"))
    }

    private func openHistory(for date: Date) {
        selectedDate = nil
        DispatchQueue.main.async {
            onOpenHistoryDate(date)
        }
    }

    private func statisticsCell(_ day: IOSStatisticsCell) -> some View {
        let isSelected = selectedDate.map {
            calendar.isDate($0, inSameDayAs: day.date)
        } ?? false
        let shape = RoundedRectangle(cornerRadius: 3)

        return Button {
            if isSelected {
                openHistory(for: day.date)
            } else {
                withAnimation(.snappy(duration: 0.2)) {
                    selectedDate = day.date
                }
            }
        } label: {
            shape
                .fill(day.color)
                .frame(width: cellSize, height: cellSize)
                .overlay {
                    if isSelected {
                        shape
                            .fill(Color.accentColor.opacity(0.18))
                            .overlay {
                                shape.strokeBorder(Color.accentColor, lineWidth: 2)
                            }
                    }
                }
                .scaleEffect(isSelected ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.accessibilityLabel)
        .accessibilityHint(
            isSelected
                ? String(localized: "この日の履歴を開く")
                : String(localized: "選択")
        )
        .popover(
            isPresented: selectionBinding(for: day),
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .bottom
        ) {
            selectedDayPopover(day)
                .padding(10)
                .presentationCompactAdaptation(.popover)
        }
    }

    private func selectionBinding(for day: IOSStatisticsCell) -> Binding<Bool> {
        Binding(
            get: {
                selectedDate.map {
                    calendar.isDate($0, inSameDayAs: day.date)
                } ?? false
            },
            set: { isPresented in
                if !isPresented,
                   selectedDate.map({ calendar.isDate($0, inSameDayAs: day.date) }) == true {
                    selectedDate = nil
                }
            }
        )
    }

    private var flowDaysByDate: [Date: StatisticsDay] {
        Dictionary(uniqueKeysWithValues: flowResult.days.map { ($0.date, $0) })
    }

    private var taskDaysByDate: [Date: AchievementDay] {
        Dictionary(uniqueKeysWithValues: taskResult.days.map { ($0.date, $0) })
    }

    private var days: [IOSStatisticsCell] {
        switch mode {
        case .flow:
            let maximum = max(1, flowResult.days.map(\.totalFocusSeconds).max() ?? 1)
            return flowResult.days.map { day in
                let taskDay = taskDaysByDate[day.date]
                return IOSStatisticsCell(
                    date: day.date,
                    color: day.isEmpty
                        ? Color.primary.opacity(0.06)
                        : Color(hex: day.mixedColorHex ?? "#007AFF")
                            .opacity(0.25 + 0.75 * Double(day.totalFocusSeconds) / Double(maximum)),
                    completedTaskCount: taskDay?.completedCount ?? 0,
                    flowCount: day.sessionCount,
                    flowSeconds: day.totalFocusSeconds,
                    accessibilityLabel: "\(day.date.formatted(date: .abbreviated, time: .omitted)), \(focusText(day.totalFocusSeconds))"
                )
            }
        case .tasks:
            let maximum = max(1, taskResult.days.map(\.completedCount).max() ?? 1)
            return taskResult.days.map { day in
                let flowDay = flowDaysByDate[day.date]
                return IOSStatisticsCell(
                    date: day.date,
                    color: day.isEmpty
                        ? Color.primary.opacity(0.06)
                        : Color(hex: day.mixedColorHex ?? "#34C759")
                            .opacity(0.25 + 0.75 * Double(day.completedCount) / Double(maximum)),
                    completedTaskCount: day.completedCount,
                    flowCount: flowDay?.sessionCount ?? 0,
                    flowSeconds: flowDay?.totalFocusSeconds ?? 0,
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
            ForEach(activeDirections) { direction in
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

private struct IOSStatisticsRefreshID: Hashable {
    let isVisible: Bool
    let range: String
    let directionID: UUID?
    let directionCount: Int
    let latestDirectionUpdate: Date?
}

private struct IOSStatisticsCell: Identifiable {
    let date: Date
    let color: Color
    let completedTaskCount: Int
    let flowCount: Int
    let flowSeconds: Int
    let accessibilityLabel: String

    var id: Date { date }
}
