//
//  BlockUnit.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import Foundation

enum BlockUnit {
    static let secondsPerBlock = 25 * 60
    static let secondsPerHalfBlock = 12 * 60

    static func blocks(forFocusedSeconds seconds: Int) -> Double {
        Double(halfBlocks(forFocusedSeconds: seconds)) * 0.5
    }

    static func wholeBlocks(forFocusedSeconds seconds: Int) -> Int {
        halfBlocks(forFocusedSeconds: seconds) / 2
    }

    static func halfBlocks(forFocusedSeconds seconds: Int) -> Int {
        max(0, seconds) / secondsPerHalfBlock
    }

    static func displayText(forFocusedSeconds seconds: Int) -> String {
        let halfBlocks = halfBlocks(forFocusedSeconds: seconds)

        guard halfBlocks > 0 else {
            return "0 Block"
        }

        if halfBlocks % 2 == 0 {
            let wholeBlocks = halfBlocks / 2
            return wholeBlocks == 1 ? "1 Block" : "\(wholeBlocks) Blocks"
        }

        let value = Double(halfBlocks) * 0.5
        return value == 0.5 ? "0.5 Block" : "\(value) Blocks"
    }

    static func progressText(focusedSeconds: Int, targetBlocks: Int) -> String {
        let targetText = targetBlocks == 1 ? "1 Block" : "\(max(0, targetBlocks)) Blocks"
        return "\(displayText(forFocusedSeconds: focusedSeconds)) / \(targetText)"
    }
}
