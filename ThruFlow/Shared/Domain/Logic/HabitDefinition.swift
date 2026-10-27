import Foundation

/// Shared recurring-goal owner. Project Habits do not inherit the Area's goal or pause.
nonisolated struct HabitDefinition {
    let area: Area
    let project: Project?

    init(area: Area) { self.area = area; project = nil }
    init?(project: Project) {
        guard let area = project.area else { return nil }
        self.area = area; self.project = project
    }
    init?(todo: Todo) {
        guard todo.isHabitOccurrence, let area = todo.area else { return nil }
        self.area = area; project = todo.project
        if let key = todo.habitOwnerKeyRawValue, key != ownerKey { return nil }
        if let project, project.area?.id != area.id { return nil }
    }

    var ownerKey: String { project.map { "project:\($0.id)" } ?? "area:\(area.id)" }
    var goalTarget: Int? { project.map { $0.habitSettings?.goalTarget } ?? area.goalTarget }
    var goalUnit: GoalUnit? { project.map { $0.habitSettings?.goalUnit } ?? area.goalUnit }
    var goalSchedule: GoalScheduleKind? { project.map { $0.habitSettings?.goalSchedule } ?? area.goalSchedule }
    var weeklyTargetCount: Int? { project.map { $0.habitSettings?.weeklyTargetCount } ?? area.weeklyTargetCount }
    var weekdayMask: Int? { project.map { $0.habitSettings?.weekdayMask } ?? area.weekdayMask }
    @MainActor var isActive: Bool {
        guard !area.isArchived, !DefaultAreas.isTaskInbox(area) else { return false }
        if let project { return !project.isCompleted && project.habitSettings?.isEnabled == true }
        return area.type == .habit && area.hasGoal
    }

    func owns(_ todo: Todo) -> Bool {
        guard todo.isHabitOccurrence else { return false }
        if let key = todo.habitOwnerKeyRawValue { return key == ownerKey }
        return todo.area?.id == area.id && todo.project?.id == project?.id
    }

    func isPaused(on day: Date, calendar: Calendar) -> Bool {
        if let project { return project.habitSettings?.wasInactive(on: calendar.startOfDay(for: day)) ?? true }
        return HabitPauseService(calendar: calendar).isPaused(area, on: day)
    }
}
