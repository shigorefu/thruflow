import Foundation

struct FlowTimerWidgetSnapshot: Codable, Equatable {
    var sessionID: UUID
    var taskEmoji: String
    var taskTitle: String
    var directionName: String
    var directionColorHex: String
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

    var isPaused: Bool {
        status == .paused
    }

    var progressCountsDown: Bool {
        timerKind == .breakTime
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

extension FlowLiveActivityContent {
    var timerWidgetSnapshot: FlowTimerWidgetSnapshot {
        FlowTimerWidgetSnapshot(
            sessionID: sessionID,
            taskEmoji: taskEmoji,
            taskTitle: taskTitle,
            directionName: directionName,
            directionColorHex: directionColorHex,
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

struct FlowTimerWidgetSnapshotStore {
    static let appGroupIdentifier = "group.com.shigorefu.thruflow"
    static let widgetKind = "FlowTimerWidget"

    private static let snapshotKey = "flow.timerWidget.snapshot"

    private let defaults: UserDefaults?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults? = UserDefaults(suiteName: Self.appGroupIdentifier)) {
        self.defaults = defaults
    }

    func save(_ snapshot: FlowTimerWidgetSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults?.set(data, forKey: Self.snapshotKey)
    }

    func load() -> FlowTimerWidgetSnapshot? {
        guard let data = defaults?.data(forKey: Self.snapshotKey) else { return nil }
        return try? decoder.decode(FlowTimerWidgetSnapshot.self, from: data)
    }

    func clear() {
        defaults?.removeObject(forKey: Self.snapshotKey)
    }
}
