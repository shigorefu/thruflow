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

    @Environment(\.controlActiveState) private var controlActiveState

    var body: some View {
        FlowStreamSurface(
            blocks: blocks,
            flowCount: flowCount,
            palette: palette,
            isActive: isActive,
            mode: mode,
            isRenderingEnabled: controlActiveState == .key
        )
    }
}
