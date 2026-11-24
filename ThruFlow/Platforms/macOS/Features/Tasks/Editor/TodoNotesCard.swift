#if os(macOS)
import SwiftUI

struct TodoNotesCard: View {
    @Binding var notes: String
    @Binding var hashtagsText: String

    var body: some View {
        TodoEditorCard {
            VStack(alignment: .leading, spacing: 7) {
                Label(String(localized: "メモ"), systemImage: "note.text")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField(String(localized: "メモ"), text: $notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...5)
            }

            VStack(alignment: .leading, spacing: 7) {
                Label(String(localized: "ハッシュタグ"), systemImage: "number")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField(String(localized: "ハッシュタグ"), text: $hashtagsText)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

struct TodoEditorCard<Content: View>: View {
    let title: String?
    private let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let title {
                Text(title)
                    .font(.headline)
            }

            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
#endif
