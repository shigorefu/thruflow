//
//  FlowHistoryEditor.swift
//  ThruFlow
//
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

    func attach(
        todo: Todo,
        to session: FlowSession,
        modelContext: ModelContext,
        now: Date = .now
    ) throws {
        let previousTodos = [session.todo] + session.resolvedSegments.map(\.todo)
        let previousAreas = [session.area] + session.resolvedSegments.map(\.area)

        session.todo = todo
        session.area = todo.area ?? session.area
        session.updatedAt = now

        try reconciler.reconcile(
            todos: previousTodos + [todo],
            areas: previousAreas + [session.area],
            modelContext: modelContext,
            now: session.endedAt ?? now
        )
    }

    func attach(
        todo: Todo,
        to segment: FlowSegment,
        in session: FlowSession,
        modelContext: ModelContext,
        now: Date = .now
    ) throws {
        let previousTodos = [segment.todo, session.todo] + session.resolvedSegments.map(\.todo)
        let previousAreas = [segment.area, session.area] + session.resolvedSegments.map(\.area)

        segment.todo = todo
        segment.area = todo.area ?? segment.area
        session.updatedAt = now
        synchronizeSessionFromSegments(session)

        try reconciler.reconcile(
            todos: previousTodos + [todo],
            areas: previousAreas + [segment.area, session.area],
            modelContext: modelContext,
            now: segment.endedAt ?? now
        )
    }

    @discardableResult
    func createManual(
        todo: Todo?,
        area: Area,
        mode: FlowMode,
        startedAt: Date,
        focusSeconds: Int,
        modelContext: ModelContext,
        now: Date = .now
    ) throws -> FlowSession {
        let adjustedSeconds = max(60, focusSeconds)
        let resolvedArea = todo?.area ?? area
        let endedAt = startedAt.addingTimeInterval(TimeInterval(adjustedSeconds))
        let session = FlowSession(
            area: resolvedArea,
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
            area: resolvedArea,
            todo: todo,
            startedAt: startedAt,
            startFocusSeconds: 0
        )
        segment.close(at: endedAt, totalFocusSeconds: adjustedSeconds)
        session.resolvedSegments = [segment]

        modelContext.insert(session)
        modelContext.insert(segment)
        try reconciler.reconcile(
            session: session,
            modelContext: modelContext,
            now: endedAt
        )
        return session
    }

    func update(
        session: FlowSession,
        todo: Todo?,
        area: Area,
        startedAt: Date? = nil,
        focusSeconds: Int,
        memo: String?,
        modelContext: ModelContext,
        now: Date = .now
    ) throws {
        let previousTodos = [session.todo] + session.resolvedSegments.map(\.todo)
        let previousAreas = [session.area] + session.resolvedSegments.map(\.area)

        let adjustedSeconds = max(0, focusSeconds)
        let adjustedStart = startedAt ?? session.startedAt
        session.todo = todo
        session.area = todo?.area ?? area
        session.startedAt = adjustedStart
        session.actualFocusDurationSeconds = adjustedSeconds
        session.endedAt = adjustedStart.addingTimeInterval(TimeInterval(adjustedSeconds))
        session.plannedEndAt = session.endedAt ?? adjustedStart
        let trimmedMemo = memo?.trimmingCharacters(in: .whitespacesAndNewlines)
        session.result = trimmedMemo?.isEmpty == true ? nil : trimmedMemo
        session.updatedAt = now
        todo?.setMemo(memo, now: now)

        if !session.resolvedSegments.isEmpty {
            let retained = session.resolvedSegments[0]
            retained.area = session.area
            retained.todo = todo
            retained.startedAt = session.startedAt
            retained.startFocusSeconds = 0
            retained.close(at: session.endedAt ?? now, totalFocusSeconds: adjustedSeconds)

            for segment in session.resolvedSegments.dropFirst() {
                modelContext.delete(segment)
            }
            session.resolvedSegments = [retained]
        }

        try reconciler.reconcile(
            todos: previousTodos + [todo],
            areas: previousAreas + [session.area],
            modelContext: modelContext,
            now: session.endedAt ?? now
        )
    }

    func update(
        segment: FlowSegment,
        in session: FlowSession,
        todo: Todo?,
        area: Area,
        startedAt: Date? = nil,
        focusSeconds: Int,
        memo: String?,
        modelContext: ModelContext,
        now: Date = .now
    ) throws {
        let previousTodos = [segment.todo, session.todo] + session.resolvedSegments.map(\.todo)
        let previousAreas = [segment.area, session.area] + session.resolvedSegments.map(\.area)
        let adjustedSeconds = max(0, focusSeconds)
        let adjustedStart = startedAt ?? segment.startedAt

        segment.todo = todo
        segment.area = todo?.area ?? area
        segment.startedAt = adjustedStart
        segment.close(
            at: adjustedStart.addingTimeInterval(TimeInterval(adjustedSeconds)),
            totalFocusSeconds: segment.startFocusSeconds + adjustedSeconds
        )

        let trimmedMemo = memo?.trimmingCharacters(in: .whitespacesAndNewlines)
        session.result = trimmedMemo?.isEmpty == true ? nil : trimmedMemo
        session.updatedAt = now
        todo?.setMemo(memo, now: now)
        synchronizeSessionFromSegments(session)

        try reconciler.reconcile(
            todos: previousTodos + [todo],
            areas: previousAreas + [segment.area],
            modelContext: modelContext,
            now: segment.endedAt ?? now
        )
    }

    func delete(session: FlowSession, modelContext: ModelContext, now: Date = .now) throws {
        let todos = [session.todo] + session.resolvedSegments.map(\.todo)
        let areas = [session.area] + session.resolvedSegments.map(\.area)
        try deleteRelatedBreaks(sessionID: session.id, modelContext: modelContext, now: now)
        modelContext.delete(session)
        try reconciler.reconcile(
            todos: todos,
            areas: areas,
            modelContext: modelContext,
            excludingSessionIDs: [session.id],
            now: now
        )
    }

    func delete(segment: FlowSegment, from session: FlowSession, modelContext: ModelContext, now: Date = .now) throws {
        let todos = [segment.todo, session.todo] + session.resolvedSegments.map(\.todo)
        let areas = [segment.area, session.area] + session.resolvedSegments.map(\.area)

        session.resolvedSegments.removeAll { $0.id == segment.id }
        modelContext.delete(segment)

        guard !session.resolvedSegments.isEmpty else {
            try deleteRelatedBreaks(sessionID: session.id, modelContext: modelContext, now: now)
            modelContext.delete(session)
            try reconciler.reconcile(
                todos: todos,
                areas: areas,
                modelContext: modelContext,
                excludingSessionIDs: [session.id],
                excludingSegmentIDs: [segment.id],
                now: now
            )
            return
        }

        synchronizeSessionFromSegments(session)
        session.updatedAt = now
        try reconciler.reconcile(
            todos: todos,
            areas: areas,
            modelContext: modelContext,
            excludingSegmentIDs: [segment.id],
            now: now
        )
    }

    func move(
        session: FlowSession,
        itemStartedAt: Date,
        to targetDate: Date,
        modelContext: ModelContext,
        now: Date = .now
    ) throws {
        let offset = targetDate.timeIntervalSince(itemStartedAt)
        guard abs(offset) >= 1 else { return }

        session.startedAt = session.startedAt.addingTimeInterval(offset)
        session.plannedEndAt = session.plannedEndAt.addingTimeInterval(offset)
        session.endedAt = session.endedAt?.addingTimeInterval(offset)
        session.updatedAt = now

        for segment in session.resolvedSegments {
            segment.startedAt = segment.startedAt.addingTimeInterval(offset)
            segment.endedAt = segment.endedAt?.addingTimeInterval(offset)
        }

        try reconciler.reconcile(session: session, modelContext: modelContext, now: now)
    }

    private func deleteRelatedBreaks(sessionID: UUID, modelContext: ModelContext, now: Date) throws {
        let breaks = try modelContext.fetch(FetchDescriptor<FlowBreak>())
        for flowBreak in breaks where
            flowBreak.previousSessionID == sessionID || flowBreak.nextSessionID == sessionID {
            flowBreak.deletedAt = now
            flowBreak.updatedAt = now
        }
    }

    private func synchronizeSessionFromSegments(_ session: FlowSession) {
        let segments = session.resolvedSegments.sorted {
            if $0.startedAt == $1.startedAt { return $0.id.uuidString < $1.id.uuidString }
            return $0.startedAt < $1.startedAt
        }
        guard let first = segments.first, let last = segments.last else { return }

        session.startedAt = first.startedAt
        session.actualFocusDurationSeconds = segments.reduce(0) { $0 + $1.resolvedFocusSeconds }
        session.endedAt = segments.compactMap(\.endedAt).max()
            ?? last.startedAt.addingTimeInterval(TimeInterval(last.resolvedFocusSeconds))
        session.plannedEndAt = session.endedAt ?? session.plannedEndAt
        session.todo = last.todo
        session.area = last.todo?.area ?? last.area ?? session.area
    }
}
