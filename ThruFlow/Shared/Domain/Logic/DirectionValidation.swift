//
//  DirectionValidation.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import Foundation

struct DirectionDraft {
    var name: String
    var type: DirectionType
    var symbolName: String
    var colorHex: String
    var goalEnabled: Bool
    var goalTarget: Int?
    var goalPeriod: GoalPeriod?
    var goalUnit: GoalUnit?
    var goalSchedule: GoalScheduleKind?
    var weeklyTargetCount: Int?
    var weekdayMask: Int?

    init(
        name: String = "",
        type: DirectionType = .neutral,
        symbolName: String = "🎯",
        colorHex: String = "#007AFF",
        goalEnabled: Bool = false,
        goalTarget: Int? = nil,
        goalPeriod: GoalPeriod? = .daily,
        goalUnit: GoalUnit? = .occurrences,
        goalSchedule: GoalScheduleKind? = .everyDay,
        weeklyTargetCount: Int? = 1,
        weekdayMask: Int? = nil
    ) {
        self.name = name
        self.type = type
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.goalEnabled = goalEnabled
        self.goalTarget = goalTarget
        self.goalPeriod = goalPeriod
        self.goalUnit = goalUnit
        self.goalSchedule = goalSchedule
        self.weeklyTargetCount = weeklyTargetCount
        self.weekdayMask = weekdayMask
    }

    init(direction: Direction) {
        self.name = direction.name
        self.type = direction.type
        self.symbolName = direction.symbolName
        self.colorHex = direction.colorHex
        self.goalEnabled = direction.hasGoal
        self.goalTarget = direction.goalTarget
        self.goalPeriod = direction.goalPeriod ?? .daily
        self.goalUnit = direction.goalUnit ?? .occurrences
        self.goalSchedule = direction.goalSchedule ?? .everyDay
        self.weeklyTargetCount = direction.weeklyTargetCount ?? 1
        self.weekdayMask = direction.weekdayMask
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedSymbolName: String {
        EmojiValidation.normalizedSingleEmoji(from: symbolName) ?? "🎯"
    }
}

enum DirectionValidationError: Error, Equatable, LocalizedError {
    case emptyName
    case invalidGoalTarget
    case missingGoalUnit
    case missingGoalSchedule
    case invalidWeeklyTargetCount
    case missingWeekdays

    var errorDescription: String? {
        switch self {
        case .emptyName:
            String(localized: "名前を入力してください。")
        case .invalidGoalTarget:
            String(localized: "目標値は1以上にしてください。")
        case .missingGoalUnit:
            String(localized: "目標を使う場合は単位を選んでください。")
        case .missingGoalSchedule:
            String(localized: "習慣の方向は頻度を選んでください。")
        case .invalidWeeklyTargetCount:
            String(localized: "週回は1〜7回で選んでください。")
        case .missingWeekdays:
            String(localized: "曜日を1つ以上選んでください。")
        }
    }
}

struct DirectionValidator {
    func validate(_ draft: DirectionDraft) -> [DirectionValidationError] {
        var errors: [DirectionValidationError] = []

        if draft.trimmedName.isEmpty {
            errors.append(.emptyName)
        }

        if draft.type == .habit {
            if (draft.goalTarget ?? 0) <= 0 {
                errors.append(.invalidGoalTarget)
            }

            if draft.goalUnit == nil {
                errors.append(.missingGoalUnit)
            }

            guard let goalSchedule = draft.goalSchedule else {
                errors.append(.missingGoalSchedule)
                return errors
            }

            switch goalSchedule {
            case .everyDay:
                break
            case .weeklyCount:
                if !(1...7).contains(draft.weeklyTargetCount ?? 0) {
                    errors.append(.invalidWeeklyTargetCount)
                }
            case .weekdays:
                if (draft.weekdayMask ?? 0) == 0 {
                    errors.append(.missingWeekdays)
                }
            }
        }

        return errors
    }
}
