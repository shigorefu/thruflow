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
    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.scenePhase) private var scenePhase
    @State private var animationClock = FlowAnimationClock()
    @State private var impulseStartedAt: Date?

    var body: some View {
        let state = FlowVisualState(blocks: blocks, flowCount: flowCount, isActive: isActive, mode: mode)
        let colors = resolvedColors

        TimelineView(.animation(minimumInterval: frameInterval, paused: animationIsPaused)) { timeline in
            GeometryReader { proxy in
                let impulse = impulseProgress(at: timeline.date)

                Rectangle()
                    .fill(.white)
                    .colorEffect(
                        ShaderLibrary.flowStream(
                            .float2(proxy.size),
                            .float(Float(animationClock.phase(
                                at: timeline.date,
                                speed: state.speed,
                                isPaused: animationIsPaused
                            ))),
                            .float(Float(state.progress)),
                            .float(Float(state.volume)),
                            .float(Float(state.detail)),
                            .float(Float(state.layerCount)),
                            .float(Float(state.waveFrequency)),
                            .float(Float(state.turbulence)),
                            .float(Float(impulse)),
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

    private var frameInterval: TimeInterval {
        isActive ? (1 / 60) : (1 / 30)
    }

    private var animationIsPaused: Bool {
        reduceMotion || isUITesting || scenePhase != .active || controlActiveState != .key
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
