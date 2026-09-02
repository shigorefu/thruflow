#if os(iOS)
import ActivityKit
import Foundation

struct FlowActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var taskEmoji: String
        var taskTitle: String
        var areaEmoji: String
        var areaName: String
        var areaColorHex: String
        var modeRawValue: String
        var modeName: String
        var status: FlowLiveActivityStatus
        var timerKind: FlowLiveActivityTimerKind
        var timerStartedAt: Date
        var plannedEndAt: Date
        var remainingSeconds: Int
        var progress: Double
        var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case taskEmoji
            case taskTitle
            case areaEmoji = "directionEmoji"
            case areaName = "directionName"
            case areaColorHex = "directionColorHex"
            case modeRawValue
            case modeName
            case status
            case timerKind
            case timerStartedAt
            case plannedEndAt
            case remainingSeconds
            case progress
            case updatedAt
        }

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

        var presentationAreaName: String {
            FlowLiveActivityPresentation.areaName(
                areaName,
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
                String(localized: "一時停止中のFlow")
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
            areaEmoji: areaEmoji,
            areaName: areaName,
            areaColorHex: areaColorHex,
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
