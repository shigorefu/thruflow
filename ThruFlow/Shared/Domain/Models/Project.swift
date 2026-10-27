import Foundation
import SwiftData

/// An optional, finite goal within an Area. Completion never completes its Tasks.
@Model
final class Project {
    var id: UUID = UUID()
    var name: String = ""
    var notes: String?
    /// Additive optional scalar; existing Projects have no Habit until enabled.
    var habitSettingsRawValue: String? = nil
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var completedAt: Date?
    var direction: Direction?
    @Relationship(inverse: \Todo.project)
    var todos: [Todo]?

    init(id: UUID = UUID(), name: String, notes: String? = nil, area: Area,
         createdAt: Date = .now, updatedAt: Date = .now, completedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.notes = notes
        self.direction = area
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }

    var habitSettings: ProjectHabitSettings? {
        get {
            guard let raw = habitSettingsRawValue, let data = raw.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(ProjectHabitSettings.self, from: data)
        }
        set {
            habitSettingsRawValue = newValue.flatMap { try? JSONEncoder().encode($0) }
                .flatMap { String(data: $0, encoding: .utf8) }
        }
    }

    var area: Area? { direction }
    var isCompleted: Bool { completedAt != nil }
    var isAvailableForNewTasks: Bool {
        !isCompleted && area.map { !$0.isArchived && !DefaultAreas.isTaskInbox($0) } == true
    }
}
