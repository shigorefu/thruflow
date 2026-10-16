import Foundation
import SwiftData

enum TaskEditingError: Error {
    case validation([TodoValidationError])
}

/// The save boundary for manually created Tasks and native Task editors.
/// Presentation callbacks belong to callers and must run only after this returns.
@MainActor
struct TaskEditingService {
    private let saveChanges: (ModelContext) throws -> Void

    init(saveChanges: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.saveChanges = saveChanges
    }

    func validationErrors(for draft: TodoDraft, editing todo: Todo? = nil) -> [TodoValidationError] {
        TodoValidator().validate(effectiveDraft(draft, editing: todo))
    }

    @discardableResult
    func save(
        draft: TodoDraft,
        editing todo: Todo? = nil,
        modelContext: ModelContext,
        now: Date = .now
    ) throws -> Todo {
        let draft = effectiveDraft(draft, editing: todo)
        let errors = TodoValidator().validate(draft)
        guard errors.isEmpty else { throw TaskEditingError.validation(errors) }

        do {
            let area = try resolvedArea(draft.area, modelContext: modelContext, now: now)
            let plannedAmount = draft.measurement == .checkbox ? nil : draft.plannedAmount
            let actualProgress = draft.measurement == .checkbox
                ? min(max(draft.actualProgress, 0), 1) : draft.actualProgress
            let savedTodo: Todo
            if let todo {
                todo.update(
                    title: draft.trimmedTitle, notes: draft.trimmedNotes, hashtags: draft.hashtags,
                    area: area, measurement: draft.measurement, priority: draft.priority,
                    isRoomIfPossible: draft.priority == .low && draft.isRoomIfPossible,
                    plannedAmount: plannedAmount, actualProgress: actualProgress,
                    scheduledDate: draft.scheduledDate, deadline: draft.deadline, now: now
                )
                savedTodo = todo
            } else {
                var descriptor = FetchDescriptor<Todo>(sortBy: [SortDescriptor(\Todo.sortIndex)])
                descriptor.fetchLimit = 1
                let sortIndex = (try modelContext.fetch(descriptor).first?.sortIndex ?? 0) - 1
                let status = TodoProgressCalculator().status(
                    measurement: draft.measurement, plannedAmount: plannedAmount,
                    actualProgress: actualProgress
                )
                let created = Todo(
                    title: draft.trimmedTitle, notes: draft.trimmedNotes, hashtags: draft.hashtags,
                    area: area, habitOccurrence: false, measurement: draft.measurement,
                    priority: draft.priority,
                    isRoomIfPossible: draft.priority == .low && draft.isRoomIfPossible,
                    plannedAmount: plannedAmount, actualProgress: actualProgress, status: status,
                    completedAt: status == .completed ? now : nil,
                    scheduledDate: draft.scheduledDate, deadline: draft.deadline,
                    sortIndex: sortIndex, createdAt: now, updatedAt: now
                )
                modelContext.insert(created)
                savedTodo = created
            }
            try saveChanges(modelContext)
            return savedTodo
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func effectiveDraft(_ draft: TodoDraft, editing todo: Todo?) -> TodoDraft {
        guard let todo, todo.isHabitOccurrence else { return draft }
        var result = draft
        // A generated occurrence keeps its Area-owned structure and schedule.
        result.area = todo.area
        result.measurement = todo.measurement
        result.plannedAmount = todo.plannedAmount
        result.priority = todo.priority
        result.isRoomIfPossible = todo.isRoomIfPossible
        result.scheduledDate = todo.scheduledDate
        result.deadline = todo.deadline
        return result
    }

    private func resolvedArea(_ area: Area?, modelContext: ModelContext, now: Date) throws -> Area {
        if let area { return area }
        let areas = try modelContext.fetch(FetchDescriptor<Area>())
        if let inbox = DefaultAreas.existingTaskInbox(in: areas) { return inbox }
        let inbox = DefaultAreas.makeTaskInbox(now: now)
        modelContext.insert(inbox)
        return inbox
    }
}
