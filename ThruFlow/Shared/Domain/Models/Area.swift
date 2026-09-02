//
//  Area.swift
//  ThruFlow
//
//

import Foundation
import SwiftData

enum AreaType: String, CaseIterable, Codable, Identifiable {
    case habit
    case neutral
    case nice

    var id: String { rawValue }

    static func normalized(rawValue: String) -> AreaType? {
        switch rawValue {
        case AreaType.habit.rawValue, "must":
            .habit
        case AreaType.neutral.rawValue:
            .neutral
        case AreaType.nice.rawValue, "bonus":
            .nice
        default:
            nil
        }
    }

    var displayName: String {
        switch self {
        case .habit:
            String(localized: "習慣")
        case .neutral:
            String(localized: "通常")
        case .nice:
            String(localized: "ナイス")
        }
    }

    var description: String {
        switch self {
        case .habit:
            String(localized: "予定日にタスクへ自動で入る習慣です。")
        case .neutral:
            String(localized: "必要なときにタスクを計画する作業領域です。")
        case .nice:
            String(localized: "できると嬉しい任意の活動です。")
        }
    }
}

enum AreaSystemRole: String, Codable {
    case taskInbox
}

enum GoalPeriod: String, CaseIterable, Codable, Identifiable {
    case daily
    case weekly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily:
            String(localized: "毎日")
        case .weekly:
            String(localized: "毎週")
        }
    }
}

enum GoalUnit: String, CaseIterable, Codable, Identifiable {
    case occurrences
    case focusBlocks
    case minutes
    case hours

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .occurrences:
            String(localized: "回")
        case .focusBlocks:
            String(localized: "フローブロック")
        case .minutes:
            String(localized: "分単位")
        case .hours:
            String(localized: "時間単位")
        }
    }
}

enum GoalScheduleKind: String, CaseIterable, Codable, Identifiable {
    case everyDay
    case weeklyCount
    case weekdays

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .everyDay:
            String(localized: "毎日予定")
        case .weeklyCount:
            String(localized: "週回")
        case .weekdays:
            String(localized: "曜日")
        }
    }

    var goalPeriod: GoalPeriod {
        switch self {
        case .everyDay:
            .daily
        case .weeklyCount, .weekdays:
            .weekly
        }
    }
}

enum GoalWeekday: Int, CaseIterable, Codable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 4
    case wednesday = 8
    case thursday = 16
    case friday = 32
    case saturday = 64

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .sunday:
            String(localized: "日曜短縮")
        case .monday:
            String(localized: "月曜短縮")
        case .tuesday:
            String(localized: "火")
        case .wednesday:
            String(localized: "水")
        case .thursday:
            String(localized: "木")
        case .friday:
            String(localized: "金")
        case .saturday:
            String(localized: "土")
        }
    }
}

/// The runtime type name intentionally remains `Direction` because SwiftData
/// and the production CloudKit schema persist it as the entity identifier.
/// Application code uses the `Area` alias declared below.
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
    @Relationship(inverse: \Todo.direction)
    var todos: [Todo]?
    @Relationship(inverse: \FlowSession.direction)
    var flowSessions: [FlowSession]?
    @Relationship(inverse: \FlowSegment.direction)
    var flowSegments: [FlowSegment]?

    init(
        id: UUID = UUID(),
        name: String,
        systemRole: AreaSystemRole? = nil,
        type: AreaType,
        symbolName: String = "🎯",
        colorHex: String = "#007AFF",
        goalTarget: Int? = nil,
        goalPeriod: GoalPeriod? = nil,
        goalUnit: GoalUnit? = nil,
        goalSchedule: GoalScheduleKind? = nil,
        weeklyTargetCount: Int? = nil,
        weekdayMask: Int? = nil,
        focusDurationSeconds: Int? = nil,
        sortIndex: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.systemRoleRawValue = systemRole?.rawValue
        self.typeRawValue = type.rawValue
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.goalTarget = goalTarget
        self.goalPeriodRawValue = goalPeriod?.rawValue
        self.goalUnitRawValue = goalUnit?.rawValue
        self.goalScheduleRawValue = goalSchedule?.rawValue
        self.weeklyTargetCount = weeklyTargetCount
        self.weekdayMask = weekdayMask
        self.focusDurationSeconds = focusDurationSeconds
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
    }

    var type: AreaType {
        get { AreaType.normalized(rawValue: typeRawValue) ?? .neutral }
        set { typeRawValue = newValue.rawValue }
    }

    var systemRole: AreaSystemRole? {
        get {
            guard let systemRoleRawValue else { return nil }
            return AreaSystemRole(rawValue: systemRoleRawValue)
        }
        set { systemRoleRawValue = newValue?.rawValue }
    }

    var goalPeriod: GoalPeriod? {
        get {
            guard let goalPeriodRawValue else { return nil }
            return GoalPeriod(rawValue: goalPeriodRawValue)
        }
        set { goalPeriodRawValue = newValue?.rawValue }
    }

    var goalUnit: GoalUnit? {
        get {
            guard let goalUnitRawValue else { return nil }
            return GoalUnit(rawValue: goalUnitRawValue)
        }
        set { goalUnitRawValue = newValue?.rawValue }
    }

    var goalSchedule: GoalScheduleKind? {
        get {
            if let goalScheduleRawValue {
                return GoalScheduleKind(rawValue: goalScheduleRawValue)
            }

            guard let goalPeriod else { return nil }
            return goalPeriod == .daily ? .everyDay : .weeklyCount
        }
        set { goalScheduleRawValue = newValue?.rawValue }
    }

    var isArchived: Bool {
        archivedAt != nil
    }

    var recordedFocusSeconds: Int {
        get { max(0, focusDurationSeconds ?? 0) }
        set { focusDurationSeconds = max(0, newValue) }
    }

    var hasGoal: Bool {
        goalTarget != nil && goalPeriod != nil && goalUnit != nil && goalSchedule != nil
    }

    var habitPausePeriods: [HabitPausePeriod] {
        get { HabitPausePeriodCodec.decode(habitPausePeriodsRawValue) }
        set { habitPausePeriodsRawValue = HabitPausePeriodCodec.encode(newValue) }
    }

    func update(
        name: String,
        type: AreaType,
        symbolName: String,
        colorHex: String,
        goalTarget: Int?,
        goalPeriod: GoalPeriod?,
        goalUnit: GoalUnit?,
        goalSchedule: GoalScheduleKind? = nil,
        weeklyTargetCount: Int? = nil,
        weekdayMask: Int? = nil,
        now: Date = .now
    ) {
        self.name = name
        self.type = type
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.goalTarget = goalTarget
        self.goalPeriod = goalPeriod
        self.goalUnit = goalUnit
        self.goalSchedule = goalSchedule
        self.weeklyTargetCount = weeklyTargetCount
        self.weekdayMask = weekdayMask
        updatedAt = now
    }

    func archive(now: Date = .now) {
        archivedAt = now
        updatedAt = now
    }

    func addFocusDuration(seconds: Int, now: Date = .now) {
        recordedFocusSeconds += max(0, seconds)
        updatedAt = now
    }

    func setSortIndex(_ value: Int, now: Date = .now) {
        sortIndex = value
        updatedAt = now
    }
}

typealias Area = Direction

extension Area {
    static var sample: Area {
        Area(
            name: String(localized: "読書"),
            type: .habit,
            symbolName: "📚",
            colorHex: "#34C759",
            goalTarget: 1,
            goalPeriod: .daily,
            goalUnit: .focusBlocks,
            goalSchedule: .everyDay
        )
    }
}
