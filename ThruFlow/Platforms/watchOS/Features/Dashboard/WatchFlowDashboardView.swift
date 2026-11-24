#if os(watchOS)
import Foundation
import SwiftData
import SwiftUI

struct WatchFlowDashboardView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Area.sortIndex) private var areas: [Area]
    @Query(sort: \Project.createdAt) private var projects: [Project]
    @Query private var todos: [Todo]

    private let todoSorter = FlowDashboardTodoSorter()
    @State private var selectedPage = WatchDashboardPage.timer

    init() {
        let page: WatchDashboardPage = switch ScreenshotMode.initialScreen() {
        case .tasks: .tasks
        case .statistics, .statisticsTrend, .statisticsBreakdown, .statisticsDots: .statistics
        case .flow, .history, .directions: .timer
        }
        _selectedPage = State(initialValue: page)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedPage) {
                WatchTimerView()
                    .tag(WatchDashboardPage.timer)

                WatchFlowStreamView(isVisible: selectedPage == .flow)
                    .tag(WatchDashboardPage.flow)

                WatchTasksView()
                    .tag(WatchDashboardPage.tasks)

                WatchStatisticsView()
                    .tag(WatchDashboardPage.statistics)
            }
            .tabViewStyle(.verticalPage(transitionStyle: .blur))
        }
        .onAppear {
            prepareToday()
            configureInitialContextIfNeeded()
        }
        .onChange(of: areas.map(\.id)) {
            prepareToday()
            configureInitialContextIfNeeded()
        }
        .onChange(of: todos.map(\.id)) {
            configureInitialContextIfNeeded()
        }
        .onChange(of: projectMaterializationRevisions) { _, _ in
            prepareToday()
            configureInitialContextIfNeeded()
        }
    }

    private var projectMaterializationRevisions: [WatchProjectMaterializationRevision] {
        projects.map {
            WatchProjectMaterializationRevision(
                id: $0.id, updatedAt: $0.updatedAt, completedAt: $0.completedAt,
                areaUpdatedAt: $0.area?.updatedAt, areaArchivedAt: $0.area?.archivedAt
            )
        }.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private var activeAreas: [Area] {
        areas.filter { $0.archivedAt == nil }
    }

    private var todayTodos: [Todo] {
        todoSorter.sorted(
            todos.filter {
                TodayTodoFilter(
                    calendar: calendar,
                    dayBoundary: dayBoundary
                ).includes($0)
            }
        )
    }

    private func prepareToday() {
        let today = dayBoundary.day(containing: .now, calendar: calendar)
        do {
            _ = try HabitTodoMaterializer(
                calendar: calendar,
                dayBoundary: dayBoundary
            ).materialize(
                areas: activeAreas,
                dates: [today],
                modelContext: modelContext
            )
        } catch {
            modelContext.rollback()
            PersistenceIssueCenter.shared.report(error, operation: .habitMaterialization)
        }
    }

    private func configureInitialContextIfNeeded() {
        guard activeFlowStore.selectedAreaID == nil else { return }

        if let todo = todayTodos.first(where: { !$0.isCompleted }),
           let area = todo.area {
            activeFlowStore.configure(area: area, todo: todo)
        } else if let area = activeAreas.first {
            activeFlowStore.configure(area: area, todo: nil)
        }
    }

}

private enum WatchDashboardPage: Hashable {
    case timer
    case flow
    case tasks
    case statistics
}

private struct WatchProjectMaterializationRevision: Hashable {
    let id: UUID
    let updatedAt: Date
    let completedAt: Date?
    let areaUpdatedAt: Date?
    let areaArchivedAt: Date?
}
#endif
