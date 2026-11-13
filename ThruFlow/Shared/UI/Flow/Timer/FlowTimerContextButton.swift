import SwiftUI

struct FlowTimerContextPresentation {
    let symbol: String
    let areaTitle: String
    let tint: Color
    let isPlaceholder: Bool
    let showsProgress: Bool
}

struct FlowTimerContextButton<Title: View, Progress: View, Detail: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let style: FlowTimerPanelStyle
    let presentation: FlowTimerContextPresentation
    let isVisuallyPressed: Bool
    let animatesVisualPress: Bool
    let accessibilityLabel: String
    let action: () -> Void
    private let title: Title
    private let progress: Progress
    private let detail: Detail

    init(
        style: FlowTimerPanelStyle,
        presentation: FlowTimerContextPresentation,
        isVisuallyPressed: Bool = false,
        animatesVisualPress: Bool = false,
        accessibilityLabel: String,
        action: @escaping () -> Void,
        @ViewBuilder title: () -> Title,
        @ViewBuilder progress: () -> Progress,
        @ViewBuilder detail: () -> Detail = { EmptyView() }
    ) {
        self.style = style
        self.presentation = presentation
        self.isVisuallyPressed = isVisuallyPressed
        self.animatesVisualPress = animatesVisualPress
        self.accessibilityLabel = accessibilityLabel
        self.action = action
        self.title = title()
        self.progress = progress()
        self.detail = detail()
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
            .animation(pressAnimation) { card in
                card.scaleEffect(isVisuallyPressed ? 0.985 : 1)
                    .opacity(isVisuallyPressed ? 0.82 : 1)
            }
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

                        detail
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(presentation.tint)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                    chevron
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .animation(pressAnimation) { card in
                    card.scaleEffect(isVisuallyPressed ? 0.985 : 1)
                        .opacity(isVisuallyPressed ? 0.82 : 1)
                }
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

    private var pressAnimation: Animation? {
        animatesVisualPress && !reduceMotion ? .smooth(duration: 0.16) : nil
    }

    private var chevron: some View {
        Image(systemName: "chevron.down")
            .font(.caption.weight(.semibold))
    }
}
