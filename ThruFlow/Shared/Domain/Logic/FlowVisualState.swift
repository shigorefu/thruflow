//
//  FlowVisualState.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/26.
//

import Foundation

struct FlowVisualState: Equatable {
    static let maximumGrowthBlocks = 6.0
    static let identityRevealBlocks = 1.0
    static let baselineRibbonCount = 6
    static let ribbonCount = 7

    let progress: Double
    let identityReveal: Double
    let speed: Double
    let volume: Double
    let detail: Double
    let depth: Double
    let glow: Double
    let waveFrequency: Double
    let turbulence: Double

    init(blocks: Double, flowCount _: Int, isActive: Bool, mode: FlowMode) {
        let linearProgress = min(max(blocks / Self.maximumGrowthBlocks, 0), 1)
        let easedProgress = Self.smoothstep(linearProgress)
        let modeCharacter = Self.modeCharacter(for: mode)

        progress = linearProgress
        let identityProgress = min(max(blocks / Self.identityRevealBlocks, 0), 1)
        identityReveal = Self.smoothstep(identityProgress)
        speed = isActive
            ? 1.10 + easedProgress * 1.70
            : 0.06 + easedProgress * 0.22

        let occupancyProgress = min(max(blocks / 4, 0), 1)
        volume = 0.38 + Self.smoothstep(occupancyProgress) * 0.30
        detail = 0.28 + easedProgress * 0.72
        depth = 0.24 + easedProgress * 0.76
        glow = 0.22 + easedProgress * 0.58
        waveFrequency = modeCharacter.frequency
        turbulence = modeCharacter.turbulence
    }

    private static func smoothstep(_ value: Double) -> Double {
        value * value * (3 - (2 * value))
    }

    private static func modeCharacter(for mode: FlowMode) -> (frequency: Double, turbulence: Double) {
        switch mode {
        case .sprint, .adaptive:
            (1.22, 0.86)
        case .twentyFiveFive:
            (0.96, 0.62)
        case .fiftyTen:
            (0.72, 0.40)
        }
    }
}

struct DailyFlowAppearance: Equatable {
    let seed: UInt64
    let topology: Double
    let bend: Double
    let spacing: Double
    let paletteRotation: Double

    init(
        date: Date,
        identityID: UUID?,
        calendar: Calendar = .current
    ) {
        let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        let identity = identityID?.uuidString.lowercased() ?? "thruflow"
        let source = [
            String(components.era ?? 0),
            String(components.year ?? 0),
            String(components.month ?? 0),
            String(components.day ?? 0),
            identity,
        ].joined(separator: "|")

        seed = Self.stableHash(source)
        topology = Self.unit(seed: seed, salt: 0)
        bend = Self.unit(seed: seed, salt: 1)
        spacing = Self.unit(seed: seed, salt: 2)
        paletteRotation = Self.unit(seed: seed, salt: 3)
    }

    init(seed: UInt64) {
        self.seed = seed
        topology = Self.unit(seed: seed, salt: 0)
        bend = Self.unit(seed: seed, salt: 1)
        spacing = Self.unit(seed: seed, salt: 2)
        paletteRotation = Self.unit(seed: seed, salt: 3)
    }

    private static func stableHash(_ value: String) -> UInt64 {
        value.utf8.reduce(14_695_981_039_346_656_037) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }

    private static func unit(seed: UInt64, salt: UInt64) -> Double {
        var value = seed &+ (salt &+ 1) &* 0x9E37_79B9_7F4A_7C15
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return Double(value >> 11) / 9_007_199_254_740_992
    }
}

enum DailyFlowIdentity {
    static func resolve(from directions: [Direction]) -> UUID? {
        directions.min {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }?.id
    }
}

enum FlowRenderCadence {
    static let activeFramesPerSecond = 60.0
    static let idleFramesPerSecond = 30.0

    static func frameInterval(isActive: Bool) -> TimeInterval {
        1 / (isActive ? activeFramesPerSecond : idleFramesPerSecond)
    }
}

final class FlowAnimationClock {
    private(set) var phase = 0.0
    private var lastDate: Date?
    private var wasPaused = true

    func phase(at date: Date, speed: Double, isPaused: Bool) -> Double {
        guard !isPaused else {
            lastDate = date
            wasPaused = true
            return phase
        }

        guard !wasPaused, let lastDate else {
            self.lastDate = date
            wasPaused = false
            return phase
        }

        let elapsed = max(0, date.timeIntervalSince(lastDate))
        phase = (phase + elapsed * speed).truncatingRemainder(dividingBy: 10_000)
        self.lastDate = date
        return phase
    }
}
