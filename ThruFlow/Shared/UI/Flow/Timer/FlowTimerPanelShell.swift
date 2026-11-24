import SwiftUI

struct FlowTimerPanelShell<Dial: View, Context: View, Mode: View, Controls: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let style: FlowTimerPanelStyle
    let minHeight: CGFloat?
    private let dial: Dial
    let timerAccessibilityLabel: String?
    private let context: Context
    private let mode: Mode
    private let controls: Controls

    init(
        style: FlowTimerPanelStyle,
        minHeight: CGFloat? = nil,
        timerAccessibilityLabel: String? = nil,
        @ViewBuilder dial: () -> Dial,
        @ViewBuilder context: () -> Context,
        @ViewBuilder mode: () -> Mode,
        @ViewBuilder controls: () -> Controls
    ) {
        self.style = style
        self.minHeight = minHeight
        self.dial = dial()
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

                FlowTimerMobileLayout(allowsHorizontal: !dynamicTypeSize.isAccessibilitySize) {
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
        if let timerAccessibilityLabel {
            dial
                .accessibilityElement(children: .combine)
                .accessibilityLabel(timerAccessibilityLabel)
        } else {
            dial
        }
    }
}

/// Keep the real player and its demo readable inside narrow cards without
/// replacing either the timer or the controls when the available width changes.
private nonisolated struct FlowTimerMobileLayout: Layout {
    var allowsHorizontal: Bool
    private let spacing: CGFloat = 18

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let ideal = subviews.map { $0.sizeThatFits(.unspecified) }
        let width = max(0, proposal.width ?? (ideal[0].width + spacing + ideal[1].width))
        if let sizes = horizontalSizes(width: width, subviews: subviews) {
            return CGSize(width: width, height: max(sizes[0].height, sizes[1].height))
        }
        let vertical = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
        return CGSize(width: width, height: vertical[0].height + spacing + vertical[1].height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        if let sizes = horizontalSizes(width: bounds.width, subviews: subviews) {
            subviews[0].place(
                at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading,
                proposal: ProposedViewSize(sizes[0])
            )
            subviews[1].place(
                at: CGPoint(x: bounds.minX + sizes[0].width + spacing, y: bounds.midY), anchor: .leading,
                proposal: ProposedViewSize(sizes[1])
            )
        } else {
            let childProposal = ProposedViewSize(width: bounds.width, height: nil)
            var y = bounds.minY
            for subview in subviews {
                subview.place(at: CGPoint(x: bounds.midX, y: y), anchor: .top, proposal: childProposal)
                y += subview.sizeThatFits(childProposal).height + spacing
            }
        }
    }

    private func horizontalSizes(width: CGFloat, subviews: Subviews) -> [CGSize]? {
        guard allowsHorizontal else { return nil }
        let controlsWidth = subviews[1].sizeThatFits(.unspecified).width
        let diameter = min(FlowTimerDial.Style.mobile.size, width - controlsWidth - spacing)
        guard diameter >= FlowTimerDial.Style.mobile.minimumSize else { return nil }
        // Propose a square: the ring may shrink slightly, but button targets do not.
        let dial = subviews[0].sizeThatFits(ProposedViewSize(width: diameter, height: diameter))
        let controls = subviews[1].sizeThatFits(ProposedViewSize(width: width - dial.width - spacing, height: nil))
        return [dial, controls]
    }
}
