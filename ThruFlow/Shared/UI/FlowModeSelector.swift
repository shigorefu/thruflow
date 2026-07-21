import SwiftUI

struct FlowModeSelector: View {
    enum HelpPresentation {
        case popover
        case sheet
    }

    @Binding var selection: FlowMode

    let isSelectionEnabled: Bool
    var helpPresentation: HelpPresentation = .popover
    var onSelect: ((FlowMode) -> Void)?

    @State private var showsHelp = false

    private let modes: [FlowMode] = [.sprint, .twentyFiveFive, .fiftyTen]

    var body: some View {
        HStack(spacing: 8) {
            Picker(String(localized: "Flowタイプ"), selection: selectionBinding) {
                ForEach(modes) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!isSelectionEnabled)

            helpButton
        }
    }

    @ViewBuilder
    private var helpButton: some View {
        let button = Button {
            showsHelp = true
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.body.weight(.semibold))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(String(localized: "Flowタイプのヘルプ"))

        switch helpPresentation {
        case .popover:
            button.popover(isPresented: $showsHelp, arrowEdge: .bottom) {
                helpContent
                    .frame(idealWidth: 360)
                    .presentationCompactAdaptation(.none)
            }
        case .sheet:
            button.sheet(isPresented: $showsHelp) {
                ScrollView {
                    helpContent
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var helpContent: some View {
        FlowModeHelpView(
            selectedMode: selection,
            modes: modes,
            isSelectionEnabled: isSelectionEnabled
        ) { mode in
            selectionBinding.wrappedValue = mode
            showsHelp = false
        }
    }

    private var selectionBinding: Binding<FlowMode> {
        Binding(
            get: { selection },
            set: { mode in
                selection = mode
                onSelect?(mode)
            }
        )
    }
}

private struct FlowModeHelpView: View {
    let selectedMode: FlowMode
    let modes: [FlowMode]
    let isSelectionEnabled: Bool
    let select: (FlowMode) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Flowタイプ"))
                        .font(.headline)
                    Text(String(localized: "作業に合う集中の長さを選びます"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(String(localized: "閉じる"))
            }

            ForEach(modes) { mode in
                Button {
                    select(mode)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: mode.iconName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(mode.iconColor, in: RoundedRectangle(cornerRadius: 11))

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(mode.displayName)
                                    .font(.headline)
                                Text(mode.workBreakText)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }

                            Text(mode.usageDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)

                        if selectedMode == mode {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(mode.iconColor)
                        }
                    }
                    .padding(10)
                    .background(
                        selectedMode == mode
                            ? mode.iconColor.opacity(0.13)
                            : Color.primary.opacity(0.045),
                        in: RoundedRectangle(cornerRadius: 13)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isSelectionEnabled)
            }
        }
        .padding(16)
    }
}

private extension FlowMode {
    var iconName: String {
        switch self {
        case .sprint: "flame.fill"
        case .twentyFiveFive: "target"
        case .fiftyTen: "mountain.2.fill"
        case .adaptive: "sparkles"
        }
    }

    var iconColor: Color {
        switch self {
        case .sprint: .orange
        case .twentyFiveFive: .blue
        case .fiftyTen: .purple
        case .adaptive: .teal
        }
    }

    var workBreakText: String {
        switch self {
        case .sprint: String(localized: "12分作業 / 3分休憩")
        case .twentyFiveFive: String(localized: "25分作業 / 5分休憩")
        case .fiftyTen: String(localized: "50分作業 / 10分休憩")
        case .adaptive: String(localized: "12分から開始")
        }
    }

    var usageDescription: String {
        switch self {
        case .sprint:
            String(localized: "短い作業や、まず始めたいときに")
        case .twentyFiveFive:
            String(localized: "日常の集中作業に")
        case .fiftyTen:
            String(localized: "中断せず深く取り組みたいときに")
        case .adaptive:
            String(localized: "作業時間に合わせて調整します")
        }
    }
}
