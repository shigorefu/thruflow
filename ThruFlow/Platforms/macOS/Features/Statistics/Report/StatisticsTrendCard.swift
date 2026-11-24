#if os(macOS)
import SwiftData
import SwiftUI

enum StatisticsQualityMode: String, CaseIterable, Identifiable {
    case flow, task, area, project

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .flow: String(localized: "集中")
        case .task: String(localized: "タスク")
        case .area: String(localized: "方向")
        case .project: String(localized: "プロジェクト")
        }
    }
}

struct StatisticsTrendCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var mode: StatisticsQualityMode
    let trend: StatisticsPresentationTrend
    let today: Date
    let availableWidth: CGFloat
    let compact: Bool
    var expandsPlot = false
    @Query private var projects: [Project]

    init(
        mode: Binding<StatisticsQualityMode>, trend: StatisticsPresentationTrend,
        today: Date, availableWidth: CGFloat, compact: Bool, expandsPlot: Bool = false
    ) {
        _mode = mode
        self.trend = trend
        self.today = today
        self.availableWidth = availableWidth
        self.compact = compact
        self.expandsPlot = expandsPlot
        var descriptor = FetchDescriptor<Project>()
        descriptor.fetchLimit = 1
        _projects = Query(descriptor)
    }

    private var options: [StatisticsQualityMode] {
        projects.isEmpty ? [.flow, .task, .area] : StatisticsQualityMode.allCases
    }

    private var availableMode: StatisticsQualityMode { options.contains(mode) ? mode : .area }

    var body: some View {
        StatisticsAnalysisCard(
            title: String(localized: "集中の質"),
            subtitle: availableMode == .task ? String(localized: "完了タスク") : String(localized: "集中時間"),
            systemImage: "chart.xyaxis.line",
            compact: compact
        ) {
            Picker(String(localized: "集中の質"), selection: Binding(
                get: { availableMode }, set: { mode = $0 }
            )) {
                ForEach(options) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .fixedSize(horizontal: true, vertical: false)
        } content: {
            ZStack(alignment: .topLeading) {
                plot
                    .id(availableMode)
                    .transition(.opacity)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: availableMode)
        }
        .onChange(of: projects.isEmpty, initial: true) { _, isEmpty in
            if isEmpty && mode == .project { mode = .area }
        }
    }

    @ViewBuilder
    private var plot: some View {
        switch availableMode {
        case .flow, .task:
            StatisticsTrendPlot(
                mode: availableMode == .flow ? .flow : .achievement,
                period: trend.period, points: trend.points, today: today,
                height: 240, compact: compact, expandsPlot: expandsPlot
            )
        case .area, .project:
            StatisticsGroupedTrendPlot(
                series: availableMode == .area ? trend.areaSeries : trend.projectSeries,
                period: trend.period, today: today,
                distinguishesProjects: availableMode == .project,
                legendOnRight: availableWidth >= 520,
                expandsPlot: expandsPlot
            )
        }
    }
}
#endif
