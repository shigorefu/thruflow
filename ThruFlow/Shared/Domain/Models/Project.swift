import Foundation
import SwiftData

/// An optional, finite goal within an Area. Completion never completes its Tasks.
@Model
final class Project {
    var id: UUID = UUID()
    var name: String = ""
    var notes: String?
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

    var area: Area? { direction }
    var isCompleted: Bool { completedAt != nil }
    var isAvailableForNewTasks: Bool {
        !isCompleted && area.map { !$0.isArchived && !DefaultAreas.isTaskInbox($0) } == true
    }
}
