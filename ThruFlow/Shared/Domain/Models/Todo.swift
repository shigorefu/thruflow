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
            String(localized: "チェック")
        case .focusBlocks:
            String(localized: "集中ブロック")
        case .minutes:
            String(localized: "分")
        }
    }
}

enum TodoPriority: String, CaseIterable, Codable, Identifiable {
    case high
    case medium
    case low

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .high:
            String(localized: "高")
        case .medium:
            String(localized: "中")
        case .low:
            String(localized: "低い")
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
            String(localized: "進行中")
        case .completed:
            String(localized: "完了")
        case .archived:
            String(localized: "アーカイブ")
        }
    }
}

@Model
final class Todo {
    var id: UUID
    var title: String
    var notes: String?
    var hashtagsRawValue: String?
    var direction: Direction?
    var measurementRawValue: String
    var priorityRawValue: String = TodoPriority.medium.rawValue
    var isRoomIfPossible: Bool = false
    var plannedAmount: Int?
    var actualProgress: Int
    var focusDurationSeconds: Int?
    var statusRawValue: String
    var completedAt: Date?
    var scheduledDate: Date?
    var deadline: Date?
    var sortIndex: Int = 0
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        hashtags: [String] = [],
        direction: Direction,
        measurement: TodoMeasurement = .checkbox,
        priority: TodoPriority = .medium,
        isRoomIfPossible: Bool = false,
        plannedAmount: Int? = nil,
        actualProgress: Int = 0,
        focusDurationSeconds: Int? = nil,
        status: TodoStatus = .active,
        completedAt: Date? = nil,
        scheduledDate: Date? = nil,
        deadline: Date? = nil,
        sortIndex: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        archivedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.hashtagsRawValue = TodoHashtagCodec.encode(hashtags)
        self.direction = direction
        self.measurementRawValue = measurement.rawValue
        self.priorityRawValue = priority.rawValue
        self.isRoomIfPossible = isRoomIfPossible
        self.plannedAmount = plannedAmount
        self.actualProgress = actualProgress
        self.focusDurationSeconds = focusDurationSeconds
        self.statusRawValue = status.rawValue
        self.completedAt = completedAt
        self.scheduledDate = scheduledDate
        self.deadline = deadline
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
        self.deletedAt = deletedAt
    }


    var measurement: TodoMeasurement {
        get { TodoMeasurement(rawValue: measurementRawValue) ?? .checkbox }
        set { measurementRawValue = newValue.rawValue }
    }

    var hashtags: [String] {
        get { TodoHashtagCodec.decode(hashtagsRawValue) }
        set { hashtagsRawValue = TodoHashtagCodec.encode(newValue) }
    }

    var priority: TodoPriority {
        get { TodoPriority(rawValue: priorityRawValue) ?? .medium }
        set {
            priorityRawValue = newValue.rawValue
            if newValue != .low {
                isRoomIfPossible = false
            }
        }
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

    var recordedFocusSeconds: Int {
        get { max(0, focusDurationSeconds ?? 0) }
        set { focusDurationSeconds = max(0, newValue) }
    }

    func update(
        title: String,
        notes: String?,
        hashtags: [String],
        direction: Direction,
        measurement: TodoMeasurement,
        priority: TodoPriority,
        isRoomIfPossible: Bool,
        plannedAmount: Int?,
        actualProgress: Int,
        scheduledDate: Date?,
        deadline: Date?,
        now: Date = .now
    ) {
        self.title = title
        self.notes = notes
        self.hashtags = hashtags
        self.direction = direction
        self.measurement = measurement
        self.priority = priority
        self.isRoomIfPossible = priority == .low && isRoomIfPossible
        self.plannedAmount = plannedAmount
        self.actualProgress = actualProgress
        self.scheduledDate = scheduledDate
        self.deadline = deadline
        let nextStatus = TodoProgressCalculator().status(
            measurement: measurement,
            plannedAmount: plannedAmount,
            actualProgress: actualProgress
        )
        updateCompletionDate(for: nextStatus, now: now)
        self.status = nextStatus
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

        updateCompletionDate(for: status, now: now)
        updatedAt = now
    }

    @discardableResult
    func setManuallyCompleted(_ completed: Bool, now: Date = .now) -> Bool {
        guard measurement == .checkbox else { return false }
        setCompleted(completed, now: now)
        return true
    }

    func setProgress(_ value: Int, now: Date = .now) {
        actualProgress = max(0, value)
        let nextStatus = TodoProgressCalculator().status(
            measurement: measurement,
            plannedAmount: plannedAmount,
            actualProgress: actualProgress
        )
        updateCompletionDate(for: nextStatus, now: now)
        status = nextStatus
        updatedAt = now
    }

    func archive(now: Date = .now) {
        archivedAt = now
        status = .archived
        updatedAt = now
    }

    func softDelete(now: Date = .now) {
        deletedAt = now
        updatedAt = now
    }

    func reschedule(to date: Date?, now: Date = .now) {
        scheduledDate = date
        updatedAt = now
    }

    func setSortIndex(_ value: Int, now: Date = .now) {
        sortIndex = value
        updatedAt = now
    }

    func addFocusDuration(seconds: Int, now: Date = .now) {
        recordedFocusSeconds += max(0, seconds)
        updatedAt = now
    }

    func setMemo(_ memo: String?, now: Date = .now) {
        let trimmed = memo?.trimmingCharacters(in: .whitespacesAndNewlines)
        notes = trimmed?.isEmpty == true ? nil : trimmed
        updatedAt = now
    }

    private func updateCompletionDate(for nextStatus: TodoStatus, now: Date) {
        if nextStatus == .completed {
            completedAt = completedAt ?? now
        } else {
            completedAt = nil
        }
    }
}

extension Todo {
    static func sample(direction: Direction = .sample) -> Todo {
        Todo(
            title: String(localized: "発表資料を作る"),
            notes: String(localized: "最初の構成を整理する"),
            direction: direction,
            measurement: .focusBlocks,
            plannedAmount: 3,
            scheduledDate: .now
        )
    }
}
