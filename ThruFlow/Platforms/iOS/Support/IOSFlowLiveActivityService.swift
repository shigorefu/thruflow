#if os(iOS)
import ActivityKit
import Foundation
import OSLog
import WidgetKit

@MainActor
final class IOSFlowLiveActivityService: LiveActivityService {
    private let timerWidgetSnapshots = FlowTimerWidgetSnapshotStore()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.shigorefu.thruflow",
        category: "LiveActivity"
    )

    func start(content: FlowLiveActivityContent) {
        publishTimerWidget(content)

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            endLiveActivities()
            return
        }

        if let existing = activity(for: content.sessionID) {
            update(existing, with: content)
            return
        }

        endActivities(except: content.sessionID)

        do {
            _ = try Activity<FlowActivityAttributes>.request(
                attributes: FlowActivityAttributes(sessionID: content.sessionID),
                content: activityContent(for: content),
                pushType: nil
            )
        } catch {
            logger.error("Unable to start Flow Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }

    func update(content: FlowLiveActivityContent) {
        publishTimerWidget(content)

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            endLiveActivities()
            return
        }

        guard let existing = activity(for: content.sessionID) else {
            start(content: content)
            return
        }

        update(existing, with: content)
    }

    func end() {
        timerWidgetSnapshots.clear()
        WidgetCenter.shared.reloadTimelines(ofKind: FlowTimerWidgetSnapshotStore.widgetKind)
        endLiveActivities()
    }

    private func endLiveActivities() {
        let activities = Activity<FlowActivityAttributes>.activities
        guard !activities.isEmpty else { return }

        Task {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func publishTimerWidget(_ content: FlowLiveActivityContent) {
        timerWidgetSnapshots.save(content.timerWidgetSnapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: FlowTimerWidgetSnapshotStore.widgetKind)
    }

    private func activity(for sessionID: UUID) -> Activity<FlowActivityAttributes>? {
        Activity<FlowActivityAttributes>.activities.first {
            $0.attributes.sessionID == sessionID
        }
    }

    private func update(
        _ activity: Activity<FlowActivityAttributes>,
        with content: FlowLiveActivityContent
    ) {
        let activityContent = activityContent(for: content)
        Task {
            await activity.update(activityContent)
        }
    }

    private func endActivities(except sessionID: UUID) {
        let staleActivities = Activity<FlowActivityAttributes>.activities.filter {
            $0.attributes.sessionID != sessionID
        }
        guard !staleActivities.isEmpty else { return }

        Task {
            for activity in staleActivities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func activityContent(for content: FlowLiveActivityContent) -> ActivityContent<FlowActivityAttributes.ContentState> {
        ActivityContent(
            state: content.activityContentState,
            staleDate: nil,
            relevanceScore: 100
        )
    }
}
#endif
