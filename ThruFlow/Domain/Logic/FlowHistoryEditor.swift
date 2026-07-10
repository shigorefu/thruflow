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
        now: Date = .now
    ) {
        let previousSeconds = session.resolvedActualFocusDurationSeconds
        removeProgress(seconds: previousSeconds, direction: session.direction, todo: session.todo, now: now)

        let adjustedSeconds = max(0, focusSeconds)
        session.todo = todo
        session.direction = todo?.direction ?? direction
        session.actualFocusDurationSeconds = adjustedSeconds
        session.endedAt = session.startedAt.addingTimeInterval(TimeInterval(adjustedSeconds))
        session.updatedAt = now
        todo?.setMemo(memo, now: now)

        addProgress(seconds: adjustedSeconds, direction: session.direction, todo: todo, completionDate: session.endedAt ?? now)
    }

    func delete(session: FlowSession, modelContext: ModelContext, now: Date = .now) {
        removeProgress(
            seconds: session.resolvedActualFocusDurationSeconds,
            direction: session.direction,
            todo: session.todo,
            now: now
        )
        modelContext.delete(session)
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
