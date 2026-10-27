import Foundation

/// One optional recurring goal per Project. Lifecycle gaps survive disable/reopen
/// so calendar navigation cannot backfill obligations while the Habit was inactive.
nonisolated struct ProjectHabitSettings: Codable, Equatable {
    var isEnabled = false
    var goalTarget = 1
    var goalUnit: GoalUnit = .occurrences
    var goalSchedule: GoalScheduleKind = .everyDay
    var weeklyTargetCount = 1
    var weekdayMask: Int?
    var startsOn: Date?
    var inactiveSince: Date?
    var inactivePeriods: [HabitPausePeriod] = []

    @MainActor var validationDraft: AreaDraft {
        AreaDraft(name: "Project", type: .habit, goalEnabled: true,
                  goalTarget: goalTarget, goalUnit: goalUnit, goalSchedule: goalSchedule,
                  weeklyTargetCount: weeklyTargetCount, weekdayMask: weekdayMask)
    }

    /// Editors only change configuration. History always comes from the saved value.
    func updatingConfiguration(from draft: Self, completed: Bool, on day: Date) -> Self {
        var result = self
        result.isEnabled = draft.isEnabled
        result.goalTarget = draft.goalTarget
        result.goalUnit = draft.goalUnit
        result.goalSchedule = draft.goalSchedule
        result.weeklyTargetCount = draft.weeklyTargetCount
        result.weekdayMask = draft.weekdayMask
        result.updateActivity(completed: completed, on: day)
        return result
    }

    mutating func updateActivity(completed: Bool, on day: Date) {
        if isEnabled && !completed {
            if startsOn == nil { startsOn = day }
            if let inactiveSince {
                if inactiveSince < day {
                    inactivePeriods.append(HabitPausePeriod(startsOn: inactiveSince, endsBefore: day, createdAt: day))
                }
                self.inactiveSince = nil
            }
        } else if startsOn != nil && inactiveSince == nil {
            inactiveSince = day
        }
    }

    func wasInactive(on day: Date) -> Bool {
        guard let startsOn else { return true }
        return day < startsOn || inactiveSince.map { day >= $0 } == true ||
            inactivePeriods.contains { $0.contains(day) }
    }
}
