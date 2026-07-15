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
    let detail: Double
    let layerCount: Int
    let waveFrequency: Double
    let turbulence: Double

    init(blocks: Double, flowCount: Int, isActive: Bool, mode: FlowMode) {
        let linearProgress = min(max(blocks / Self.maximumGrowthBlocks, 0), 1)
        let easedProgress = linearProgress * linearProgress * (3 - (2 * linearProgress))
        let modeCharacter = Self.modeCharacter(for: mode)

        progress = linearProgress
        speed = isActive
            ? 1.10 + easedProgress * 1.70
            : 0.06 + easedProgress * 0.22
        let occupancyProgress = min(max(blocks / 4, 0), 1)
        let easedOccupancy = occupancyProgress * occupancyProgress * (3 - (2 * occupancyProgress))
        volume = 0.38 + easedOccupancy * 0.30
        detail = 0.30 + easedProgress * 0.70
        layerCount = min(8, max(6, 6 + min(flowCount / 3, 2)))
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
