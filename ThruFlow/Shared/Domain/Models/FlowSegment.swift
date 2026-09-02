//
//  FlowSegment.swift
//  ThruFlow
//
//

import Foundation
import SwiftData

@Model
final class FlowSegment {
    var id: UUID = UUID()
    var session: FlowSession?
    /// Persisted as `direction` for SwiftData and CloudKit compatibility.
    var direction: Area?
    var todo: Todo?
    var startedAt: Date = Date.now
    var endedAt: Date?
    var startFocusSeconds: Int = 0
    var endFocusSeconds: Int?
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        session: FlowSession,
        area: Area,
        todo: Todo?,
        startedAt: Date,
        startFocusSeconds: Int
    ) {
        self.id = id
        self.session = session
        self.direction = area
        self.todo = todo
        self.startedAt = startedAt
        self.startFocusSeconds = max(0, startFocusSeconds)
        self.createdAt = startedAt
    }

    var area: Area? {
        get { direction }
        set { direction = newValue }
    }

    var resolvedFocusSeconds: Int {
        max(0, (endFocusSeconds ?? startFocusSeconds) - startFocusSeconds)
    }

    func close(at date: Date, totalFocusSeconds: Int) {
        endedAt = max(date, startedAt)
        endFocusSeconds = max(startFocusSeconds, totalFocusSeconds)
    }

    func reopen() {
        endedAt = nil
        endFocusSeconds = nil
    }
}
