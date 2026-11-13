#if os(macOS)
import SwiftUI

struct FlowTaskTitleSuggestions: View {
    let suggestions: [TaskTitleSuggestion]
    var highlightedID: String? = nil
    let onSelect: (TaskTitleSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(suggestions) { suggestion in
                Button {
                    onSelect(suggestion)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(.tint)
                            .frame(width: 16)
                        Text(suggestion.title)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                    .background(
                        suggestion.id == highlightedID ? Color.accentColor.opacity(0.18) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.12))
        }
    }
}
#endif
