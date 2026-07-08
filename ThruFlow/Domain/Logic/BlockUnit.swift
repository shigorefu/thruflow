//
//  BlockUnit.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import Foundation

enum BlockUnit {
    static let secondsPerBlock = 25 * 60

    static func blocks(forFocusedSeconds seconds: Int) -> Double {
        Double(max(0, seconds)) / Double(secondsPerBlock)
    }

    static func wholeBlocks(forFocusedSeconds seconds: Int) -> Int {
        max(0, seconds) / secondsPerBlock
    }

    static func displayText(forFocusedSeconds seconds: Int) -> String {
        let clampedSeconds = max(0, seconds)
        let minutes = clampedSeconds / 60

        switch minutes {
        case 12:
            return "0.5 Block"
        case 25:
            return "1 Block"
        case 50:
            return "2 Blocks"
        default:
            let fullBlocks = clampedSeconds / secondsPerBlock
            let remainingMinutes = (clampedSeconds % secondsPerBlock) / 60

            if fullBlocks == 0 {
                return "\(minutes)分"
            }

            if remainingMinutes == 0 {
                return fullBlocks == 1 ? "1 Block" : "\(fullBlocks) Blocks"
            }

            return "\(fullBlocks) Block\(fullBlocks == 1 ? "" : "s") + \(remainingMinutes)分"
        }
    }

    static func progressText(focusedSeconds: Int, targetBlocks: Int) -> String {
        let targetText = targetBlocks == 1 ? "1 Block" : "\(max(0, targetBlocks)) Blocks"
        return "\(displayText(forFocusedSeconds: focusedSeconds)) / \(targetText)"
    }
}
