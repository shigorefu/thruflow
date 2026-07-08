//
//  Direction.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import Foundation
import SwiftData

enum DirectionType: String, CaseIterable, Codable, Identifiable {
    case must
    case neutral
    case bonus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .must:
            "必須"
        case .neutral:
            "通常"
        case .bonus:
            "ボーナス"
        }
    }

    var description: String {
        switch self {
        case .must:
            "今日の達成条件に入る重要な方向です。"
        case .neutral:
            "必要なときにタスクを計画する作業領域です。"
        case .bonus:
            "できると良い任意の活動です。日の達成は妨げません。"
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
            "回数"
        case .focusBlocks:
            "集中ブロック"
        case .minutes:
            "分"
        case .hours:
            "時間"
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
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        type: DirectionType,
        symbolName: String = "circle",
        colorHex: String = "#3B82F6",
        goalTarget: Int? = nil,
        goalPeriod: GoalPeriod? = nil,
        goalUnit: GoalUnit? = nil,
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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
    }

    var type: DirectionType {
        get { DirectionType(rawValue: typeRawValue) ?? .neutral }
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

    var isArchived: Bool {
        archivedAt != nil
    }

    var hasGoal: Bool {
        goalTarget != nil && goalPeriod != nil && goalUnit != nil
    }

    func update(
        name: String,
        type: DirectionType,
        symbolName: String,
        colorHex: String,
        goalTarget: Int?,
        goalPeriod: GoalPeriod?,
        goalUnit: GoalUnit?,
        now: Date = .now
    ) {
        self.name = name
        self.type = type
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.goalTarget = goalTarget
        self.goalPeriod = goalPeriod
        self.goalUnit = goalUnit
        updatedAt = now
    }

    func archive(now: Date = .now) {
        archivedAt = now
        updatedAt = now
    }
}

extension Direction {
    static var sample: Direction {
        Direction(
            name: "読書",
            type: .must,
            symbolName: "book.closed",
            colorHex: "#10B981",
            goalTarget: 1,
            goalPeriod: .daily,
            goalUnit: .focusBlocks
        )
    }
}
