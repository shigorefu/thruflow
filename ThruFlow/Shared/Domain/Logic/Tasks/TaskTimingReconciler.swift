import Foundation

struct TaskTimingReconciler {
    /// Progress and generation timestamps cannot supersede an explicit timing edit.
    /// A cleared clock is an edit too; always copy the time and reminder together.
    func merge(todos: [Todo], into canonical: Todo) {
        if let timing = todos.filter({ $0.scheduledTimeUpdatedAt != nil }).sorted(by: {
            if $0.scheduledTimeUpdatedAt != $1.scheduledTimeUpdatedAt {
                return $0.scheduledTimeUpdatedAt! > $1.scheduledTimeUpdatedAt!
            }
            return $0.id.uuidString < $1.id.uuidString
        }).first {
            canonical.scheduledTimeMinutes = timing.scheduledTimeMinutes
            canonical.reminderEnabled = timing.reminderEnabled
            canonical.scheduledTimeUpdatedAt = timing.scheduledTimeUpdatedAt
        }
        if canonical.scheduledDate == nil {
            canonical.scheduledTimeMinutes = nil
            canonical.reminderEnabled = false
        }
    }
}
