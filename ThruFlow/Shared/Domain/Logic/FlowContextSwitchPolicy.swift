//
//  FlowContextSwitchPolicy.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/28.
//

import Foundation

struct FlowContextSwitchPolicy {
    static let transferThresholdSeconds = 60

    func shouldTransferCurrentSegment(
        totalFocusSeconds: Int,
        segmentStartFocusSeconds: Int
    ) -> Bool {
        let segmentFocusSeconds = max(0, totalFocusSeconds - segmentStartFocusSeconds)
        return segmentFocusSeconds < Self.transferThresholdSeconds
    }
}
