//
//  TodoValidation.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import Foundation

struct TodoDraft {
    var title: String
    var notes: String
    var direction: Direction?
    var measurement: TodoMeasurement
    var priority: TodoPriority
    var isRoomIfPossible: Bool
    var plannedAmount: Int?
    var actualProgress: Int
    var scheduledDate: Date?
    var deadline: Date?

    init(
        title: String = "",
        notes: String = "",
        direction: Direction? = nil,
        measurement: TodoMeasurement = .checkbox,
        priority: TodoPriority = .medium,
        isRoomIfPossible: Bool = false,
        plannedAmount: Int? = nil,
        actualProgress: Int = 0,
        scheduledDate: Date? = .now,
        deadline: Date? = nil
    ) {
        self.title = title
        self.notes = notes
        self.direction = direction
        self.measurement = measurement
        self.priority = priority
        self.isRoomIfPossible = isRoomIfPossible
        self.plannedAmount = plannedAmount
        self.actualProgress = actualProgress
        self.scheduledDate = scheduledDate
        self.deadline = deadline
    }

    init(todo: Todo) {
        self.title = todo.title
        self.notes = todo.notes ?? ""
        self.direction = todo.direction
        self.measurement = todo.measurement
        self.priority = todo.priority
        self.isRoomIfPossible = todo.isRoomIfPossible
        self.plannedAmount = todo.plannedAmount
        self.actualProgress = todo.actualProgress
        self.scheduledDate = todo.scheduledDate
        self.deadline = todo.deadline
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedNotes: String? {
        let value = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

enum TodoValidationError: Error, Equatable, LocalizedError {
    case invalidPlannedAmount
    case invalidActualProgress

    var errorDescription: String? {
        switch self {
        case .invalidPlannedAmount:
            String(localized: "予定量は1以上にしてください。")
        case .invalidActualProgress:
            String(localized: "進捗は0以上にしてください。")
        }
    }
}

struct TodoValidator {
    func validate(_ draft: TodoDraft) -> [TodoValidationError] {
        var errors: [TodoValidationError] = []

        if draft.measurement != .checkbox, (draft.plannedAmount ?? 0) <= 0 {
            errors.append(.invalidPlannedAmount)
        }

        if draft.actualProgress < 0 {
            errors.append(.invalidActualProgress)
        }

        return errors
    }
}
