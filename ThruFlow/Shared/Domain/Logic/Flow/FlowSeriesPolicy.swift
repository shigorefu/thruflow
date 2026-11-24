//
//  FlowSeriesPolicy.swift
//  ThruFlow
//
//

import Foundation

struct FlowSeriesPolicy {
    static let blocksPerLongBreak = 4.0
    static let longBreakDurationSeconds = 20 * 60

    static func continuationWindow(forPlannedBreakSeconds seconds: Int) -> Int {
        max(0, seconds) * 3 / 2
    }

    struct FocusPeriod {
        var focusedSeconds: Int
        var restedSeconds: Int = 0
    }

    struct BreakRecommendation: Equatable {
        var durationSeconds: Int
        var isLong: Bool
    }

    /// Replays actual rest, rather than treating a created/skipped break as completed.
    /// Periods are chronological; the last period is the focus ending now (no rest yet).
    func recommendation(after periods: [FocusPeriod]) -> BreakRecommendation {
        var cycleFocus = 0
        var uninterruptedFocus = 0
        var shortRestCredit = 0
        var longRestCredit = 0

        for period in periods {
            cycleFocus += max(0, period.focusedSeconds)
            uninterruptedFocus += max(0, period.focusedSeconds)
            let rest = max(0, period.restedSeconds)
            if let target = Self.longBreakTarget(forFocusedSeconds: cycleFocus) {
                // Short rests taken before reaching four Blocks do not pay off long rest.
                longRestCredit += rest
                if longRestCredit >= target {
                    cycleFocus = 0
                    uninterruptedFocus = 0
                    shortRestCredit = 0
                    longRestCredit = 0
                }
            } else {
                shortRestCredit += rest
                if shortRestCredit >= Self.regularBreakDuration(forFocusedSeconds: uninterruptedFocus) {
                    uninterruptedFocus = 0
                    shortRestCredit = 0
                }
            }
        }

        if let target = Self.longBreakTarget(forFocusedSeconds: cycleFocus) {
            return BreakRecommendation(durationSeconds: target - longRestCredit, isLong: true)
        }
        return BreakRecommendation(
            durationSeconds: max(1, Self.regularBreakDuration(forFocusedSeconds: uninterruptedFocus) - shortRestCredit),
            isLong: false
        )
    }

    static func regularBreakDuration(forFocusedSeconds seconds: Int) -> Int {
        switch seconds {
        case (74 * 60)...: 15 * 60
        case (49 * 60)...: 10 * 60
        case (24 * 60)...: 5 * 60
        default: 3 * 60
        }
    }

    private static func longBreakTarget(forFocusedSeconds seconds: Int) -> Int? {
        let blocks = BlockUnit.wholeBlocks(forFocusedSeconds: seconds)
        guard blocks >= Int(blocksPerLongBreak) else { return nil }
        return min(30 * 60, longBreakDurationSeconds + (blocks - Int(blocksPerLongBreak)) * 5 * 60)
    }

    func canContinueSeries(after flowBreak: FlowBreak, at date: Date) -> Bool {
        !flowBreak.isDeleted
            && flowBreak.nextSessionID == nil
            && date >= flowBreak.startedAt
            && date <= flowBreak.continuationDeadline
    }
}
