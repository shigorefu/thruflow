import Foundation

struct ReviewPromptUsage: Equatable {
    let firstLaunchAt: Date
    let completedFlowCount: Int
    let activeDayCount: Int
    let lastRequestedVersion: String?
}

struct ReviewPromptPolicy {
    static let minimumDaysSinceInstall = 7
    static let minimumActiveDays = 5
    static let minimumCompletedFlows = 10

    var calendar = Calendar.current

    func isEligible(
        usage: ReviewPromptUsage,
        currentVersion: String,
        now: Date
    ) -> Bool {
        guard usage.lastRequestedVersion != currentVersion else { return false }
        guard let eligibleDate = calendar.date(
            byAdding: .day,
            value: Self.minimumDaysSinceInstall,
            to: usage.firstLaunchAt
        ), now >= eligibleDate else {
            return false
        }

        return usage.activeDayCount >= Self.minimumActiveDays ||
            usage.completedFlowCount >= Self.minimumCompletedFlows
    }
}

@MainActor
final class ReviewPromptStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, now: Date = .now) {
        self.defaults = defaults
        if defaults.object(forKey: Keys.firstLaunchAt) == nil {
            defaults.set(now, forKey: Keys.firstLaunchAt)
        }
    }

    var firstLaunchAt: Date {
        defaults.object(forKey: Keys.firstLaunchAt) as? Date ?? .now
    }

    var lastRequestedVersion: String? {
        defaults.string(forKey: Keys.lastRequestedVersion)
    }

    func markRequested(version: String) {
        defaults.set(version, forKey: Keys.lastRequestedVersion)
    }

    private enum Keys {
        static let firstLaunchAt = "reviewPrompt.firstLaunchAt"
        static let lastRequestedVersion = "reviewPrompt.lastRequestedVersion"
    }
}
