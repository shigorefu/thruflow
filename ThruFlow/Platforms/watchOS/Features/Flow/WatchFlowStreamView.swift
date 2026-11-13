#if os(watchOS)
import Foundation
import SwiftData
import SwiftUI

struct WatchFlowStreamView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore
    @Query(sort: \Area.sortIndex) private var areas: [Area]
    @Query private var sessions: [FlowSession]
    @Query private var flowBreaks: [FlowBreak]

    let isVisible: Bool
    @State private var isImmersive = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let snapshot = FlowDashboardBuilder(
                calendar: calendar,
                dayBoundary: dayBoundary
            ).build(
                date: timeline.date,
                sessions: sessions,
                breaks: flowBreaks,
                activeSessionID: activeFlowStore.activeSession?.id,
                activeFocusSeconds: activeFlowStore.actualFocusSeconds(now: timeline.date),
                visualIdentityID: DailyFlowIdentity.resolve(from: areas)
            )

            FlowStreamSurface(
                blocks: snapshot.blocks,
                flowCount: snapshot.flowCount,
                palette: snapshot.palette,
                paletteWeights: snapshot.paletteWeights,
                dailySeed: snapshot.dailyVisualSeed,
                isActive: activeFlowStore.phase == .focusing,
                mode: activeFlowStore.selectedMode,
                breakStyle: activeFlowStore.flowStreamBreakStyle,
                breakInteraction: activeFlowStore.flowBreakInteraction,
                isRenderingEnabled: isVisible
            )
            .ignoresSafeArea()
            .overlay {
                if !isImmersive {
                    VStack {
                        HStack {
                            Text(String(localized: "今日のFlow"))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay {
                                    Capsule()
                                        .strokeBorder(Color.white.opacity(0.22))
                                }
                            Spacer()
                        }

                        Spacer()

                        HStack {
                            Text(BlockUnit.displayText(forFocusedSeconds: snapshot.totalFocusSeconds))
                            Spacer()
                            Text(String(localized: "集中\(snapshot.flowCount)回"))
                        }
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.16))
                        }
                    }
                    .padding(8)
                    .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isImmersive.toggle()
                }
            }
        }
        .accessibilityHint(
            isImmersive
                ? String(localized: "情報を表示")
                : String(localized: "情報を隠す")
        )
    }
}
#endif
