//
//  FlowHistoryEditor.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/11.
//

import Foundation
import SwiftData

struct FlowHistoryEditor {
    func update(
        session: FlowSession,
        todo: Todo?,
        direction: Direction,
        focusSeconds: Int,
        memo: String?,
        modelContext: ModelContext? = nil,
        now: Date = .now
    ) {
        removeSessionProgress(session, now: now)

        let adjustedSeconds = max(0, focusSeconds)
        session.todo = todo
        session.direction = todo?.direction ?? direction
        session.actualFocusDurationSeconds = adjustedSeconds
        session.endedAt = session.startedAt.addingTimeInterval(TimeInterval(adjustedSeconds))
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
                modelContext?.delete(segment)
            }
            session.segments = [retained]
        }

        addProgress(seconds: adjustedSeconds, direction: session.direction, todo: todo, completionDate: session.endedAt ?? now)
    }

    func delete(session: FlowSession, modelContext: ModelContext, now: Date = .now) {
        removeSessionProgress(session, now: now)
        modelContext.delete(session)
    }

    func delete(segment: FlowSegment, from session: FlowSession, modelContext: ModelContext, now: Date = .now) {
        let seconds = segment.resolvedFocusSeconds
        removeProgress(seconds: seconds, direction: segment.direction, todo: segment.todo, now: now)

        session.segments.removeAll { $0.id == segment.id }
        modelContext.delete(segment)

        guard !session.segments.isEmpty else {
            modelContext.delete(session)
            return
        }

        if let actualSeconds = session.actualFocusDurationSeconds {
            session.actualFocusDurationSeconds = max(0, actualSeconds - seconds)
        }
        session.updatedAt = now
    }

    private func removeSessionProgress(_ session: FlowSession, now: Date) {
        if !session.segments.isEmpty {
            for segment in session.segments where segment.resolvedFocusSeconds > 0 {
                removeProgress(
                    seconds: segment.resolvedFocusSeconds,
                    direction: segment.direction,
                    todo: segment.todo,
                    now: now
                )
            }
            return
        }

        removeProgress(
            seconds: session.resolvedActualFocusDurationSeconds,
            direction: session.direction,
            todo: session.todo,
            now: now
        )
    }

    private func addProgress(seconds: Int, direction: Direction?, todo: Todo?, completionDate: Date) {
        direction?.recordedFocusSeconds += max(0, seconds)
        direction?.updatedAt = completionDate
        adjustTodo(todo, by: max(0, seconds), now: completionDate)
    }

    private func removeProgress(seconds: Int, direction: Direction?, todo: Todo?, now: Date) {
        direction?.recordedFocusSeconds = max(0, (direction?.recordedFocusSeconds ?? 0) - max(0, seconds))
        direction?.updatedAt = now
        adjustTodo(todo, by: -max(0, seconds), now: now)
    }

    private func adjustTodo(_ todo: Todo?, by seconds: Int, now: Date) {
        guard let todo, todo.measurement != .checkbox else { return }
        todo.recordedFocusSeconds = max(0, todo.recordedFocusSeconds + seconds)

        switch todo.measurement {
        case .checkbox:
            break
        case .focusBlocks:
            todo.setProgress(BlockUnit.wholeBlocks(forFocusedSeconds: todo.recordedFocusSeconds), now: now)
        case .minutes:
            todo.setProgress(todo.recordedFocusSeconds / 60, now: now)
        }
    }
}
