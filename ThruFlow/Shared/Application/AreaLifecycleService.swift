import Foundation
import SwiftData

enum AreaLifecycleError: Error { case systemArea }

/// Archive and restore are one saved operation on every client.
@MainActor
struct AreaLifecycleService {
    var calendar: Calendar
    var dayBoundary: AppDayBoundary
    private let saveChanges: (ModelContext) throws -> Void

    init(calendar: Calendar = .current, dayBoundary: AppDayBoundary = .midnight,
         saveChanges: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.calendar = calendar
        self.dayBoundary = dayBoundary
        self.saveChanges = saveChanges
    }

    func archive(_ area: Area, modelContext: ModelContext, now: Date = .now) throws {
        guard !DefaultAreas.isTaskInbox(area) else { throw AreaLifecycleError.systemArea }
        let todos = try modelContext.fetch(FetchDescriptor<Todo>()).filter { $0.area?.id == area.id }
        let journal = EditorMutationJournal(modelContext: modelContext)
        journal.capture(area)
        for todo in todos { journal.capture(todo) }
        do {
            area.archive(now: now, calendar: calendar, dayBoundary: dayBoundary)
            ArchivedHabitTodoReconciler(calendar: calendar, dayBoundary: dayBoundary)
                .reconcile(todos: todos, now: now)
            try saveChanges(modelContext)
        } catch {
            journal.restore(modelContext: modelContext)
            throw error
        }
    }

    func restore(_ area: Area, modelContext: ModelContext, now: Date = .now) throws {
        guard !DefaultAreas.isTaskInbox(area) else { throw AreaLifecycleError.systemArea }
        guard let archivedAt = area.archivedAt else { return }
        let journal = EditorMutationJournal(modelContext: modelContext)
        journal.capture(area)
        do {
            // Retain the inactive interval using the existing pause representation.
            // Never undelete a retired occurrence or erase a separate manual pause.
            let firstDay = dayBoundary.day(containing: archivedAt, calendar: calendar)
            let today = dayBoundary.day(containing: now, calendar: calendar)
            if area.type == .habit, firstDay < today {
                area.habitPausePeriods += [HabitPausePeriod(startsOn: firstDay, endsBefore: today, createdAt: now)]
            }
            area.archivedAt = nil
            area.updatedAt = now
            try saveChanges(modelContext)
        } catch {
            journal.restore(modelContext: modelContext)
            throw error
        }
    }
}
