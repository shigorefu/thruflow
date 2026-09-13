//
//  FlowStreamView.swift
//  ThruFlow
//
//

import SwiftUI

struct FlowStreamView: View {
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

    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var windowIsActive: Bool {
        controlActiveState == .key && scenePhase == .active
    }

    var body: some View {
        FlowStreamSurface(
            blocks: blocks,
            flowCount: flowCount,
            palette: palette,
            paletteWeights: paletteWeights,
            dailySeed: dailySeed,
            isActive: isActive,
            mode: mode,
            breakStyle: breakStyle,
            breakInteraction: breakInteraction,
            isRenderingEnabled: isRenderingEnabled && windowIsActive
        )
        .equatable()
        .blur(radius: windowIsActive ? 0 : 8)
        .clipped()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: windowIsActive)
    }
}
