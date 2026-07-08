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

    init(
        name: String = "",
        type: DirectionType = .must,
        symbolName: String = "🎯",
        colorHex: String = "#007AFF",
        goalEnabled: Bool = false,
        goalTarget: Int? = nil,
        goalPeriod: GoalPeriod? = .daily,
        goalUnit: GoalUnit? = .focusBlocks
    ) {
        self.name = name
        self.type = type
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.goalEnabled = goalEnabled
        self.goalTarget = goalTarget
        self.goalPeriod = goalPeriod
        self.goalUnit = goalUnit
    }

    init(direction: Direction) {
        self.name = direction.name
        self.type = direction.type
        self.symbolName = direction.symbolName
        self.colorHex = direction.colorHex
        self.goalEnabled = direction.hasGoal
        self.goalTarget = direction.goalTarget
        self.goalPeriod = direction.goalPeriod ?? .daily
        self.goalUnit = direction.goalUnit ?? .focusBlocks
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedSymbolName: String {
        let trimmed = symbolName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "🎯" : trimmed
    }
}

enum DirectionValidationError: Error, Equatable, LocalizedError {
    case emptyName
    case invalidGoalTarget
    case missingGoalPeriod
    case missingGoalUnit

    var errorDescription: String? {
        switch self {
        case .emptyName:
            "名前を入力してください。"
        case .invalidGoalTarget:
            "目標値は1以上にしてください。"
        case .missingGoalPeriod:
            "目標を使う場合は期間を選んでください。"
        case .missingGoalUnit:
            "目標を使う場合は単位を選んでください。"
        }
    }
}

struct DirectionValidator {
    func validate(_ draft: DirectionDraft) -> [DirectionValidationError] {
        var errors: [DirectionValidationError] = []

        if draft.trimmedName.isEmpty {
            errors.append(.emptyName)
        }

        if draft.goalEnabled {
            if (draft.goalTarget ?? 0) <= 0 {
                errors.append(.invalidGoalTarget)
            }

            if draft.goalPeriod == nil {
                errors.append(.missingGoalPeriod)
            }

            if draft.goalUnit == nil {
                errors.append(.missingGoalUnit)
            }
        }

        return errors
    }
}
