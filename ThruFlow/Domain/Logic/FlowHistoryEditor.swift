//
//  FlowHistoryEditor.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/11.
//

import Foundation
import SwiftData

struct FlowHistoryTimeDraft: Equatable {
    private(set) var startedAt: Date
    private(set) var endedAt: Date
    private(set) var focusMinutes: Int

    init(startedAt: Date, endedAt: Date?, focusSeconds: Int) {
        let resolvedSeconds = max(60, focusSeconds)
        let resolvedMinutes = Self.minutes(between: startedAt, and: endedAt ?? startedAt.addingTimeInterval(TimeInterval(resolvedSeconds)))
        self.startedAt = startedAt
        self.focusMinutes = resolvedMinutes
        self.endedAt = startedAt.addingTimeInterval(TimeInterval(resolvedMinutes * 60))
    }

    var focusSeconds: Int {
        focusMinutes * 60
    }

    mutating func setStartedAt(_ date: Date) {
        let previousMinutes = focusMinutes
        startedAt = date

        if endedAt > date {
            focusMinutes = Self.minutes(between: date, and: endedAt)
        } else {
            focusMinutes = previousMinutes
        }
        endedAt = date.addingTimeInterval(TimeInterval(focusMinutes * 60))
    }

    mutating func setEndedAt(_ date: Date) {
        focusMinutes = Self.minutes(between: startedAt, and: date)
        endedAt = startedAt.addingTimeInterval(TimeInterval(focusMinutes * 60))
    }

    mutating func setFocusMinutes(_ minutes: Int) {
        focusMinutes = min(max(minutes, 1), 720)
        endedAt = startedAt.addingTimeInterval(TimeInterval(focusMinutes * 60))
    }

    private static func minutes(between start: Date, and end: Date) -> Int {
        min(max(Int((end.timeIntervalSince(start) / 60).rounded()), 1), 720)
    }
}

struct FlowHistoryEditor {
    private let reconciler = FlowProgressReconciler()

    @discardableResult
    func createManual(
        todo: Todo?,
        direction: Direction,
        mode: FlowMode,
        startedAt: Date,
        focusSeconds: Int,
        modelContext: ModelContext,
        now: Date = .now
    ) -> FlowSession {
        let adjustedSeconds = max(60, focusSeconds)
        let resolvedDirection = todo?.direction ?? direction
        let endedAt = startedAt.addingTimeInterval(TimeInterval(adjustedSeconds))
        let session = FlowSession(
            direction: resolvedDirection,
            todo: todo,
            mode: mode,
            phase: .completed,
            status: .completed,
            startedAt: startedAt,
            plannedEndAt: endedAt,
            endedAt: endedAt,
            plannedFocusDurationSeconds: adjustedSeconds,
            actualFocusDurationSeconds: adjustedSeconds,
            plannedBreakDurationSeconds: mode.breakDurationSeconds,
            createdAt: now,
            updatedAt: now
        )
        let segment = FlowSegment(
            session: session,
            direction: resolvedDirection,
            todo: todo,
            startedAt: startedAt,
            startFocusSeconds: 0
        )
        segment.close(at: endedAt, totalFocusSeconds: adjustedSeconds)
        session.segments = [segment]

        modelContext.insert(session)
        modelContext.insert(segment)
        reconciler.reconcile(
            session: session,
            modelContext: modelContext,
            now: endedAt
        )
        return session
    }

    func update(
        session: FlowSession,
        todo: Todo?,
        direction: Direction,
        startedAt: Date? = nil,
        focusSeconds: Int,
        memo: String?,
        modelContext: ModelContext,
        now: Date = .now
    ) {
        let previousTodos = [session.todo] + session.segments.map(\.todo)
        let previousDirections = [session.direction] + session.segments.map(\.direction)

        let adjustedSeconds = max(0, focusSeconds)
        let adjustedStart = startedAt ?? session.startedAt
        session.todo = todo
        session.direction = todo?.direction ?? direction
        session.startedAt = adjustedStart
        session.actualFocusDurationSeconds = adjustedSeconds
        session.endedAt = adjustedStart.addingTimeInterval(TimeInterval(adjustedSeconds))
        session.plannedEndAt = session.endedAt ?? adjustedStart
        session.updatedAt = now
        todo?.setMemo(memo, now: now)

        if !session.segments.isEmpty {
            let retained = session.segments[0]
            retained.direction = session.direction
            retained.todo = todo
            retained.startedAt = session.startedAt
            retained.startFocusSeconds = 0
            retained.close(at: session.endedAt ?? now, totalFocusSeconds: adjustedSeconds)

            for segment in session.segments.dropFirst() {
                modelContext.delete(segment)
            }
            session.segments = [retained]
        }

        reconciler.reconcile(
            todos: previousTodos + [todo],
            directions: previousDirections + [session.direction],
            modelContext: modelContext,
            now: session.endedAt ?? now
        )
    }

    func delete(session: FlowSession, modelContext: ModelContext, now: Date = .now) {
        let todos = [session.todo] + session.segments.map(\.todo)
        let directions = [session.direction] + session.segments.map(\.direction)
        deleteRelatedBreaks(sessionID: session.id, modelContext: modelContext, now: now)
        modelContext.delete(session)
        reconciler.reconcile(
            todos: todos,
            directions: directions,
            modelContext: modelContext,
            excludingSessionIDs: [session.id],
            now: now
        )
    }

    func delete(segment: FlowSegment, from session: FlowSession, modelContext: ModelContext, now: Date = .now) {
        let seconds = segment.resolvedFocusSeconds
        let todos = [segment.todo, session.todo] + session.segments.map(\.todo)
        let directions = [segment.direction, session.direction] + session.segments.map(\.direction)

        session.segments.removeAll { $0.id == segment.id }
        modelContext.delete(segment)

        guard !session.segments.isEmpty else {
            deleteRelatedBreaks(sessionID: session.id, modelContext: modelContext, now: now)
            modelContext.delete(session)
            reconciler.reconcile(
                todos: todos,
                directions: directions,
                modelContext: modelContext,
                excludingSessionIDs: [session.id],
                excludingSegmentIDs: [segment.id],
                now: now
            )
            return
        }

        if let actualSeconds = session.actualFocusDurationSeconds {
            session.actualFocusDurationSeconds = max(0, actualSeconds - seconds)
        }
        session.updatedAt = now
        reconciler.reconcile(
            todos: todos,
            directions: directions,
            modelContext: modelContext,
            excludingSegmentIDs: [segment.id],
            now: now
        )
    }

    private func deleteRelatedBreaks(sessionID: UUID, modelContext: ModelContext, now: Date) {
        let breaks = (try? modelContext.fetch(FetchDescriptor<FlowBreak>())) ?? []
        for flowBreak in breaks where
            flowBreak.previousSessionID == sessionID || flowBreak.nextSessionID == sessionID {
            flowBreak.deletedAt = now
            flowBreak.updatedAt = now
        }
    }
}
