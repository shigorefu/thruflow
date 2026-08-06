#if os(iOS) || os(macOS)
import SwiftData
import SwiftUI
import WidgetKit

struct ProductWidgetSnapshotSyncView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \Todo.updatedAt) private var todos: [Todo]
    @Query(sort: \Direction.updatedAt) private var directions: [Direction]
    @Query(sort: \FlowSession.updatedAt) private var sessions: [FlowSession]

    private let snapshots = ProductWidgetSnapshotStore()

    private var contentVersion: Int {
        var hasher = Hasher()
        hasher.combine(dayBoundary.day(containing: .now, calendar: calendar))
        todos.forEach {
            hasher.combine($0.id)
            hasher.combine($0.updatedAt)
            hasher.combine($0.direction?.id)
        }
        directions.forEach {
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
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .task(id: contentVersion) {
                publish()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    publish()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                publish()
            }
    }

    @MainActor
    private func publish(now: Date = .now) {
        let builder = ProductWidgetSnapshotBuilder(
            calendar: calendar,
            dayBoundary: dayBoundary
        )
        snapshots.saveTasks(builder.tasksSnapshot(todos: todos, now: now))
        snapshots.saveDots(builder.dotsSnapshot(sessions: sessions, now: now))
        WidgetCenter.shared.reloadTimelines(ofKind: ProductWidgetSnapshotStore.tasksWidgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: ProductWidgetSnapshotStore.dotsWidgetKind)
    }
}
#endif
