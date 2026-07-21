import SwiftUI

struct IOSFlowStreamView: View {
    let snapshot: FlowDashboardSnapshot
    let isActive: Bool
    let mode: FlowMode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var animationClock = FlowAnimationClock()

    var body: some View {
        let visualState = FlowVisualState(
            blocks: snapshot.blocks,
            flowCount: snapshot.flowCount,
            isActive: isActive,
            mode: mode
        )

        TimelineView(.animation(minimumInterval: isActive ? 1 / 60 : 1 / 30, paused: animationIsPaused)) { timeline in
            Canvas(opaque: false, colorMode: .extendedLinear, rendersAsynchronously: true) { context, size in
                let phase = animationClock.phase(
                    at: timeline.date,
                    speed: visualState.speed,
                    isPaused: animationIsPaused
                )
                render(in: &context, size: size, state: visualState, phase: phase)
            }
        }
        .background(backgroundTint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "今日のFlow"))
        .accessibilityValue(accessibilityValue(for: visualState))
    }

    private var animationIsPaused: Bool {
        reduceMotion || scenePhase != .active || ProcessInfo.processInfo.arguments.contains("--uitesting")
    }

    private var colors: [Color] {
        let fallback = ["#0A84FF", "#30D5C8", "#BF5AF2", "#64D2FF"]
        let palette = snapshot.palette.isEmpty ? fallback : snapshot.palette
        return (0..<4).map { Color(hex: palette[$0 % palette.count]) }
    }

    private var backgroundTint: Color {
        switch mode {
        case .twelveThree, .adaptive:
            Color.orange.opacity(0.07)
        case .twentyFiveFive:
            Color.blue.opacity(0.07)
        case .fiftyTen:
            Color.purple.opacity(0.07)
        }
    }

    private func render(
        in context: inout GraphicsContext,
        size: CGSize,
        state: FlowVisualState,
        phase: Double
    ) {
        guard size.width > 0, size.height > 0 else { return }

        let centerY = size.height * 0.52
        let spacing = size.height * 0.07
        let baseWidth = max(18, size.height * (0.10 + state.volume * 0.07))
        let resolvedColors = colors

        context.blendMode = .plusLighter
        for layer in 0..<state.layerCount {
            let depth = Double(layer) / Double(max(state.layerCount - 1, 1))
            let color = resolvedColors[layer % resolvedColors.count]
            let path = ribbonPath(
                size: size,
                centerY: centerY + (CGFloat(layer) - CGFloat(state.layerCount - 1) / 2) * spacing,
                phase: phase * (0.62 + depth * 0.58) + Double(layer) * 0.91,
                frequency: state.waveFrequency * (0.88 + depth * 0.25),
                turbulence: state.turbulence,
                depth: depth
            )

            var glowContext = context
            glowContext.addFilter(.blur(radius: CGFloat(5 + depth * 4)))
            glowContext.stroke(
                path,
                with: .color(color.opacity(0.20 + depth * 0.10)),
                style: StrokeStyle(lineWidth: baseWidth * 1.35, lineCap: .round, lineJoin: .round)
            )
            context.stroke(
                path,
                with: .color(color.opacity(0.40 + state.detail * 0.24)),
                style: StrokeStyle(
                    lineWidth: baseWidth * (0.72 + depth * 0.24),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }

    private func ribbonPath(
        size: CGSize,
        centerY: CGFloat,
        phase: Double,
        frequency: Double,
        turbulence: Double,
        depth: Double
    ) -> Path {
        var path = Path()
        let samples = 42

        for index in 0...samples {
            let progress = Double(index) / Double(samples)
            let x = size.width * progress
            let primary = sin(progress * .pi * 2 * frequency + phase)
            let secondary = sin(progress * .pi * 4.1 + phase * 0.63 + depth * 2.4)
            let amplitude = size.height * (0.13 + 0.045 * depth)
            let y = centerY + amplitude * (primary * 0.78 + secondary * 0.22 * turbulence)
            let point = CGPoint(x: x, y: y)

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

    private func accessibilityValue(for state: FlowVisualState) -> String {
        switch state.progress {
        case ..<0.01: String(localized: "まだFlowはありません")
        case ..<0.34: String(localized: "小さな流れ")
        case ..<0.84: String(localized: "育っている流れ")
        default: String(localized: "満ちている流れ")
        }
    }
}

struct IOSFlowTimelineView: View {
    let snapshot: FlowDashboardSnapshot
    let now: Date

    @Environment(\.calendar) private var calendar

    var body: some View {
        let range = FlowTimelineRange(
            date: now,
            segments: snapshot.segments,
            breaks: snapshot.breaks,
            calendar: calendar
        )

        VStack(alignment: .leading, spacing: 7) {
            Text(String(localized: "今日のタイムライン"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))

                    ForEach(snapshot.seriesSpans) { span in
                        timelineCapsule(
                            start: span.startedAt,
                            end: span.endedAt,
                            range: range,
                            width: proxy.size.width,
                            color: Color.secondary.opacity(0.42),
                            height: 14
                        )
                    }

                    ForEach(snapshot.segments) { segment in
                        timelineCapsule(
                            start: segment.startedAt,
                            end: segment.endedAt,
                            range: range,
                            width: proxy.size.width,
                            color: Color(hex: segment.colorHex),
                            height: 14
                        )
                    }
                }
            }
            .frame(height: 14)

            HStack {
                ForEach(range.labelDates(calendar: calendar), id: \.self) { date in
                    Text(date, format: .dateTime.hour(.twoDigits(amPM: .omitted)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if date != range.labelDates(calendar: calendar).last {
                        Spacer()
                    }
                }
            }
        }
    }

    private func timelineCapsule(
        start: Date,
        end: Date,
        range: FlowTimelineRange,
        width: CGFloat,
        color: Color,
        height: CGFloat
    ) -> some View {
        let startX = width * range.fraction(for: start)
        let endX = width * range.fraction(for: end)
        return Capsule()
            .fill(color)
            .frame(width: max(endX - startX, 4), height: height)
            .offset(x: startX)
    }
}
