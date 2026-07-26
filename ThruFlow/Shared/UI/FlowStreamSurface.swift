import SwiftUI

struct FlowStreamSurface: View {
    let blocks: Double
    let flowCount: Int
    let palette: [String]
    let paletteWeights: [Double]
    let dailySeed: UInt64
    let isActive: Bool
    let mode: FlowMode
    let isRenderingEnabled: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var animationClock = FlowAnimationClock()
    @State private var impulseStartedAt: Date?

    init(
        blocks: Double,
        flowCount: Int,
        palette: [String],
        paletteWeights: [Double] = [],
        dailySeed: UInt64 = 0,
        isActive: Bool,
        mode: FlowMode,
        isRenderingEnabled: Bool
    ) {
        self.blocks = blocks
        self.flowCount = flowCount
        self.palette = palette
        self.paletteWeights = paletteWeights
        self.dailySeed = dailySeed
        self.isActive = isActive
        self.mode = mode
        self.isRenderingEnabled = isRenderingEnabled
    }

    var body: some View {
        let state = FlowVisualState(
            blocks: blocks,
            flowCount: flowCount,
            isActive: isActive,
            mode: mode
        )
        let colors = resolvedColors
        let weights = resolvedWeights
        let appearance = DailyFlowAppearance(seed: dailySeed)
        let background = resolvedBackground(identityReveal: state.identityReveal)

        TimelineView(.animation(
            minimumInterval: FlowRenderCadence.frameInterval(isActive: isActive),
            paused: animationIsPaused
        )) { timeline in
            GeometryReader { proxy in
                Rectangle()
                    .fill(background)
                    .colorEffect(
                        ShaderLibrary.flowStream(
                            .float2(proxy.size),
                            .float(Float(animationClock.phase(
                                at: timeline.date,
                                speed: state.speed,
                                isPaused: animationIsPaused
                            ))),
                            .float(Float(state.progress)),
                            .float(Float(state.identityReveal)),
                            .float(Float(state.volume)),
                            .float(Float(state.detail)),
                            .float(Float(state.depth)),
                            .float(Float(state.glow)),
                            .float(Float(state.waveFrequency)),
                            .float(Float(state.turbulence)),
                            .float(Float(impulseProgress(at: timeline.date))),
                            .float(Float(appearance.topology)),
                            .float(Float(appearance.bend)),
                            .float(Float(appearance.spacing)),
                            .float(Float(appearance.paletteRotation)),
                            .color(colors[0]),
                            .color(colors[1]),
                            .color(colors[2]),
                            .color(colors[3]),
                            .float(Float(weights[0])),
                            .float(Float(weights[1])),
                            .float(Float(weights[2])),
                            .float(Float(weights[3])),
                            .color(background),
                            .float(colorScheme == .dark ? 1 : 0)
                        )
                    )
                    .compositingGroup()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "今日のFlow"))
        .accessibilityValue(accessibilityValue(state))
        .onChange(of: completedHalfBlocks) { oldValue, newValue in
            guard newValue > oldValue else { return }
            impulseStartedAt = .now
        }
    }

    private var resolvedColors: [Color] {
        let fallback = ["#0A84FF", "#30D5C8", "#BF5AF2", "#64D2FF"]
        let values = palette.isEmpty ? fallback : palette
        return (0..<4).map { Color(hex: values[$0 % values.count]) }
    }

    private var resolvedWeights: [Double] {
        guard !palette.isEmpty else {
            return [0.25, 0.25, 0.25, 0.25]
        }

        let provided = (0..<4).map { index -> Double in
            guard index < paletteWeights.count else { return 0 }
            return max(0, paletteWeights[index])
        }
        let repeated = (0..<4).map { index -> Double in
            if provided.reduce(0, +) > 0 {
                return provided[index]
            }
            return index < palette.count ? 1 : 0
        }
        let total = max(repeated.reduce(0, +), 1)
        return repeated.map { $0 / total }
    }

    private func resolvedBackground(identityReveal: Double) -> Color {
        let reveal = min(max(identityReveal, 0), 1)

        switch colorScheme {
        case .dark:
            return Color(
                red: 0.025 + (0.022 - 0.025) * reveal,
                green: 0.032 + (0.029 - 0.032) * reveal,
                blue: 0.052 + (0.048 - 0.052) * reveal
            )
        default:
            return Color(
                red: 0.91 + (0.925 - 0.91) * reveal,
                green: 0.93 + (0.94 - 0.93) * reveal,
                blue: 0.96 + (0.965 - 0.96) * reveal
            )
        }
    }

    private var animationIsPaused: Bool {
        reduceMotion || isUITesting || scenePhase != .active || !isRenderingEnabled
    }

    private var completedHalfBlocks: Int {
        Int(floor(max(blocks, 0) * 2))
    }

    private func impulseProgress(at date: Date) -> Double {
        guard let impulseStartedAt else { return -1 }
        let progress = date.timeIntervalSince(impulseStartedAt) / 1.8
        return (0...1).contains(progress) ? progress : -1
    }

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting")
    }

    private func accessibilityValue(_ state: FlowVisualState) -> String {
        switch state.progress {
        case ..<0.01: String(localized: "まだFlowはありません")
        case ..<0.34: String(localized: "小さな流れ")
        case ..<0.84: String(localized: "育っている流れ")
        default: String(localized: "満ちている流れ")
        }
    }
}
