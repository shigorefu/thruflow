#if os(macOS)
import SwiftData
import SwiftUI

struct FlowDashboardData: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query private var todos: [Todo]
    @Query private var sessions: [FlowSession]
    @Query private var flowBreaks: [FlowBreak]
    @Query(sort: \Project.createdAt) private var projects: [Project]
    @State private var dayRevision = 0
    @Binding private var snapshot: FlowDashboardSnapshot?
    @Binding private var todoGroups: FlowDashboardTodoGroups?
    @Binding private var trend: FlowDashboardTrend?

    let areas: [Area]
    let showsTrend: Bool

    init(
        areas: [Area],
        showsTrend: Bool,
        snapshot: Binding<FlowDashboardSnapshot?>,
        todoGroups: Binding<FlowDashboardTodoGroups?>,
        trend: Binding<FlowDashboardTrend?>
    ) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -16, to: .now) ?? .distantPast
        let todoUpperBound = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .distantFuture
        let missingScheduledDate = Date.distantPast
        self.areas = areas
        self.showsTrend = showsTrend
        _snapshot = snapshot
        _todoGroups = todoGroups
        _trend = trend
        _todos = Query(
            filter: #Predicate<Todo> { todo in
                (todo.scheduledDate ?? missingScheduledDate) >= cutoff &&
                    (todo.scheduledDate ?? missingScheduledDate) < todoUpperBound
            },
            sort: \Todo.updatedAt,
            order: .reverse
        )
        _sessions = Query(
            filter: #Predicate<FlowSession> { $0.startedAt >= cutoff },
            sort: \FlowSession.updatedAt,
            order: .reverse
        )
        _flowBreaks = Query(
            filter: #Predicate<FlowBreak> { $0.startedAt >= cutoff },
            sort: \FlowBreak.updatedAt,
            order: .reverse
        )
    }

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                dayRevision &+= 1
            }
            .task(id: habitPreparationID) {
                await prepareTodayHabits()
            }
            .onChange(of: activeFlowStore.phase) { _, _ in
                refreshSnapshot(now: .now)
            }
            .task(id: snapshotRefreshID) {
                await refreshDashboardCache()
            }
            .task(id: todoGroupsRefreshID) {
                guard !Task.isCancelled else { return }
                todoGroups = FlowDashboardTodoGroupBuilder(
                    calendar: calendar,
                    dayBoundary: dayBoundary
                ).build(from: todos)
            }
            .task(id: trendRefreshID) {
                guard showsTrend, !Task.isCancelled else { return }
                refreshTrend(now: .now)
            }
    }

    private var snapshotRefreshID: FlowDashboardRefreshID {
        FlowDashboardRefreshID(
            sessionCount: sessions.count,
            latestSessionUpdate: sessions.first?.updatedAt,
            breakCount: flowBreaks.count,
            latestBreakUpdate: flowBreaks.first?.updatedAt,
            areaCount: areas.count,
            latestAreaUpdate: areas.first?.updatedAt,
            activeSessionID: activeFlowStore.activeSession?.id,
            phase: activeFlowStore.timerState?.phase.rawValue,
            calendar: calendar,
            dayBoundaryHour: dayBoundary.hour,
            dayRevision: dayRevision
        )
    }

    private var todoGroupsRefreshID: FlowDashboardTodoRefreshID {
        FlowDashboardTodoRefreshID(
            todoCount: todos.count,
            latestTodoUpdate: todos.first?.updatedAt,
            calendar: calendar,
            dayBoundaryHour: dayBoundary.hour,
            dayRevision: dayRevision
        )
    }

    private var habitPreparationID: FlowDashboardHabitPreparationID {
        FlowDashboardHabitPreparationID(
            areaCount: areas.count,
            latestAreaUpdate: areas.first?.updatedAt,
            todos: todoGroupsRefreshID,
            projectRevisions: projects.map {
                FlowDashboardProjectHabitRevision(
                    id: $0.id, updatedAt: $0.updatedAt, completedAt: $0.completedAt,
                    areaUpdatedAt: $0.area?.updatedAt, areaArchivedAt: $0.area?.archivedAt
                )
            }.sorted { $0.id.uuidString < $1.id.uuidString }
        )
    }

    private var trendRefreshID: FlowDashboardTrendRefreshID? {
        guard showsTrend else { return nil }
        return FlowDashboardTrendRefreshID(snapshot: snapshotRefreshID, todos: todoGroupsRefreshID)
    }

    private func refreshDashboardCache() async {
        guard !Task.isCancelled else { return }
        refreshSnapshot(now: .now)

        while !Task.isCancelled, activeFlowStore.timerState != nil {
            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            refreshSnapshot(now: .now)
        }
    }

    private func refreshSnapshot(now: Date) {
        let day = dayBoundary.day(containing: now, calendar: calendar)
        let interval = dayBoundary.interval(for: day, calendar: calendar)
        snapshot = FlowDashboardBuilder(calendar: calendar, dayBoundary: dayBoundary).build(
            date: now,
            sessions: sessions.filter { interval.contains($0.startedAt) },
            breaks: flowBreaks.filter { interval.contains($0.startedAt) },
            activeSessionID: activeFlowStore.activeSession?.id,
            activeFocusSeconds: activeFlowStore.actualFocusSeconds(now: now),
            visualIdentityID: DailyFlowIdentity.resolve(from: areas)
        )
    }

    private func refreshTrend(now: Date) {
        let builder = DashboardStatisticsBuilder(calendar: calendar, dayBoundary: dayBoundary)
        trend = FlowDashboardTrend(
            days: builder.days(count: 7, endingOn: now, sessions: sessions, breaks: flowBreaks),
            comparison: builder.comparison(on: now, sessions: sessions, breaks: flowBreaks, todos: todos)
        )
    }

    private func prepareTodayHabits() async {
        try? await Task.sleep(for: .milliseconds(220))
        guard !Task.isCancelled else { return }
        let now = Date.now
        let today = dayBoundary.day(containing: now, calendar: calendar)
        do {
            _ = try HabitTodoMaterializer(calendar: calendar, dayBoundary: dayBoundary).materialize(
                areas: areas,
                dates: [today],
                modelContext: modelContext,
                now: now,
                knownTodos: todos,
                reconcilesDuplicates: false
            )
        } catch {
            modelContext.rollback()
            PersistenceIssueCenter.shared.report(error, operation: .habitMaterialization)
        }
    }
}

