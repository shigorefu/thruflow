import Foundation
import SwiftData

enum ProjectEditingError: Error, LocalizedError {
    case emptyName
    case unavailableArea
    case differentArea
    case invalidHabit([AreaValidationError])

    var errorDescription: String? {
        switch self {
        case .invalidHabit(let errors): errors.first?.localizedDescription
        case .emptyName: String(localized: "プロジェクト名を入力してください。")
        case .unavailableArea: String(localized: "アーカイブされていない分野を選んでください。")
        case .differentArea: String(localized: "プロジェクトの分野は変更できません。")
        }
    }
}

@MainActor
struct ProjectEditingService {
    var calendar: Calendar
    var dayBoundary: AppDayBoundary
    private let saveChanges: (ModelContext) throws -> Void

    init(calendar: Calendar = .current, dayBoundary: AppDayBoundary = .midnight, saveChanges: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.calendar = calendar
        self.dayBoundary = dayBoundary
        self.saveChanges = saveChanges
    }

    @discardableResult
    func save(name: String, notes: String = "", area: Area, editing project: Project? = nil, habit: ProjectHabitSettings? = nil,
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
        if let habit, habit.isEnabled {
            let errors = AreaValidator().validate(habit.validationDraft)
            guard errors.isEmpty else { throw ProjectEditingError.invalidHabit(errors) }
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
            if let habit {
                let day = dayBoundary.day(containing: now, calendar: calendar)
                let previous = saved.habitSettings
                let updated = (previous ?? ProjectHabitSettings())
                    .updatingConfiguration(from: habit, completed: saved.isCompleted, on: day)
                saved.habitSettings = updated
                if updated != previous {
                    try reconcile(saved, journal: journal, modelContext: modelContext, now: now)
                }
            }
            try saveChanges(modelContext)
            return saved
        } catch {
            journal.restore(modelContext: modelContext)
            throw error
        }
    }

    private func reconcile(_ project: Project, journal: EditorMutationJournal,
                           modelContext: ModelContext, now: Date) throws {
        guard let habit = HabitDefinition(project: project) else { return }
        let todos = try modelContext.fetch(FetchDescriptor<Todo>())
        for todo in todos where habit.owns(todo) { journal.capture(todo) }
        HabitScheduleChangeReconciler(calendar: calendar, dayBoundary: dayBoundary)
            .reconcile(habit: habit, todos: todos, modelContext: modelContext, now: now)
    }

    func setCompleted(_ completed: Bool, for project: Project,
                      modelContext: ModelContext, now: Date = .now) throws {
        guard project.isCompleted != completed else { return }
        let journal = EditorMutationJournal(modelContext: modelContext)
        journal.capture(project)
        do {
            project.completedAt = completed ? now : nil
            project.updatedAt = now
            if var settings = project.habitSettings {
                settings.updateActivity(completed: completed, on: dayBoundary.day(containing: now, calendar: calendar))
                project.habitSettings = settings
                try reconcile(project, journal: journal, modelContext: modelContext, now: now)
            }
            try saveChanges(modelContext)
        } catch {
            journal.restore(modelContext: modelContext)
            throw error
        }
    }
}
