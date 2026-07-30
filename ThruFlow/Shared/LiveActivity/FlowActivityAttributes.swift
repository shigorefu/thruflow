#if os(iOS)
import ActivityKit
import Foundation

struct FlowActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var taskEmoji: String
        var taskTitle: String
        var directionEmoji: String
        var directionName: String
        var directionColorHex: String
        var modeRawValue: String
        var modeName: String
        var status: FlowLiveActivityStatus
        var timerKind: FlowLiveActivityTimerKind
        var timerStartedAt: Date
        var plannedEndAt: Date
        var remainingSeconds: Int
        var progress: Double
        var updatedAt: Date

        var timerRange: ClosedRange<Date> {
            timerStartedAt...max(timerStartedAt.addingTimeInterval(1), plannedEndAt)
        }

        var overtimeRange: ClosedRange<Date> {
            plannedEndAt...plannedEndAt.addingTimeInterval(24 * 60 * 60)
        }

        var isPaused: Bool {
            status == .paused
        }

        var progressCountsDown: Bool {
            timerKind == .breakTime
        }

        var presentationEmoji: String {
            FlowLiveActivityPresentation.emoji(
                taskEmoji: taskEmoji,
                timerKind: timerKind
            )
        }

        var presentationTitle: String {
            FlowLiveActivityPresentation.title(
                taskTitle: taskTitle,
                timerKind: timerKind
            )
        }

        var presentationDirectionName: String {
            FlowLiveActivityPresentation.directionName(
                directionName,
                timerKind: timerKind
            )
        }

        var statusTitle: String {
            switch status {
            case .focus:
                String(localized: "集中")
            case .breakTime:
                String(localized: "休憩")
            case .paused:
                String(localized: "一時停止")
            }
        }
    }

    var sessionID: UUID
}

extension FlowLiveActivityContent {
    var activityContentState: FlowActivityAttributes.ContentState {
        FlowActivityAttributes.ContentState(
            taskEmoji: taskEmoji,
            taskTitle: taskTitle,
            directionEmoji: directionEmoji,
            directionName: directionName,
            directionColorHex: directionColorHex,
            modeRawValue: modeRawValue,
            modeName: modeName,
            status: status,
            timerKind: timerKind,
            timerStartedAt: timerStartedAt,
            plannedEndAt: plannedEndAt,
            remainingSeconds: remainingSeconds,
            progress: progress,
            updatedAt: updatedAt
        )
    }
}
#endif
