#if os(macOS)
import SwiftData
import SwiftUI

struct FlowMiniPlayerTransport: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    let style: FlowMiniPlayerView.Style
    let now: Date
    let artworkColor: Color
    let handlePrimaryAction: () -> Void

    @ViewBuilder
    var body: some View {
        if style == .dashboard {
            dashboardTransportControls
        } else {
            headerTransportControls
        }
    }

    private var headerTransportControls: some View {
        HStack(spacing: 6) {
            if style == .dashboard {
                compactControlSlot(isEnabled: activeFlowStore.timerState != nil) {
                    destroyButton
                }

                compactControlSlot(isEnabled: activeFlowStore.timerState != nil) {
                    stopButton
                }

                compactControlSlot(isEnabled: activeFlowStore.canRequestBreak) {
                    breakButton
                }

                compactControlSlot(isEnabled: canSeek) {
                    seekBackwardButton
                }

                primaryButton(now: now)

                compactControlSlot(isEnabled: canSeek) {
                    seekForwardButton
                }
            } else {
                if activeFlowStore.timerState != nil {
                    destroyButton
                    stopButton
                }

                if activeFlowStore.canRequestBreak {
                    breakButton
                }

                if canSeek {
                    seekBackwardButton
                }

                primaryButton(now: now)

                if canSeek {
                    seekForwardButton
                }
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.06))
        .clipShape(Capsule())
    }

    private var dashboardTransportControls: some View {
        FlowTimerTransportControls(
            style: .dashboard,
            presentation: FlowTimerTransportPresentation(
                primarySymbol: primaryButtonImage(now: now),
                primaryLabel: primaryButtonTitle(now: now),
                primaryTint: primaryButtonColor(now: now),
                isPrimaryEnabled: true,
                canSeek: canSeek,
                canDestroy: activeFlowStore.timerState != nil,
                canStop: activeFlowStore.timerState != nil,
                canStartBreak: activeFlowStore.canRequestBreak,
                destroyLabel: activeFlowStore.isBreakPhase
                    ? String(localized: "休憩を削除")
                    : String(localized: "Flowを破壊"),
                visuallyPressedAction: nil
            ),
            animatesPrimarySymbol: true
        ) { action in
            switch action {
            case .seekBackward:
                activeFlowStore.seekBackward(modelContext: modelContext)
            case .primary:
                handlePrimaryAction()
            case .seekForward:
                activeFlowStore.seekForward(modelContext: modelContext)
            case .destroy:
                activeFlowStore.destroy(modelContext: modelContext)
            case .stop:
                activeFlowStore.stop(modelContext: modelContext)
            case .startBreak:
                activeFlowStore.requestBreakMemo(modelContext: modelContext)
            }
        }
    }

    private func compactControlSlot<Content: View>(
        isEnabled: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.34)
    }

    private var controlButtonSize: CGFloat {
        34
    }

    private var primaryControlButtonSize: CGFloat {
        42
    }

    private var seekBackwardButton: some View {
        Button {
            activeFlowStore.seekBackward(modelContext: modelContext)
        } label: {
            Image(systemName: "gobackward.5")
                .font(.callout.weight(.semibold))
                .frame(width: controlButtonSize, height: controlButtonSize)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(String(localized: "残り時間を5分短縮"))
    }

    private var seekForwardButton: some View {
        Button {
            activeFlowStore.seekForward(modelContext: modelContext)
        } label: {
            Image(systemName: "goforward.5")
                .font(.callout.weight(.semibold))
                .frame(width: controlButtonSize, height: controlButtonSize)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(String(localized: "残り時間を5分延長"))
    }

    private var stopButton: some View {
        Button {
            activeFlowStore.stop(modelContext: modelContext)
        } label: {
            Image(systemName: "stop.fill")
                .font(.callout.weight(.semibold))
                .frame(width: controlButtonSize, height: controlButtonSize)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(String(localized: "Flowを停止して保存"))
    }

    private var breakButton: some View {
        Button {
            activeFlowStore.requestBreakMemo(modelContext: modelContext)
        } label: {
            Image(systemName: "cup.and.saucer.fill")
                .font(.callout.weight(.semibold))
                .frame(width: controlButtonSize, height: controlButtonSize)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(String(localized: "休憩を開始"))
    }

    private var destroyButton: some View {
        Button(role: .destructive) {
            activeFlowStore.destroy(modelContext: modelContext)
        } label: {
            Image(systemName: "trash.fill")
                .font(.callout.weight(.semibold))
                .frame(width: controlButtonSize, height: controlButtonSize)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.red)
        .accessibilityLabel(activeFlowStore.isBreakPhase ? String(localized: "休憩を削除") : String(localized: "Flowを破壊"))
    }

    private func primaryButton(now: Date) -> some View {
        Button {
            handlePrimaryAction()
        } label: {
            if style == .dashboard {
                Image(systemName: primaryButtonImage(now: now))
                    .font(.title3.weight(.semibold))
                    .frame(width: primaryControlButtonSize, height: primaryControlButtonSize)
                    .background(primaryButtonColor(now: now))
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            } else {
                Label(primaryButtonTitle(now: now), systemImage: primaryButtonImage(now: now))
                    .font(.headline.weight(.semibold))
                    .frame(width: 142, height: 44)
                    .background(primaryButtonColor(now: now))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(primaryButtonTitle(now: now))
    }

    private func primaryButtonTitle(now: Date) -> String {
        switch activeFlowStore.phase {
        case .idle, .configured:
            String(localized: "Flowを開始")
        case .focusing:
            activeFlowStore.isFocusOvertime(now: now) ? String(localized: "休憩") : String(localized: "一時停止")
        case .paused:
            String(localized: "再開")
        case .breakTime:
            String(localized: "Flowを開始")
        case .awaitingExtensionDecision:
            String(localized: "Flowを終了")
        case .awaitingResult:
            String(localized: "保存")
        case .completed:
            String(localized: "Flowを開始")
        }
    }

    private func primaryButtonImage(now: Date) -> String {
        switch activeFlowStore.phase {
        case .focusing:
            activeFlowStore.isFocusOvertime(now: now) ? "cup.and.saucer.fill" : "pause.fill"
        case .awaitingResult:
            "checkmark"
        default:
            "play.fill"
        }
    }

    private func primaryButtonColor(now: Date) -> Color {
        switch FlowTimerPrimaryTintRole(
            phase: activeFlowStore.phase,
            isFocusOvertime: activeFlowStore.isFocusOvertime(now: now)
        ) {
        case .area:
            artworkColor
        case .paused, .breakTime:
            .blue
        }
    }

    private var canSeek: Bool {
        activeFlowStore.timerState?.canAdjustRemainingTime == true
    }
}
#endif
