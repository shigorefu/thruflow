#if os(iOS)
import SwiftUI

struct IOSEmojiPickerView: View {
    @Binding var selection: String

    @Environment(\.dismiss) private var dismiss
    @AppStorage("direction.recent-emojis") private var storedRecents = ""

    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var customEmoji = ""
    @State private var customError = false

    private let columns = [GridItem(.adaptive(minimum: 42), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if !recents.isEmpty, searchText.isEmpty {
                        emojiSection(String(localized: "最近"), emojis: recents)
                    }

                    ForEach(Array(filteredSections.enumerated()), id: \.offset) { _, section in
                        emojiSection(section.title, emojis: section.emojis)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "その他の絵文字"))
                            .font(.headline)
                        HStack {
                            TextField("🙂", text: $customEmoji)
                                .textInputAutocapitalization(.never)
                                .font(.title2)
                            Button(String(localized: "選択")) {
                                guard let emoji = EmojiValidation.normalizedSingleEmoji(from: customEmoji) else {
                                    customError = true
                                    return
                                }
                                choose(emoji)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        if customError {
                            Text(String(localized: "絵文字を1つ入力してください"))
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(16)
            }
            .iosCenteredNavigationTitle(String(localized: "絵文字"))
            .iosToolbarSearch(
                text: $searchText,
                isPresented: $isSearchPresented,
                prompt: String(localized: "絵文字を検索")
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "閉じる")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func emojiSection(_ title: String, emojis: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(emojis, id: \.self) { emoji in
                    Button {
                        choose(emoji)
                    } label: {
                        Text(emoji)
                            .font(.title2)
                            .frame(width: 42, height: 42)
                            .background(
                                selection == emoji ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.045),
                                in: RoundedRectangle(cornerRadius: 9)
                            )
                            .overlay {
                                if selection == emoji {
                                    RoundedRectangle(cornerRadius: 9)
                                        .strokeBorder(Color.accentColor, lineWidth: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var recents: [String] {
        storedRecents.split(separator: "|").map(String.init)
    }

    private var filteredSections: [(title: String, emojis: [String])] {
        emojiSections.compactMap { section in
            guard !searchText.isEmpty else { return section }
            let query = searchText.lowercased()
            guard section.title.lowercased().contains(query) else { return nil }
            return section
        }
    }

    private var emojiSections: [(title: String, emojis: [String])] {
        [
            (String(localized: "People"), ["😀", "🙂", "🤓", "🧑‍💻", "🧑‍🎨", "🧑‍🏫", "💪", "🧘"]),
            (String(localized: "Activities"), ["🏃", "🏋️", "⚽️", "🎾", "🎨", "🎵", "🎮", "🏆"]),
            (String(localized: "Work & Study"), ["💻", "📚", "📝", "📖", "🎓", "🧠", "🔬", "📊"]),
            (String(localized: "Objects"), ["📱", "⌚️", "💡", "🔧", "📌", "🗂️", "✏️", "🎯"]),
            (String(localized: "Food"), ["☕️", "🍎", "🥗", "🍜", "🍙", "🥐", "🍵", "🥛"]),
            (String(localized: "Travel"), ["🚶", "🚲", "🚆", "✈️", "🗺️", "🏠", "🏫", "🏢"]),
            (String(localized: "Nature"), ["🌱", "🌿", "🌳", "🌊", "🔥", "☀️", "🌙", "⛰️"]),
            (String(localized: "Symbols"), ["✅", "⭐️", "❤️", "💜", "🔵", "🟢", "⚡️", "♾️"]),
        ]
    }

    private func choose(_ emoji: String) {
        selection = emoji
        var updated = recents.filter { $0 != emoji }
        updated.insert(emoji, at: 0)
        storedRecents = updated.prefix(20).joined(separator: "|")
        dismiss()
    }
}
#endif
