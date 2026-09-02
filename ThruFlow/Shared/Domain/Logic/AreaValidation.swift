//
//  AreaValidation.swift
//  ThruFlow
//
//

import Foundation

struct AreaDraft {
    var name: String
    var type: AreaType
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
        type: AreaType = .neutral,
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

    init(area: Area) {
        self.name = area.name
        self.type = area.type
        self.symbolName = area.symbolName
        self.colorHex = area.colorHex
        self.goalEnabled = area.hasGoal
        self.goalTarget = area.goalTarget
        self.goalPeriod = area.goalPeriod ?? .daily
        self.goalUnit = area.goalUnit ?? .occurrences
        self.goalSchedule = area.goalSchedule ?? .everyDay
        self.weeklyTargetCount = area.weeklyTargetCount ?? 1
        self.weekdayMask = area.weekdayMask
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedSymbolName: String {
        EmojiValidation.normalizedSingleEmoji(from: symbolName) ?? "🎯"
    }
}

enum AreaValidationError: Error, Equatable, LocalizedError {
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

struct AreaValidator {
    func validate(_ draft: AreaDraft) -> [AreaValidationError] {
        var errors: [AreaValidationError] = []

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
