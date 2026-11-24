#if os(iOS)
import SwiftUI

struct IOSTaskComposerQuickInputLegend: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(String(localized: "ショートカットを使えます"), systemImage: "command")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 0)
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "クイック入力のヒントを非表示"))
            }

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                GridRow {
                    legendItem("[ ]", String(localized: "チェック"))
                    legendItem("@", String(localized: "分野"))
                }
                GridRow {
                    legendItem("[1b]", String(localized: "1ブロック"))
                    legendItem("!", String(localized: "優先度"))
                }
                GridRow {
                    legendItem("[25m]", String(localized: "25分"))
                    legendItem("/", String(localized: "日付"))
                }
                GridRow {
                    legendItem("#", String(localized: "タグ"))
                    legendItem("9:00", String(localized: "時刻"))
                }
            }
        }
        .foregroundStyle(.secondary)
        .padding(11)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func legendItem(_ shortcut: String, _ label: String) -> some View {
        HStack(spacing: 7) {
            Text(verbatim: shortcut)
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 38, alignment: .leading)
            Text(label)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

struct IOSTaskComposerAutocompletePanel: View {
    let suggestions: [IOSQuickInputSuggestion]
    let onSelect: (IOSQuickInputSuggestion) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { suggestion in
                Button {
                    onSelect(suggestion)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: suggestion.systemImage)
                            .foregroundStyle(.tint)
                            .frame(width: 22)
                        Text(suggestion.title)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                        if let detail = suggestion.detail {
                            Text(detail)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 42)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if suggestion.id != suggestions.last?.id {
                    Divider().padding(.leading, 44)
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct IOSQuickInputSuggestion: Identifiable {
    enum Action {
        case area(UUID)
        case token(String)
        case title(String)
    }

    let id: String
    let title: String
    let detail: String?
    let systemImage: String
    let action: Action
}
#endif