struct FlowDashboardTrend {
    let days: [DashboardStatisticsDay]
    let comparison: DashboardStatisticsComparison
}

private struct FlowDashboardRefreshID: Hashable {
    let sessionCount: Int
    let latestSessionUpdate: Date?
    let breakCount: Int
    let latestBreakUpdate: Date?
    let areaCount: Int
    let latestAreaUpdate: Date?
    let activeSessionID: UUID?
    let phase: String?
    let calendar: Calendar
    let dayBoundaryHour: Int
    let dayRevision: Int
}

private struct FlowDashboardTodoRefreshID: Hashable {
    let todoCount: Int
    let latestTodoUpdate: Date?
    let calendar: Calendar
    let dayBoundaryHour: Int
    let dayRevision: Int
}

private struct FlowDashboardTrendRefreshID: Hashable {
    let snapshot: FlowDashboardRefreshID
    let todos: FlowDashboardTodoRefreshID
}

private struct FlowDashboardProjectHabitRevision: Hashable {
    let id: UUID
    let updatedAt: Date
    let completedAt: Date?
    let areaUpdatedAt: Date?
    let areaArchivedAt: Date?
}

private struct FlowDashboardHabitPreparationID: Hashable {
    let areaCount: Int
    let latestAreaUpdate: Date?
    let todos: FlowDashboardTodoRefreshID
    let projectRevisions: [FlowDashboardProjectHabitRevision]
}
#endif
