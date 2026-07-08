//
//  FlowProgressCalculator.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import Foundation

struct FlowProgressCalculator {
    func applyFocusDuration(seconds: Int, direction: Direction?, todo: Todo?, now: Date = .now) {
        let focusedSeconds = max(0, seconds)

        if let direction {
            direction.addFocusDuration(seconds: focusedSeconds, now: now)
        }

        guard let todo,
              let goalUnit = direction?.goalUnit else { return }

        switch goalUnit {
        case .occurrences:
            break
        case .focusBlocks:
            todo.addFocusDuration(seconds: focusedSeconds, now: now)
            let completedBlocks = BlockUnit.wholeBlocks(forFocusedSeconds: todo.recordedFocusSeconds)
            todo.setProgress(completedBlocks, now: now)
        case .minutes:
            todo.addFocusDuration(seconds: focusedSeconds, now: now)
            todo.setProgress(todo.recordedFocusSeconds / 60, now: now)
        case .hours:
            todo.addFocusDuration(seconds: focusedSeconds, now: now)
            todo.setProgress(todo.recordedFocusSeconds / 60, now: now)
        }
    }
}
