//
//  FlowStreamView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/12.
//

import SwiftUI

struct FlowStreamView: View {
    let blocks: Double
    let flowCount: Int
    let palette: [String]
    let isActive: Bool
    let mode: FlowMode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let state = FlowVisualState(blocks: blocks, flowCount: flowCount, isActive: isActive, mode: mode)
        let colors = resolvedColors

        TimelineView(.animation(minimumInterval: frameInterval, paused: animationIsPaused)) { timeline in
            GeometryReader { proxy in
                Rectangle()
                    .fill(.white)
                    .colorEffect(
                        ShaderLibrary.flowStream(
                            .float2(proxy.size),
                            .float(shaderTime(timeline.date, speed: state.speed)),
                            .float(Float(state.progress)),
                            .float(Float(state.volume)),
                            .float(Float(state.layerCount)),
                            .float(Float(state.waveFrequency)),
                            .float(Float(state.turbulence)),
                            .color(colors[0]),
                            .color(colors[1]),
                            .color(colors[2]),
                            .color(colors[3])
                        )
                    )
                    .compositingGroup()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日のFlow")
        .accessibilityValue(accessibilityValue(state))
    }

    private var resolvedColors: [Color] {
        let fallback = ["#0A84FF", "#30D5C8", "#BF5AF2", "#64D2FF"]
        let values = palette.isEmpty ? fallback : palette
        return (0..<4).map { Color(hex: values[$0 % values.count]) }
    }

    private var frameInterval: TimeInterval {
        isActive ? (1 / 60) : (1 / 30)
    }

    private var animationIsPaused: Bool {
        reduceMotion || isUITesting || scenePhase != .active
    }

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting")
    }

    private func shaderTime(_ date: Date, speed: Double) -> Float {
        guard !animationIsPaused else { return 0 }
        return Float(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000) * speed)
    }

    private func accessibilityValue(_ state: FlowVisualState) -> String {
        switch state.progress {
        case ..<0.01:
            "まだFlowはありません"
        case ..<0.34:
            "小さな流れ"
        case ..<0.84:
            "育っている流れ"
        default:
            "満ちている流れ"
        }
    }
}
