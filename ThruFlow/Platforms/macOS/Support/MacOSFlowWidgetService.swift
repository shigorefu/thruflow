#if os(macOS)
import WidgetKit

@MainActor
final class MacOSFlowWidgetService: LiveActivityService {
    private let snapshots = FlowTimerWidgetSnapshotStore()

    func start(content: FlowLiveActivityContent) {
        publish(content)
    }

    func update(content: FlowLiveActivityContent) {
        publish(content)
    }

    func end() {
        snapshots.clear()
        WidgetCenter.shared.reloadTimelines(ofKind: FlowTimerWidgetSnapshotStore.widgetKind)
    }

    private func publish(_ content: FlowLiveActivityContent) {
        snapshots.save(content.timerWidgetSnapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: FlowTimerWidgetSnapshotStore.widgetKind)
    }
}
#endif
