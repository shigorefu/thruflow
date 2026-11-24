//
//  FlowProgressCalculator.swift
//  ThruFlow
//
//

import Foundation

struct FlowProgressCalculator {
    func applyFocusDuration(seconds: Int, area: Area?, todo: Todo?, now: Date = .now) {
        let focusedSeconds = max(0, seconds)

        if let area {
            area.addFocusDuration(seconds: focusedSeconds, now: now)
        }

        guard let todo else { return }

        switch todo.measurement {
        case .checkbox:
            break
        case .focusBlocks:
            todo.addFocusDuration(seconds: focusedSeconds, now: now)
            let completedBlocks = BlockUnit.wholeBlocks(forFocusedSeconds: todo.recordedFocusSeconds)
            todo.setProgress(completedBlocks, now: now)
        case .minutes:
            todo.addFocusDuration(seconds: focusedSeconds, now: now)
            todo.setProgress(todo.recordedFocusSeconds / 60, now: now)
        }
    }

    func applySession(_ session: FlowSession, fallbackSeconds: Int, now: Date = .now) {
        if !session.resolvedSegments.isEmpty {
            for segment in session.resolvedSegments where segment.resolvedFocusSeconds > 0 {
                applyFocusDuration(
                    seconds: segment.resolvedFocusSeconds,
                    area: segment.area,
                    todo: segment.todo,
                    now: now
                )
            }
            return
        }

        applyFocusDuration(
            seconds: fallbackSeconds,
            area: session.area,
            todo: session.todo,
            now: now
        )
    }
}
