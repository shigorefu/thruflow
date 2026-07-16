//
//  FlowBreak.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/14.
//

import Foundation
import SwiftData

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

    init(
        id: UUID = UUID(),
        seriesID: UUID,
        previousSessionID: UUID,
        nextSessionID: UUID? = nil,
        startedAt: Date,
        timerStoppedAt: Date? = nil,
        connectedUntil: Date? = nil,
        adjustedEndAt: Date? = nil,
        plannedDurationSeconds: Int,
        isLongBreak: Bool = false,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.seriesID = seriesID
        self.previousSessionID = previousSessionID
        self.nextSessionID = nextSessionID
        self.startedAt = startedAt
        self.timerStoppedAt = timerStoppedAt
        self.connectedUntil = connectedUntil
        self.adjustedEndAt = adjustedEndAt
        self.plannedDurationSeconds = max(0, plannedDurationSeconds)
        self.isLongBreak = isLongBreak
        self.createdAt = createdAt ?? startedAt
        self.updatedAt = updatedAt ?? startedAt
        self.deletedAt = deletedAt
    }

    var continuationDeadline: Date {
        startedAt.addingTimeInterval(TimeInterval(FlowSeriesPolicy.continuationWindow(
            forPlannedBreakSeconds: plannedDurationSeconds
        )))
    }

    var isDeleted: Bool {
        deletedAt != nil
    }

    func resolvedEndAt(referenceDate: Date) -> Date {
        max(adjustedEndAt ?? connectedUntil ?? timerStoppedAt ?? referenceDate, startedAt)
    }

    func stopTimer(at date: Date) {
        timerStoppedAt = max(date, startedAt)
        updatedAt = date
    }

    func connect(to sessionID: UUID, at date: Date) {
        nextSessionID = sessionID
        connectedUntil = max(date, startedAt)
        updatedAt = date
    }
}
