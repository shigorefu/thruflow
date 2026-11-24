import SwiftUI

enum FlowTimerPanelAction: Equatable, Sendable {
    case seekBackward
    case primary
    case seekForward
    case destroy
    case stop
    case startBreak
}

enum FlowTimerPrimaryTintRole: Equatable, Sendable {
    case area
    case paused
    case breakTime

    init(phase: FlowPhase, isFocusOvertime: Bool) {
        switch phase {
        case .paused:
            self = .paused
        case .breakTime:
            self = .breakTime
        case .focusing where isFocusOvertime:
            self = .area
        default:
            self = .area
        }
    }
}

struct FlowTimerTransportPresentation {
    let primarySymbol: String
    let primaryLabel: String
    let primaryTint: Color
    let isPrimaryEnabled: Bool
    let canSeek: Bool
    let canDestroy: Bool
    let canStop: Bool
    let canStartBreak: Bool
    let destroyLabel: String
    let visuallyPressedAction: FlowTimerPanelAction?
}

struct FlowTimerTransportControls: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let style: FlowTimerPanelStyle
    let presentation: FlowTimerTransportPresentation
    var animatesVisualPress = false
    var animatesPrimarySymbol = false
    let action: (FlowTimerPanelAction) -> Void

    @ViewBuilder
    var body: some View {
        switch style {
        case .mobile:
            VStack(spacing: 10) {
                HStack(spacing: 5) {
                    mobileControl("gobackward.5", action: .seekBackward)
                        .disabled(!presentation.canSeek)
                        .accessibilityLabel(String(localized: "残り時間を5分短縮"))

                    primaryButton(size: 62, font: .title2.weight(.bold))

                    mobileControl("goforward.5", action: .seekForward)
                        .disabled(!presentation.canSeek)
                        .accessibilityLabel(String(localized: "残り時間を5分延長"))
                }

                HStack(spacing: 8) {
                    mobileControl("trash.fill", action: .destroy, role: .destructive)
                        .disabled(!presentation.canDestroy)
                        .accessibilityLabel(presentation.destroyLabel)

                    mobileControl("stop.fill", action: .stop)
                        .disabled(!presentation.canStop)
                        .accessibilityLabel(String(localized: "Flowを停止して保存"))

                    mobileControl("cup.and.saucer.fill", action: .startBreak)
                        .disabled(!presentation.canStartBreak)
                        .accessibilityLabel(String(localized: "休憩を開始"))
                }
            }
            .frame(maxWidth: .infinity)

        case .dashboard:
            HStack(spacing: 6) {
                dashboardSlot(isEnabled: presentation.canDestroy) {
                    dashboardControl(
                        "trash.fill",
                        action: .destroy,
                        role: .destructive,
                        foreground: .red
                    )
                        .accessibilityLabel(presentation.destroyLabel)
                }
                dashboardSlot(isEnabled: presentation.canStop) {
                    dashboardControl("stop.fill", action: .stop)
                        .accessibilityLabel(String(localized: "Flowを停止して保存"))
                }
                dashboardSlot(isEnabled: presentation.canStartBreak) {
                    dashboardControl("cup.and.saucer.fill", action: .startBreak)
                        .accessibilityLabel(String(localized: "休憩を開始"))
                }
                dashboardSlot(isEnabled: presentation.canSeek) {
                    dashboardControl("gobackward.5", action: .seekBackward)
                        .accessibilityLabel(String(localized: "残り時間を5分短縮"))
                }

                primaryButton(size: 42, font: .title3.weight(.semibold))

                dashboardSlot(isEnabled: presentation.canSeek) {
                    dashboardControl("goforward.5", action: .seekForward)
                        .accessibilityLabel(String(localized: "残り時間を5分延長"))
                }
            }
            .padding(3)
            .background(Color.primary.opacity(0.06))
            .clipShape(Capsule())
        }
    }

    private func primaryButton(size: CGFloat, font: Font) -> some View {
        Button {
            action(.primary)
        } label: {
            Image(systemName: presentation.primarySymbol)
                .font(font)
                .contentTransition(reduceMotion || !animatesPrimarySymbol ? .identity : .opacity)
                .animation(reduceMotion || !animatesPrimarySymbol ? nil : .smooth(duration: 0.20),
                           value: presentation.primarySymbol)
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(presentation.primaryTint, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!presentation.isPrimaryEnabled)
        .scaleEffect(presentation.visuallyPressedAction == .primary ? 0.88 : 1)
        .opacity(presentation.visuallyPressedAction == .primary ? 0.82 : 1)
        .transaction(configurePressTransaction)
        .accessibilityLabel(presentation.primaryLabel)
    }

    private func mobileControl(
        _ systemName: String,
        action panelAction: FlowTimerPanelAction,
        role: ButtonRole? = nil
    ) -> some View {
        Button(role: role) {
            action(panelAction)
        } label: {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .frame(width: 38, height: 38)
                .background(Color.primary.opacity(0.055), in: Circle())
        }
        .buttonStyle(.plain)
        .scaleEffect(presentation.visuallyPressedAction == panelAction ? 0.88 : 1)
        .opacity(presentation.visuallyPressedAction == panelAction ? 0.72 : 1)
        .transaction(configurePressTransaction)
    }

    private func dashboardControl(
        _ systemName: String,
        action panelAction: FlowTimerPanelAction,
        role: ButtonRole? = nil,
        foreground: Color = .secondary
    ) -> some View {
        Button(role: role) {
            action(panelAction)
        } label: {
            Image(systemName: systemName)
                .font(.callout.weight(.semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground)
        .scaleEffect(presentation.visuallyPressedAction == panelAction ? 0.86 : 1)
        .opacity(presentation.visuallyPressedAction == panelAction ? 0.68 : 1)
        .transaction(configurePressTransaction)
    }

    private func dashboardSlot<Content: View>(
        isEnabled: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.34)
    }

    private func configurePressTransaction(_ transaction: inout Transaction) {
        guard animatesVisualPress, !reduceMotion else { return }
        transaction.animation = .easeOut(duration: 0.1)
    }
}
