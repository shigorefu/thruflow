//
//  FlowVisualState.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/13.
//

import Foundation

struct FlowVisualState: Equatable {
    static let maximumGrowthBlocks = 6.0

    let progress: Double
    let speed: Double
    let volume: Double
    let layerCount: Int
    let waveFrequency: Double
    let turbulence: Double

    init(blocks: Double, flowCount: Int, isActive: Bool, mode: FlowMode) {
        let linearProgress = min(max(blocks / Self.maximumGrowthBlocks, 0), 1)
        let easedProgress = linearProgress * linearProgress * (3 - (2 * linearProgress))
        let modeCharacter = Self.modeCharacter(for: mode)

        progress = linearProgress
        let dailySpeed = 0.075 + easedProgress * 0.68
        speed = dailySpeed + (isActive ? 0.58 : 0)
        volume = 0.42 + easedProgress * 0.58
        layerCount = min(10, max(7, 7 + min(flowCount / 2, 3)))
        waveFrequency = modeCharacter.frequency
        turbulence = modeCharacter.turbulence
    }

    private static func modeCharacter(for mode: FlowMode) -> (frequency: Double, turbulence: Double) {
        switch mode {
        case .twelveThree, .adaptive:
            (1.22, 0.86)
        case .twentyFiveFive:
            (0.96, 0.62)
        case .fiftyTen:
            (0.72, 0.40)
        }
    }
}

final class FlowAnimationClock {
    private(set) var phase = 0.0
    private var lastDate: Date?
    private var lastSpeed = 0.0
    private var wasPaused = true

    func phase(at date: Date, speed: Double, isPaused: Bool) -> Double {
        guard !isPaused else {
            lastDate = date
            lastSpeed = speed
            wasPaused = true
            return phase
        }

        guard !wasPaused, let lastDate else {
            self.lastDate = date
            lastSpeed = speed
            wasPaused = false
            return phase
        }

        let elapsed = max(0, date.timeIntervalSince(lastDate))
        phase = (phase + elapsed * lastSpeed).truncatingRemainder(dividingBy: 10_000)
        self.lastDate = date
        lastSpeed = speed
        return phase
    }
}
