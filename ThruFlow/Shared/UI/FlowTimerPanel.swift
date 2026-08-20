import SwiftUI

enum FlowTimerPanelStyle: Equatable {
    case mobile
    case dashboard

    var timerStyle: FlowTimerDial.Style {
        switch self {
        case .mobile: .mobile
        case .dashboard: .dashboard
        }
    }
}

struct FlowTimerPresentation {
    let progress: Double
    let tint: Color
    let eyebrow: String
    let timeText: String
    let footer: String
}

/// Production Flow player chrome shared by the real player and onboarding.
/// The shell owns layout only; its callers own application state and actions.
struct FlowTimerPanelShell<Context: View, Mode: View, Controls: View>: View {
    let style: FlowTimerPanelStyle
    let minHeight: CGFloat?
    let timer: FlowTimerPresentation
    let timerAccessibilityLabel: String?
    private let context: Context
    private let mode: Mode
    private let controls: Controls

    init(
        style: FlowTimerPanelStyle,
        minHeight: CGFloat? = nil,
        timer: FlowTimerPresentation,
        timerAccessibilityLabel: String? = nil,
        @ViewBuilder context: () -> Context,
        @ViewBuilder mode: () -> Mode,
        @ViewBuilder controls: () -> Controls
    ) {
        self.style = style
        self.minHeight = minHeight
        self.timer = timer
        self.timerAccessibilityLabel = timerAccessibilityLabel
        self.context = context()
        self.mode = mode()
        self.controls = controls()
    }

    @ViewBuilder
    var body: some View {
        switch style {
        case .mobile:
            VStack(spacing: 12) {
                context
                mode

                HStack(spacing: 18) {
                    timerDial
                    controls
                }
                .frame(maxWidth: .infinity)
            }
            .padding(14)
            .frame(minHeight: minHeight, alignment: .top)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

        case .dashboard:
            VStack(spacing: 18) {
                context
                mode
                timerDial
                controls
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.08))
            }
        }
    }

    @ViewBuilder
    private var timerDial: some View {
        let dial = FlowTimerDial(
            progress: timer.progress,
            tint: timer.tint,
            eyebrow: timer.eyebrow,
            timeText: timer.timeText,
            footer: timer.footer,
            style: style.timerStyle
        )

        if let timerAccessibilityLabel {
            dial
                .accessibilityElement(children: .combine)
                .accessibilityLabel(timerAccessibilityLabel)
        } else {
            dial
        }
    }
}

struct FlowTimerContextPresentation {
    let symbol: String
    let areaTitle: String
    let tint: Color
    let detail: String?
    let isPlaceholder: Bool
    let showsProgress: Bool
}

struct FlowTimerContextButton<Title: View, Progress: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let style: FlowTimerPanelStyle
    let presentation: FlowTimerContextPresentation
    let isVisuallyPressed: Bool
    let animatesVisualPress: Bool
    let accessibilityLabel: String
    let action: () -> Void
    private let title: Title
    private let progress: Progress

    init(
        style: FlowTimerPanelStyle,
        presentation: FlowTimerContextPresentation,
        isVisuallyPressed: Bool = false,
        animatesVisualPress: Bool = false,
        accessibilityLabel: String,
        action: @escaping () -> Void,
        @ViewBuilder title: () -> Title,
        @ViewBuilder progress: () -> Progress
    ) {
        self.style = style
        self.presentation = presentation
        self.isVisuallyPressed = isVisuallyPressed
        self.animatesVisualPress = animatesVisualPress
        self.accessibilityLabel = accessibilityLabel
        self.action = action
        self.title = title()
        self.progress = progress()
    }

    @ViewBuilder
    var body: some View {
        switch style {
        case .mobile:
            Button(action: action) {
                HStack(spacing: 12) {
                    if presentation.showsProgress {
                        progress
                    }

                    artwork(size: 46, cornerRadius: 11, font: .title2)

                    VStack(alignment: .leading, spacing: 2) {
                        title
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        HStack(spacing: 5) {
                            Circle()
                                .fill(presentation.tint)
                                .frame(width: 6, height: 6)
                            Text(presentation.areaTitle)
                                .lineLimit(1)
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(presentation.isPlaceholder ? Color.secondary : presentation.tint)
                    }

                    Spacer(minLength: 0)
                    chevron
                        .foregroundStyle(presentation.tint)
                        .frame(width: 28, height: 28)
                        .background(presentation.tint.opacity(0.12), in: Circle())
                }
                .padding(10)
                .background(presentation.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(presentation.tint.opacity(presentation.isPlaceholder ? 0.55 : 0.28))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .scaleEffect(isVisuallyPressed ? 0.985 : 1)
            .opacity(isVisuallyPressed ? 0.82 : 1)
            .transaction(configurePressTransaction)
            .accessibilityLabel(accessibilityLabel)

        case .dashboard:
            HStack(spacing: 8) {
                if presentation.showsProgress {
                    progress
                }

                HStack(spacing: 12) {
                    artwork(size: 42, cornerRadius: 8, font: .system(size: 22))

                    VStack(alignment: .leading, spacing: 2) {
                        title
                            .font(.headline)
                            .foregroundStyle(presentation.isPlaceholder ? Color.secondary.opacity(0.7) : Color.primary)
                            .lineLimit(1)

                        Text(presentation.areaTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if let detail = presentation.detail {
                            Text(detail)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(presentation.tint)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                    chevron
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .scaleEffect(isVisuallyPressed ? 0.985 : 1)
                .opacity(isVisuallyPressed ? 0.82 : 1)
                .transaction(configurePressTransaction)
                .onTapGesture(perform: action)
            }
            .padding(.leading, presentation.showsProgress ? 6 : 0)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.primary.opacity(0.08))
            }
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: accessibilityLabel) {
                action()
            }
        }
    }

    private func artwork(size: CGFloat, cornerRadius: CGFloat, font: Font) -> some View {
        Text(presentation.symbol)
            .font(font)
            .frame(width: size, height: size)
            .background(
                presentation.tint.opacity(style == .dashboard ? 0.18 : 0.16),
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
            .overlay {
                if style == .dashboard {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(presentation.tint.opacity(0.24))
                }
            }
            .accessibilityHidden(true)
    }

    private func configurePressTransaction(_ transaction: inout Transaction) {
        guard animatesVisualPress, !reduceMotion else { return }
        transaction.animation = .easeOut(duration: 0.1)
    }

    private var chevron: some View {
        Image(systemName: "chevron.down")
            .font(.caption.weight(.semibold))
    }
}

enum FlowTimerPanelAction: Equatable, Sendable {
    case seekBackward
    case primary
    case seekForward
    case destroy
    case stop
    case startBreak
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
