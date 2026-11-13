#if os(watchOS)
import SwiftData
import SwiftUI

struct WatchTimerControls: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    let isCompact: Bool
    let selectedArea: Area?
    let selectedTodo: Todo?
    let primaryTint: Color
    @Binding var showsMemo: Bool

    @State private var restButtonReactionSequence = 0

    var body: some View {
        let secondarySize: CGFloat = isCompact ? 24 : 28
        let primarySize: CGFloat = isCompact ? 36 : 44
        let spacing: CGFloat = isCompact ? 2 : 3

        return VStack(spacing: isCompact ? 3 : 5) {
            HStack(spacing: spacing) {
                timerButton("gobackward.5", size: secondarySize) {
                    activeFlowStore.seekBackward(modelContext: modelContext)
                }
                .disabled(!canSeek)
                .accessibilityLabel(String(localized: "残り時間を5分短縮"))

                Button(action: primaryAction) {
                    Image(systemName: primarySymbol)
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: primarySize, height: primarySize)
                        .background(primaryTint, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(selectedArea == nil)
                .accessibilityLabel(primaryActionTitle)

                timerButton("goforward.5", size: secondarySize) {
                    activeFlowStore.seekForward(modelContext: modelContext)
                }
                .disabled(!canSeek)
                .accessibilityLabel(String(localized: "残り時間を5分延長"))
            }

            HStack(spacing: spacing) {
                timerButton(
                    "trash.fill",
                    role: .destructive,
                    tint: .red,
                    size: secondarySize
                ) {
                    activeFlowStore.destroy(modelContext: modelContext)
                }
                .disabled(activeFlowStore.timerState == nil)
                .accessibilityLabel(
                    activeFlowStore.isBreakPhase
                        ? String(localized: "休憩を削除")
                        : String(localized: "Flowを破壊")
                )

                timerButton("stop.fill", size: secondarySize) {
                    activeFlowStore.stop(modelContext: modelContext)
                    showsMemo = activeFlowStore.phase == .awaitingResult
                }
                .disabled(activeFlowStore.timerState == nil)
                .accessibilityLabel(String(localized: "Flowを停止して保存"))

                timerButton(
                    "cup.and.saucer.fill",
                    size: secondarySize,
                    symbolEffectValue: restButtonReactionSequence
                ) {
                    restButtonReactionSequence &+= 1
                    activeFlowStore.requestBreakMemo(modelContext: modelContext)
                    showsMemo = activeFlowStore.isAwaitingBreakMemo
                }
                .disabled(!activeFlowStore.canRequestBreak)
                .accessibilityLabel(String(localized: "休憩を開始"))
                .sensoryFeedback(
                    .impact(weight: .light),
                    trigger: restButtonReactionSequence
                )
            }
        }
    }

    private var primarySymbol: String {
        guard let state = activeFlowStore.timerState else { return "play.fill" }
        if state.phase == .paused { return "play.fill" }
        if activeFlowStore.isBreakPhase { return "forward.fill" }
        return "pause.fill"
    }

    private var primaryActionTitle: String {
        guard let state = activeFlowStore.timerState else {
            return String(localized: "Flowを開始")
        }
        if state.phase == .paused {
            return String(localized: "再開")
        }
        if activeFlowStore.isBreakPhase {
            return String(localized: "Flowを開始")
        }
        return String(localized: "一時停止")
    }

    private var canSeek: Bool {
        activeFlowStore.timerState?.canAdjustRemainingTime == true
    }

    private func primaryAction() {
        if activeFlowStore.isBreakPhase {
            guard let area = selectedArea else { return }
            activeFlowStore.startNextFlow(
                area: area,
                todo: selectedTodo,
                modelContext: modelContext
            )
            return
        }

        if let state = activeFlowStore.timerState {
            state.phase == .paused
                ? activeFlowStore.resume(modelContext: modelContext)
                : activeFlowStore.pause(modelContext: modelContext)
            return
        }

        guard let area = selectedArea else { return }
        activeFlowStore.start(
            area: area,
            todo: selectedTodo,
            modelContext: modelContext
        )
    }

    private func timerButton(
        _ systemName: String,
        role: ButtonRole? = nil,
        tint: Color = .secondary,
        size: CGFloat = 28,
        symbolEffectValue: Int = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .symbolEffect(.bounce, value: symbolEffectValue)
                .frame(width: size, height: size)
                .background(Color.primary.opacity(0.055), in: Circle())
        }
        .buttonStyle(.plain)
    }
}
#endif
