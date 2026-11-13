#if os(iOS)
import SwiftUI

struct IOSTaskTitleSuggestionPanel: View {
    let suggestions: [TaskTitleSuggestion]
    let onSelect: (TaskTitleSuggestion) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(suggestions) { suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        Label(suggestion.title, systemImage: "clock.arrow.circlepath")
                            .font(.subheadline)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(.regularMaterial, in: Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
#endif
