//
//  Direction.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import Foundation
import SwiftData

enum DirectionType: String, CaseIterable, Codable, Identifiable {
    case habit
    case neutral
    case nice

    var id: String { rawValue }

    static func normalized(rawValue: String) -> DirectionType? {
        switch rawValue {
        case DirectionType.habit.rawValue, "must":
            .habit
        case DirectionType.neutral.rawValue:
            .neutral
        case DirectionType.nice.rawValue, "bonus":
            .nice
        default:
            nil
        }
    }

    var displayName: String {
        switch self {
        case .habit:
            "習慣"
        case .neutral:
            "通常"
        case .nice:
            "ナイス"
        }
    }

    var description: String {
        switch self {
        case .habit:
            "予定日にタスクへ自動で入る習慣です。"
        case .neutral:
            "必要なときにタスクを計画する作業領域です。"
        case .nice:
            "できると嬉しい任意の活動です。"
        }
    }
}

enum GoalPeriod: String, CaseIterable, Codable, Identifiable {
    case daily
    case weekly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily:
            "毎日"
        case .weekly:
            "毎週"
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
            "回"
        case .focusBlocks:
            "フローブロック"
        case .minutes:
            "分"
        case .hours:
            "時間"
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
            "毎日"
        case .weeklyCount:
            "週回"
        case .weekdays:
            "曜日"
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
            "日"
        case .monday:
            "月"
        case .tuesday:
            "火"
        case .wednesday:
            "水"
        case .thursday:
            "木"
        case .friday:
            "金"
        case .saturday:
            "土"
        }
    }
}

@Model
final class Direction {
    var id: UUID
    var name: String
    var typeRawValue: String
    var symbolName: String
    var colorHex: String
    var goalTarget: Int?
    var goalPeriodRawValue: String?
    var goalUnitRawValue: String?
    var goalScheduleRawValue: String?
    var weeklyTargetCount: Int?
    var weekdayMask: Int?
    var focusDurationSeconds: Int?
    var sortIndex: Int = 0
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        type: DirectionType,
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

    var type: DirectionType {
        get { DirectionType.normalized(rawValue: typeRawValue) ?? .neutral }
        set { typeRawValue = newValue.rawValue }
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

    func update(
        name: String,
        type: DirectionType,
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

extension Direction {
    static var sample: Direction {
        Direction(
            name: "読書",
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
