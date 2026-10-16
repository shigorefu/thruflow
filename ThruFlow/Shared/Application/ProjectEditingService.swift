import Foundation
import SwiftData

enum ProjectEditingError: Error, LocalizedError {
    case emptyName
    case unavailableArea
    case differentArea

    var errorDescription: String? {
        switch self {
        case .emptyName: String(localized: "プロジェクト名を入力してください。")
        case .unavailableArea: String(localized: "アーカイブされていない分野を選んでください。")
        case .differentArea: String(localized: "プロジェクトの分野は変更できません。")
        }
    }
}

@MainActor
struct ProjectEditingService {
    private let saveChanges: (ModelContext) throws -> Void

    init(saveChanges: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.saveChanges = saveChanges
    }

    @discardableResult
    func save(name: String, notes: String = "", area: Area, editing project: Project? = nil,
              modelContext: ModelContext, now: Date = .now) throws -> Project {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ProjectEditingError.emptyName }
        if let project {
            guard project.area?.id == area.id else { throw ProjectEditingError.differentArea }
        } else {
            guard !area.isArchived, !DefaultAreas.isTaskInbox(area) else {
                throw ProjectEditingError.unavailableArea
            }
        }
        let journal = EditorMutationJournal(modelContext: modelContext)
        if let project { journal.capture(project) }
        do {
            let saved: Project
            if let project {
                project.name = name
                project.notes = notes.isEmpty ? nil : notes
                project.updatedAt = now
                saved = project
            } else {
                saved = Project(name: name, notes: notes.isEmpty ? nil : notes, area: area,
                                createdAt: now, updatedAt: now)
                modelContext.insert(saved)
            }
            try saveChanges(modelContext)
            return saved
        } catch {
            journal.restore(modelContext: modelContext)
            throw error
        }
    }

    func setCompleted(_ completed: Bool, for project: Project,
                      modelContext: ModelContext, now: Date = .now) throws {
        guard project.isCompleted != completed else { return }
        let journal = EditorMutationJournal(modelContext: modelContext)
        journal.capture(project)
        do {
            project.completedAt = completed ? now : nil
            project.updatedAt = now
            try saveChanges(modelContext)
        } catch {
            journal.restore(modelContext: modelContext)
            throw error
        }
    }
}
