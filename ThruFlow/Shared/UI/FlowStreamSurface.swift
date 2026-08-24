import SwiftUI

struct FlowStreamSurface: View, Equatable {
    let blocks: Double
    let flowCount: Int
    let palette: [String]
    let paletteWeights: [Double]
    let dailySeed: UInt64
    let isActive: Bool
    let mode: FlowMode
    let breakStyle: FlowStreamBreakStyle
    let breakInteraction: FlowBreakInteraction?
    let isRenderingEnabled: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var animationClock = FlowAnimationClock()
    @State private var impulseStartedAt: Date?
    @State private var reactionState = FlowStreamReactionState()

    init(
        blocks: Double,
        flowCount: Int,
        palette: [String],
        paletteWeights: [Double] = [],
        dailySeed: UInt64 = 0,
        isActive: Bool,
        mode: FlowMode,
        breakStyle: FlowStreamBreakStyle = .none,
        breakInteraction: FlowBreakInteraction? = nil,
        isRenderingEnabled: Bool
    ) {
        self.blocks = blocks
        self.flowCount = flowCount
        self.palette = palette
        self.paletteWeights = paletteWeights
        self.dailySeed = dailySeed
        self.isActive = isActive
        self.mode = mode
        self.breakStyle = breakStyle
        self.breakInteraction = breakInteraction
        self.isRenderingEnabled = isRenderingEnabled
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.blocks == rhs.blocks &&
            lhs.flowCount == rhs.flowCount &&
            lhs.palette == rhs.palette &&
            lhs.paletteWeights == rhs.paletteWeights &&
            lhs.dailySeed == rhs.dailySeed &&
            lhs.isActive == rhs.isActive &&
            lhs.mode == rhs.mode &&
            lhs.breakStyle == rhs.breakStyle &&
            lhs.breakInteraction == rhs.breakInteraction &&
            lhs.isRenderingEnabled == rhs.isRenderingEnabled
    }

    var body: some View {
        let state = FlowVisualState(
            blocks: blocks,
            flowCount: flowCount,
            isActive: isActive,
            mode: mode
        )
        let colors = resolvedRibbonColors
        let appearance = DailyFlowAppearance(seed: dailySeed)
        let background = resolvedBackground(identityReveal: state.identityReveal)

#if os(watchOS)
        watchSurface(
            state: state,
            colors: colors,
            appearance: appearance,
            background: background
        )
#else
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
                                at: ProcessInfo.processInfo.systemUptime,
                                visualState: state,
                                isPaused: animationIsPaused
                            ))),
                            .float(isActive ? 1 : 0),
                            .float(Float(state.progress)),
                            .float(Float(state.identityReveal)),
                            .float(Float(state.volume)),
                            .float(Float(state.detail)),
                            .float(Float(state.depth)),
                            .float(Float(state.glow)),
                            .float(Float(state.waveFrequency)),
                            .float(Float(state.turbulence)),
                            .float(Float(impulseProgress(at: timeline.date))),
                            .float(Float(restRequestProgress(at: timeline.date))),
                            .float(Float(regularBreakProgress(at: timeline.date))),
                            .float(Float(longBreakProgress(at: timeline.date))),
                            .float(breakStyle.rawValue),
                            .float(Float(appearance.topology)),
                            .float(Float(appearance.bend)),
                            .float(Float(appearance.spacing)),
                            .float(Float(appearance.paletteRotation)),
                            .color(colors[0]),
                            .color(colors[1]),
                            .color(colors[2]),
                            .color(colors[3]),
                            .color(colors[4]),
                            .color(colors[5]),
                            .color(colors[6]),
                            .color(background),
                            .float(colorScheme == .dark ? 1 : 0)
                        )
                    )
                    .animation(.easeInOut(duration: 0.8), value: mode)
                    .compositingGroup()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "今日のFlow"))
        .accessibilityValue(accessibilityValue(state, breakStyle: breakStyle))
        .onChange(of: completedHalfBlocks) { oldValue, newValue in
            guard newValue > oldValue else { return }
            impulseStartedAt = .now
        }
        .onAppear(perform: synchronizeBreakInteraction)
        .onChange(of: breakInteraction?.sequence) { _, _ in
            synchronizeBreakInteraction()
        }
        .onChange(of: breakStyle) { _, newValue in
            guard newValue == .none else { return }
            reactionState.clearConfirmedBreak()
        }
