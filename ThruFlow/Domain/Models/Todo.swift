//
//  Todo.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import Foundation
import SwiftData

enum TodoMeasurement: String, CaseIterable, Codable, Identifiable {
    case checkbox
    case focusBlocks
    case minutes

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .checkbox:
            "チェック"
        case .focusBlocks:
            "集中ブロック"
        case .minutes:
            "分"
        }
    }
}

enum TodoStatus: String, CaseIterable, Codable, Identifiable {
    case active
    case completed
    case archived

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .active:
            "進行中"
        case .completed:
            "完了"
        case .archived:
            "アーカイブ"
        }
    }
}

@Model
final class Todo {
    var id: UUID
    var title: String
    var notes: String?
    var direction: Direction?
    var measurementRawValue: String
    var plannedAmount: Int?
    var actualProgress: Int
    var statusRawValue: String
    var scheduledDate: Date?
    var deadline: Date?
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        direction: Direction,
        measurement: TodoMeasurement = .checkbox,
        plannedAmount: Int? = nil,
        actualProgress: Int = 0,
        status: TodoStatus = .active,
        scheduledDate: Date? = nil,
        deadline: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        archivedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.direction = direction
        self.measurementRawValue = measurement.rawValue
        self.plannedAmount = plannedAmount
        self.actualProgress = actualProgress
        self.statusRawValue = status.rawValue
        self.scheduledDate = scheduledDate
        self.deadline = deadline
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
        self.deletedAt = deletedAt
    }

    var measurement: TodoMeasurement {
        get { TodoMeasurement(rawValue: measurementRawValue) ?? .checkbox }
        set { measurementRawValue = newValue.rawValue }
    }

    var status: TodoStatus {
        get { TodoStatus(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
    }

    var isArchived: Bool {
        archivedAt != nil || status == .archived
    }

    var isDeleted: Bool {
        deletedAt != nil
    }

    var isCompleted: Bool {
        status == .completed
    }

    func update(
        title: String,
        notes: String?,
        direction: Direction,
        measurement: TodoMeasurement,
        plannedAmount: Int?,
        actualProgress: Int,
        scheduledDate: Date?,
        deadline: Date?,
        now: Date = .now
    ) {
        self.title = title
        self.notes = notes
        self.direction = direction
        self.measurement = measurement
        self.plannedAmount = plannedAmount
        self.actualProgress = actualProgress
        self.scheduledDate = scheduledDate
        self.deadline = deadline
        self.status = TodoProgressCalculator().status(
            measurement: measurement,
            plannedAmount: plannedAmount,
            actualProgress: actualProgress
        )
        updatedAt = now
    }

    func setCompleted(_ completed: Bool, now: Date = .now) {
        switch measurement {
        case .checkbox:
            actualProgress = completed ? 1 : 0
            status = completed ? .completed : .active
        case .focusBlocks, .minutes:
            if completed {
                actualProgress = max(actualProgress, plannedAmount ?? 1)
                status = .completed
            } else {
                status = .active
            }
        }

        updatedAt = now
    }

    func setProgress(_ value: Int, now: Date = .now) {
        actualProgress = max(0, value)
        status = TodoProgressCalculator().status(
            measurement: measurement,
            plannedAmount: plannedAmount,
            actualProgress: actualProgress
        )
        updatedAt = now
    }

    func archive(now: Date = .now) {
        archivedAt = now
        status = .archived
        updatedAt = now
    }
}

extension Todo {
    static func sample(direction: Direction = .sample) -> Todo {
        Todo(
            title: "発表資料を作る",
            notes: "最初の構成を整理する",
            direction: direction,
            measurement: .focusBlocks,
            plannedAmount: 3,
            scheduledDate: .now
        )
    }
}
