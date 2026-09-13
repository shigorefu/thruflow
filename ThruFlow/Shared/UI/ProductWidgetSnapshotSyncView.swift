#if os(iOS) || os(macOS)
import SwiftData
import SwiftUI
import WidgetKit

struct ProductWidgetSnapshotSyncView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshRevision = 0

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .background {
                TasksWidgetSnapshotSyncView(refreshRevision: refreshRevision)
                DotsWidgetSnapshotSyncView(refreshRevision: refreshRevision)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshRevision += 1 }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                refreshRevision += 1
            }
    }
}

// Separate observation scopes keep checkbox changes out of the Flow-history projection.
private struct TasksWidgetSnapshotSyncView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Query(sort: \Todo.updatedAt) private var todos: [Todo]
    @Query(sort: \Area.updatedAt) private var areas: [Area]
    let refreshRevision: Int

    private var contentVersion: Int {
        var hasher = Hasher()
        hasher.combine(refreshRevision)
        hasher.combine(calendar)
        hasher.combine(dayBoundary.hour)
        todos.forEach {
            hasher.combine($0.id)
            hasher.combine($0.updatedAt)
            hasher.combine($0.area?.id)
        }
        areas.forEach {
            hasher.combine($0.id)
            hasher.combine($0.updatedAt)
        }
        return hasher.finalize()
    }

    var body: some View {
        Color.clear
            .task(id: contentVersion) {
                // Let the checkmark render first and coalesce rapid edits.
                do { try await Task.sleep(for: .milliseconds(350)) }
                catch { return }
                guard !Task.isCancelled else { return }
                let snapshot = ProductWidgetSnapshotBuilder(
                    calendar: calendar, dayBoundary: dayBoundary
                ).tasksSnapshot(todos: todos)
                ProductWidgetSnapshotStore().saveTasks(snapshot)
                WidgetCenter.shared.reloadTimelines(ofKind: ProductWidgetSnapshotStore.tasksWidgetKind)
            }
    }
}

private struct DotsWidgetSnapshotSyncView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Query(sort: \Area.updatedAt) private var areas: [Area]
    @Query(sort: \FlowSession.updatedAt) private var sessions: [FlowSession]
    let refreshRevision: Int

    private var contentVersion: Int {
        var hasher = Hasher()
        hasher.combine(refreshRevision)
        hasher.combine(calendar)
        hasher.combine(dayBoundary.hour)
        areas.forEach {
            hasher.combine($0.id)
            hasher.combine($0.updatedAt)
        }
        sessions.forEach {
            hasher.combine($0.id)
            hasher.combine($0.updatedAt)
            hasher.combine($0.resolvedSegments.count)
        }
        return hasher.finalize()
    }

    var body: some View {
        Color.clear
            .task(id: contentVersion) {
                do { try await Task.sleep(for: .milliseconds(350)) }
                catch { return }
                guard !Task.isCancelled else { return }
                let snapshot = ProductWidgetSnapshotBuilder(
                    calendar: calendar, dayBoundary: dayBoundary
                ).dotsSnapshot(sessions: sessions)
                ProductWidgetSnapshotStore().saveDots(snapshot)
                WidgetCenter.shared.reloadTimelines(ofKind: ProductWidgetSnapshotStore.dotsWidgetKind)
            }
    }
}
#endif
