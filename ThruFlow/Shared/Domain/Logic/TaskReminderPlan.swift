import Foundation

enum TaskTimeFormatting {
    static func parse(_ text: String) -> Int? {
        let bytes = Array(text.utf8)
        guard bytes.count == 5, bytes[2] == 58,
              [0, 1, 3, 4].allSatisfy({ (48...57).contains(bytes[$0]) }) else { return nil }
        let hour = Int(bytes[0] - 48) * 10 + Int(bytes[1] - 48)
        let minute = Int(bytes[3] - 48) * 10 + Int(bytes[4] - 48)
        guard hour < 24, minute < 60 else { return nil }
        return hour * 60 + minute
    }

    static func text(minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// Uses the selected civil date, not the custom Flow day boundary.
    /// A missing DST clock time advances to the next valid time; a repeated one uses the first.
    static func date(on day: Date, minutes: Int, calendar: Calendar) -> Date? {
        guard (0..<1440).contains(minutes),
              let result = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60,
                                         second: 0, of: day, matchingPolicy: .nextTime,
                                         repeatedTimePolicy: .first),
              calendar.isDate(result, inSameDayAs: day) else { return nil }
        return result
    }
}

struct TaskReminderRequest: Equatable, Sendable {
    static let prefix = "task.reminder."
    let taskID: UUID
    let title: String
    let body: String
    let fireDate: Date
    var identifier: String { Self.prefix + taskID.uuidString }
}

struct TaskReminderPlan {
    static func isEligible(_ todo: Todo) -> Bool {
        todo.reminderEnabled && !todo.isCompleted && !todo.isArchived && !todo.isDeleted &&
            todo.area.map { !$0.isArchived } == true && todo.scheduledDate != nil &&
            todo.scheduledTimeMinutes.map { (0..<1440).contains($0) } == true
    }

    func requests(todos: [Todo], calendar: Calendar, now: Date, limit: Int = 60) -> [TaskReminderRequest] {
        let requests = todos.compactMap { todo -> TaskReminderRequest? in
            guard Self.isEligible(todo),
                  let day = todo.scheduledDate, let minutes = todo.scheduledTimeMinutes,
                  let date = TaskTimeFormatting.date(on: day, minutes: minutes, calendar: calendar),
                  date > now else { return nil }
            return TaskReminderRequest(taskID: todo.id, title: String(localized: "タスクの時間です"),
                                       body: TodoDisplay.title(for: todo), fireDate: date)
        }
        return Array(requests.sorted {
            $0.fireDate == $1.fireDate ? $0.identifier < $1.identifier : $0.fireDate < $1.fireDate
        }.prefix(max(0, limit)))
    }
}
