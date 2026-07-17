//
//  FlowSegment.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/13.
//

import Foundation
import SwiftData

@Model
final class FlowSegment {
    var id: UUID = UUID()
    var session: FlowSession?
    var direction: Direction?
    var todo: Todo?
    var startedAt: Date = Date.now
    var endedAt: Date?
    var startFocusSeconds: Int = 0
    var endFocusSeconds: Int?
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        session: FlowSession,
        direction: Direction,
        todo: Todo?,
        startedAt: Date,
        startFocusSeconds: Int
    ) {
        self.id = id
        self.session = session
        self.direction = direction
        self.todo = todo
        self.startedAt = startedAt
        self.startFocusSeconds = max(0, startFocusSeconds)
        self.createdAt = startedAt
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
