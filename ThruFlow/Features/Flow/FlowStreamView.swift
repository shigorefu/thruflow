//
//  FlowStreamView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/12.
//

import SwiftUI

struct FlowStreamView: View {
    let intensity: Double
    let flowCount: Int
    let palette: [String]
    let isActive: Bool
    let mode: FlowMode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let colors = resolvedColors

        TimelineView(.periodic(from: .now, by: refreshInterval)) { timeline in
            Canvas(rendersAsynchronously: true) { context, size in
                draw(in: &context, size: size, date: timeline.date, colors: colors)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日のFlow")
        .accessibilityValue(accessibilityValue)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, date: Date, colors: [Color]) {
        guard size.width > 0, size.height > 0 else { return }

        let normalizedIntensity = min(max(intensity, 0), 1)
        let layerCount = min(7, max(5, 5 + min(flowCount, 1) + Int(normalizedIntensity.rounded(.down))))
        let phase = reduceMotion ? 0 : date.timeIntervalSinceReferenceDate * animationSpeed
        let centerY = size.height * 0.50
        let amplitude = size.height * (0.12 + normalizedIntensity * 0.12)
        let baseWidth = max(5, size.height * (0.022 + normalizedIntensity * 0.018))

        for layer in 0..<layerCount {
            let layerProgress = layerCount == 1 ? 0 : Double(layer) / Double(layerCount - 1)
            let color = colors[layer % colors.count]
            let verticalOffset = (layerProgress - 0.5) * size.height * (0.42 + normalizedIntensity * 0.12)
            var path = Path()

            for step in 0...48 {
                let progress = Double(step) / 48
                let x = size.width * progress
                let primaryWave = sin(progress * .pi * 2.2 + phase + Double(layer) * 0.58)
                let secondaryWave = sin(progress * .pi * 5.0 - phase * 0.55 + Double(layer)) * 0.32
                let envelope = 0.46 + sin(progress * .pi) * 0.54
                let y = centerY + verticalOffset + (primaryWave + secondaryWave) * amplitude * envelope

                if step == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            let opacity = 0.46 + layerProgress * 0.40
            let gradient = Gradient(colors: [color.opacity(opacity * 0.48), color.opacity(opacity), color.opacity(opacity * 0.62)])
            context.stroke(
                path,
                with: .linearGradient(
                    gradient,
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                ),
                style: StrokeStyle(lineWidth: baseWidth + CGFloat(layer) * 1.4, lineCap: .round, lineJoin: .round)
            )
        }
    }

    @MainActor
    private var resolvedColors: [Color] {
        let values = palette.isEmpty ? ["#0A84FF", "#30D5C8"] : Array(palette.prefix(6))
        return values.map(Color.init(hex:))
    }

    private var animationSpeed: Double {
        guard isActive else { return 0.10 }

        return switch mode {
        case .twelveThree, .adaptive:
            1.15
        case .twentyFiveFive:
            0.68
        case .fiftyTen:
            0.34
        }
    }

    private var refreshInterval: TimeInterval {
        if reduceMotion || isUITesting { return 60 }
        return isActive ? (1 / 15) : 0.5
    }

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting")
    }

    private var accessibilityValue: String {
        switch intensity {
        case ..<0.01:
            "まだFlowはありません"
        case ..<0.35:
            "小さな流れ"
        case ..<0.75:
            "育っている流れ"
        default:
            "豊かな流れ"
        }
    }
}
