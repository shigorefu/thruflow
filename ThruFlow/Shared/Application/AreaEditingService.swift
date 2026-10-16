import Foundation
import SwiftData

enum AreaEditingError: Error {
    case validation([AreaValidationError])
}

/// Both native editors validate and reconcile Habit projections in the same save.
@MainActor
struct AreaEditingService {
    let calendar: Calendar
    let dayBoundary: AppDayBoundary
    private let saveChanges: (ModelContext) throws -> Void

    init(
        calendar: Calendar = .current,
        dayBoundary: AppDayBoundary = .midnight,
        saveChanges: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.calendar = calendar
        self.dayBoundary = dayBoundary
        self.saveChanges = saveChanges
    }

    func validationErrors(for draft: AreaDraft) -> [AreaValidationError] {
        AreaValidator().validate(draft.normalizedForEditing)
    }

    @discardableResult
    func save(
        draft: AreaDraft,
        editing area: Area? = nil,
        modelContext: ModelContext,
        now: Date = .now
    ) throws -> Area {
        let draft = draft.normalizedForEditing
        let errors = AreaValidator().validate(draft)
        guard errors.isEmpty else { throw AreaEditingError.validation(errors) }
        let schedule = draft.goalSchedule
        let weeklyCount = schedule == .weeklyCount ? draft.weeklyTargetCount : nil
        let weekdayMask = schedule != nil && schedule != .everyDay ? draft.weekdayMask : nil

        do {
            let savedArea: Area
            if let area {
                let wasHabit = area.type == .habit
                let todos = wasHabit && draft.type == .habit
                    ? try modelContext.fetch(FetchDescriptor<Todo>()) : []
                area.update(
                    name: draft.trimmedName, type: draft.type,
                    symbolName: draft.normalizedSymbolName, colorHex: draft.colorHex,
                    goalTarget: draft.goalTarget, goalPeriod: schedule?.goalPeriod,
                    goalUnit: draft.goalUnit, goalSchedule: schedule,
                    weeklyTargetCount: weeklyCount, weekdayMask: weekdayMask, now: now
                )
                if wasHabit, area.type == .habit {
                    _ = HabitScheduleChangeReconciler(calendar: calendar, dayBoundary: dayBoundary)
                        .reconcile(area: area, todos: todos, modelContext: modelContext, now: now)
                }
                savedArea = area
            } else {
                var descriptor = FetchDescriptor<Area>(sortBy: [SortDescriptor(\Area.sortIndex, order: .reverse)])
                descriptor.fetchLimit = 1
                let sortIndex = (try modelContext.fetch(descriptor).first?.sortIndex ?? -1) + 1
                let created = Area(
                    name: draft.trimmedName, type: draft.type,
                    symbolName: draft.normalizedSymbolName, colorHex: draft.colorHex,
                    goalTarget: draft.goalTarget, goalPeriod: schedule?.goalPeriod,
                    goalUnit: draft.goalUnit, goalSchedule: schedule,
                    weeklyTargetCount: weeklyCount, weekdayMask: weekdayMask,
                    sortIndex: sortIndex, createdAt: now, updatedAt: now
                )
                modelContext.insert(created)
                savedArea = created
            }
            try saveChanges(modelContext)
            return savedArea
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
