#if os(macOS) || os(iOS)
import SwiftData
import SwiftUI

enum StatisticsDistributionDimension: String, Identifiable {
    case task
    case area
    case project

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .task: String(localized: "タスク")
        case .area: String(localized: "方向")
        case .project: String(localized: "プロジェクト")
        }
    }

    func items(in distribution: StatisticsPresentationDistribution) -> [StatisticsDistributionItem] {
        switch self {
        case .task: distribution.task
        case .area: distribution.area
        case .project: distribution.project
        }
    }
}

struct StatisticsDistributionOptions<Content: View>: View {
    @Binding private var selection: StatisticsDistributionDimension
    @Query private var projects: [Project]
    private let content: (Binding<StatisticsDistributionDimension>, [StatisticsDistributionDimension]) -> Content

    init(
        selection: Binding<StatisticsDistributionDimension>,
        @ViewBuilder content: @escaping (Binding<StatisticsDistributionDimension>, [StatisticsDistributionDimension]) -> Content
    ) {
        _selection = selection
        var descriptor = FetchDescriptor<Project>()
        descriptor.fetchLimit = 1
        _projects = Query(descriptor)
        self.content = content
    }

    var body: some View {
        let options: [StatisticsDistributionDimension] = projects.isEmpty
            ? [.area, .task] : [.area, .project, .task]
        let availableSelection = Binding(
            get: { options.contains(selection) ? selection : .area },
            set: { selection = options.contains($0) ? $0 : .area }
        )
        content(availableSelection, options)
            .onChange(of: projects.isEmpty, initial: true) { _, isEmpty in
                if isEmpty && selection == .project {
                    selection = .area
                }
            }
    }
}
#endif
