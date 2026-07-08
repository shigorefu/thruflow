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

        guard let todo else { return }

        todo.addFocusDuration(seconds: focusedSeconds, now: now)

        switch todo.measurement {
        case .checkbox:
            break
        case .focusBlocks:
            let completedBlocks = BlockUnit.wholeBlocks(forFocusedSeconds: todo.recordedFocusSeconds)
            todo.setProgress(completedBlocks, now: now)
        case .minutes:
            todo.setProgress(todo.recordedFocusSeconds / 60, now: now)
        }
    }
}