#endif
    }

#if os(watchOS)
    private func watchSurface(
        state: FlowVisualState,
        colors: [Color],
        appearance: DailyFlowAppearance,
        background: Color
    ) -> some View {
        TimelineView(.animation(
            minimumInterval: FlowRenderCadence.frameInterval(isActive: isActive),
            paused: animationIsPaused
        )) { timeline in
            Canvas { context, size in
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(background)
                )

                let phase = animationClock.phase(
                    at: ProcessInfo.processInfo.systemUptime,
                    visualState: state,
                    isPaused: animationIsPaused
                )
                drawWatchRibbons(
                    in: &context,
                    size: size,
                    phase: phase,
                    state: state,
                    colors: colors,
                    appearance: appearance,
                    restRequestProgress: restRequestProgress(at: timeline.date),
                    regularBreakProgress: regularBreakProgress(at: timeline.date),
                    longBreakProgress: longBreakProgress(at: timeline.date)
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "今日のFlow"))
        .accessibilityValue(accessibilityValue(state, breakStyle: breakStyle))
        .onChange(of: completedHalfBlocks) { oldValue, newValue in
            guard newValue > oldValue else { return }
            impulseStartedAt = .now
        }
        .onAppear(perform: synchronizeBreakInteraction)
        .onChange(of: breakInteraction?.sequence) { _, _ in
            synchronizeBreakInteraction()
        }
        .onChange(of: breakStyle) { _, newValue in
            guard newValue == .none else { return }
            reactionState.clearConfirmedBreak()
        }
    }

    private func drawWatchRibbons(
        in context: inout GraphicsContext,
        size: CGSize,
        phase: Double,
        state: FlowVisualState,
        colors: [Color],
        appearance: DailyFlowAppearance,
        restRequestProgress: Double,
        regularBreakProgress: Double,
        longBreakProgress: Double
    ) {
        let ribbonCount = FlowVisualState.ribbonCount
        let impulse = max(0, impulseProgress(at: .now))
        let requestEnvelope = FlowStreamReactionTiming.envelope(for: restRequestProgress)
        let regularBreakEnvelope = FlowStreamReactionTiming.envelope(for: regularBreakProgress)
        let longBreakEnvelope = FlowStreamReactionTiming.envelope(for: longBreakProgress)
        let longBreakAmount = breakStyle == .long ? 1.0 : 0.0
        let idleAmount = !isActive && breakStyle == .none ? 1.0 : 0.0
        let baseWidth = max(5, size.height * (0.070 + state.volume * 0.044))
        let amplitude = size.height * (0.06 + state.detail * 0.035)

        for ribbon in 0..<ribbonCount {
            let progress = Double(ribbon) / Double(max(ribbonCount - 1, 1))
            let color = colors[ribbon]
            let path = watchRibbonPath(
                ribbon: ribbon,
                ribbonCount: ribbonCount,
                size: size,
                phase: phase,
                amplitude: amplitude,
                state: state,
                appearance: appearance,
                requestEnvelope: requestEnvelope,
                regularBreakEnvelope: regularBreakEnvelope,
                longBreakEnvelope: longBreakEnvelope,
                longBreakAmount: longBreakAmount,
                idleAmount: idleAmount
            )
            let width = baseWidth * (0.86 + progress * 0.34)
                * (1 + longBreakEnvelope * 0.24)
            let opacity = 0.42
                + state.glow * 0.38
                + impulse * 0.12
                + requestEnvelope * 0.05
                + regularBreakEnvelope * 0.06
                + longBreakEnvelope * 0.12

            context.drawLayer { glowLayer in
                glowLayer.addFilter(.blur(radius: max(1.5, width * 0.52)))
                glowLayer.stroke(
                    path,
                    with: .color(color.opacity(opacity * 0.52)),
                    style: StrokeStyle(lineWidth: width * 1.8, lineCap: .round)
                )
            }
            context.stroke(
                path,
                with: .color(color.opacity(min(opacity, 0.92))),
                style: StrokeStyle(lineWidth: width, lineCap: .round)
            )
        }
    }

    private func watchRibbonPath(
        ribbon: Int,
        ribbonCount: Int,
        size: CGSize,
        phase: Double,
        amplitude: Double,
        state: FlowVisualState,
        appearance: DailyFlowAppearance,
        requestEnvelope: Double,
        regularBreakEnvelope: Double,
        longBreakEnvelope: Double,
        longBreakAmount: Double,
        idleAmount: Double
    ) -> Path {
        let ribbonProgress = Double(ribbon) / Double(max(ribbonCount - 1, 1))
        let laneDirection = ribbonProgress * 2 - 1
        let spread = requestEnvelope * 0.032
            + regularBreakEnvelope * 0.044
            + longBreakEnvelope * 0.092
            + longBreakAmount * 0.018
        let baseY = size.height * (0.14 + ribbonProgress * 0.72 + laneDirection * spread)
        let phaseOffset = Double(ribbon) * (0.61 + appearance.spacing * 0.42)
        let frequency = state.waveFrequency * (0.82 + appearance.topology * 0.28)
        let bend = 0.72 + appearance.bend * 0.58
        let stepCount = 28

        var path = Path()
        for step in 0...stepCount {
            let xProgress = Double(step) / Double(stepCount)
            let primary = sin(
                xProgress * .pi * 2 * frequency
                    + phase * bend
                    + phaseOffset
            )
            let detail = sin(
                xProgress * .pi * 4.6
                    - phase * (0.38 + state.turbulence * 0.22)
                    + phaseOffset * 1.7
            )
            let longBreakBreath = longBreakAmount > 0
                ? sin(
                    xProgress * .pi * 2.2
                        - phase * 2.4
                        + phaseOffset
                ) * 0.16
                : 0
            let idleCurrent = idleAmount > 0
                ? sin(
                    xProgress * .pi * 5.2
                        - phase * 3.4
                        + phaseOffset * 1.2
                ) * 0.09
                : 0
            let y = baseY + amplitude * (
                primary * (0.72 + ribbonProgress * 0.18)
                    + detail * state.turbulence * 0.18
                    + longBreakBreath
                    + idleCurrent
            )
            let point = CGPoint(x: size.width * xProgress, y: y)

            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

#endif

    private var resolvedRibbonColors: [Color] {
        FlowStreamPaletteLayout.ribbonColorHexes(
            palette: palette,
            weights: paletteWeights,
            ribbonCount: FlowVisualState.ribbonCount
        )
        .map { Color(hex: $0) }
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

    private func restRequestProgress(at date: Date) -> Double {
        transientProgress(for: .requested, at: date)
    }

    private func regularBreakProgress(at date: Date) -> Double {
        transientProgress(for: .started(isLong: false), at: date)
    }

    private func longBreakProgress(at date: Date) -> Double {
        transientProgress(for: .started(isLong: true), at: date)
    }

    private func transientProgress(
        for kind: FlowBreakInteraction.Kind,
        at date: Date
    ) -> Double {
        guard !reduceMotion else { return -1 }
        return reactionState.progress(for: kind, at: date)
    }

    private func synchronizeBreakInteraction() {
        reactionState.consume(breakInteraction, breakStyle: breakStyle)
    }

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting")
    }

    private func accessibilityValue(
        _ state: FlowVisualState,
        breakStyle: FlowStreamBreakStyle
    ) -> String {
        switch breakStyle {
        case .regular:
            return String(localized: "休憩")
        case .long:
            return String(localized: "長休憩")
        case .none:
            break
        }

        return switch state.progress {
        case ..<0.01: String(localized: "まだFlowはありません")
        case ..<0.34: String(localized: "小さな流れ")
        case ..<0.84: String(localized: "育っている流れ")
        default: String(localized: "満ちている流れ")
        }
    }
}
