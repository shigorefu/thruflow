//
//  FlowSeriesPolicy.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/14.
//

import Foundation

struct FlowSeriesPolicy {
    static let blocksPerLongBreak = 4.0
    static let longBreakDurationSeconds = 20 * 60

    static func continuationWindow(forPlannedBreakSeconds seconds: Int) -> Int {
        max(0, seconds) * 3 / 2
    }

    func shouldUseLongBreak(
        totalSeriesFocusSeconds: Int,
        completedLongBreakCount: Int
    ) -> Bool {
        let nextThreshold = Double(max(0, completedLongBreakCount) + 1) * Self.blocksPerLongBreak
        return BlockUnit.blocks(forFocusedSeconds: totalSeriesFocusSeconds) >= nextThreshold
    }

    func canContinueSeries(after flowBreak: FlowBreak, at date: Date) -> Bool {
        !flowBreak.isDeleted
            && flowBreak.nextSessionID == nil
            && date >= flowBreak.startedAt
            && date <= flowBreak.continuationDeadline
    }
}
