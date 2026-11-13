#if os(iOS)
import SwiftUI

struct IOSFlowStreamView: View {
    let snapshot: FlowDashboardSnapshot
    let isActive: Bool
    let mode: FlowMode
    let breakStyle: FlowStreamBreakStyle
    let breakInteraction: FlowBreakInteraction?
    let isRenderingEnabled: Bool

    var body: some View {
        FlowStreamSurface(
            blocks: snapshot.blocks,
            flowCount: snapshot.flowCount,
            palette: snapshot.palette,
            paletteWeights: snapshot.paletteWeights,
            dailySeed: snapshot.dailyVisualSeed,
            isActive: isActive,
            mode: mode,
            breakStyle: breakStyle,
            breakInteraction: breakInteraction,
            isRenderingEnabled: isRenderingEnabled
        )
        .equatable()
    }
}
#endif
