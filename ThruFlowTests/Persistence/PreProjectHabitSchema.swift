import Foundation
import SwiftData
@testable import ThruFlow

/// Disk-migration fixture with Projects and task timing, before Project Habit scalars.
enum PreProjectHabitSchema: VersionedSchema {
    typealias Area = Direction
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Direction.self, Project.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self] }

    @Model
    final class Direction {
        var id: UUID = UUID()
        var name: String = ""
        var systemRoleRawValue: String?
        var typeRawValue: String = AreaType.neutral.rawValue
        var symbolName: String = "🎯"
        var colorHex: String = "#007AFF"
        var goalTarget: Int?
        var goalPeriodRawValue: String?
        var goalUnitRawValue: String?
        var goalScheduleRawValue: String?
        var weeklyTargetCount: Int?
        var weekdayMask: Int?
        var focusDurationSeconds: Int?
        var habitPausePeriodsRawValue: String?
        var sortIndex: Int = 0
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        var archivedAt: Date?
        @Relationship(inverse: \Project.direction)
        var projects: [Project]?
        @Relationship(inverse: \Todo.direction)
        var todos: [Todo]?
        @Relationship(inverse: \FlowSession.direction)
        var flowSessions: [FlowSession]?
        @Relationship(inverse: \FlowSegment.direction)
        var flowSegments: [FlowSegment]?

        init() {}
    }

    @Model
    final class Project {
        var id: UUID = UUID()
        var name: String = ""
        var notes: String?
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        var completedAt: Date?
        var direction: Direction?
        @Relationship(inverse: \Todo.project) var todos: [Todo]?
        init() {}
    }

    @Model
    final class Todo {
        var id: UUID = UUID()
        var title: String = ""
        var notes: String?
        var hashtagsRawValue: String?
        /// Optional scalar for additive local-store and CloudKit migration.
        var externalTaskLinkRawValue: String? = nil
        /// Nil preserves classification of records created before this field existed.
        var habitOccurrence: Bool? = nil
        /// Persisted as `direction` for SwiftData and CloudKit compatibility.
        var direction: Area?
        var project: Project?
        var measurementRawValue: String = TodoMeasurement.checkbox.rawValue
        var priorityRawValue: String = TodoPriority.medium.rawValue
        var isRoomIfPossible: Bool = false
        var plannedAmount: Int?
        var actualProgress: Int = 0
        var focusDurationSeconds: Int?
        var statusRawValue: String = TodoStatus.active.rawValue
        var completedAt: Date?
        var scheduledDate: Date?
        var scheduledTimeMinutes: Int?
        var reminderEnabled: Bool = false
        var scheduledTimeUpdatedAt: Date?
        var deadline: Date?
        var sortIndex: Int = 0
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        var archivedAt: Date?
        var deletedAt: Date?
        @Relationship(inverse: \FlowSession.todo)
        var flowSessions: [FlowSession]?
        @Relationship(inverse: \FlowSegment.todo)
        var flowSegments: [FlowSegment]?

        init() {}
    }

    @Model
    final class FlowSession {
        var id: UUID = UUID()
        var seriesID: UUID?
        /// Optional additive field; nil legacy records are never auto-exported.
        var recordingDeviceID: String?
        /// Persisted as `direction` for SwiftData and CloudKit compatibility.
        var direction: Area?
        var todo: Todo?
        var intent: String = ""
        var result: String?
        var modeRawValue: String = FlowMode.twentyFiveFive.rawValue
        var phaseRawValue: String = FlowPhase.focusing.rawValue
        var statusRawValue: String = FlowSessionStatus.active.rawValue
        var startedAt: Date = Date.now
        var plannedEndAt: Date = Date.now
        var endedAt: Date?
        var plannedFocusDurationSeconds: Int = 0
        var actualFocusDurationSeconds: Int?
        var plannedBreakDurationSeconds: Int = 0
        var accumulatedPauseDurationSeconds: Int = 0
        var pausedAt: Date?
        var phaseBeforePauseRawValue: String?
        var completedAt: Date?
        var breakStartedAt: Date?
        var wasPaused: Bool = false
        var interruptionCount: Int = 0
        var runtimeRevision: Int = 0
        var runtimeMutationID: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        @Relationship(deleteRule: .cascade, inverse: \FlowSegment.session)
        var segments: [FlowSegment]?

        init() {}
    }

    @Model
    final class FlowSegment {
        var id: UUID = UUID()
        var session: FlowSession?
        /// Persisted as `direction` for SwiftData and CloudKit compatibility.
        var direction: Area?
        var todo: Todo?
        var startedAt: Date = Date.now
        var endedAt: Date?
        var startFocusSeconds: Int = 0
        var endFocusSeconds: Int?
        var createdAt: Date = Date.now

        init() {}
    }

    @Model
    final class FlowBreak {
        var id: UUID = UUID()
        var seriesID: UUID = UUID()
        var previousSessionID: UUID = UUID()
        var nextSessionID: UUID?
        var startedAt: Date = Date.now
        var timerStoppedAt: Date?
        var connectedUntil: Date?
        var adjustedEndAt: Date?
        var plannedDurationSeconds: Int = 0
        var isLongBreak: Bool = false
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        var deletedAt: Date?

        init() {}
    }

}
