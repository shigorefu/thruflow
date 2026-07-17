//
//  EmojiPickerView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import SwiftUI

struct EmojiPickerView: View {
    @Binding var selection: String

    @Environment(\.dismiss) private var dismiss
    @AppStorage("direction.recentEmoji") private var recentEmojiRaw = "[]"

    @State private var searchText = ""
    @State private var customEmoji = ""
    @State private var customEmojiError: String?

    private let columns = [
        GridItem(.adaptive(minimum: 38), spacing: 8)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        recentSection

                        ForEach(filteredCategories) { category in
                            emojiSection(title: category.name, emoji: category.emoji)
                        }

                        customEmojiSection
                    }
                    .padding()
                }
            }
            .navigationTitle(String(localized: "絵文字"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "閉じる")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(String(localized: "検索"), text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding([.horizontal, .top])
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "絵文字を検索"))
    }

    private var customEmojiSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "その他の絵文字"))
                .font(.headline)

            HStack(spacing: 10) {
                TextField(String(localized: "絵文字を入力"), text: $customEmoji)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(selectCustomEmoji)

                Button(String(localized: "追加"), action: selectCustomEmoji)
                    .disabled(customEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let customEmojiError {
                Text(customEmojiError)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text(String(localized: "複数入力された場合は最初の絵文字だけ保存します。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private var recentEmoji: [String] {
        guard let data = recentEmojiRaw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }

        return decoded.filter { EmojiValidation.normalizedSingleEmoji(from: $0) != nil }
    }

    private var filteredRecentEmoji: [String] {
        filtered(recentEmoji)
    }

    private var filteredCategories: [EmojiCategory] {
        emojiCategories.compactMap { category in
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if category.name.localizedCaseInsensitiveContains(query) {
                return category
            }

            let filteredEmoji = filtered(category.emoji)
            guard !filteredEmoji.isEmpty else { return nil }
            return EmojiCategory(name: category.name, emoji: filteredEmoji)
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Recent"))
                .font(.headline)

            if filteredRecentEmoji.isEmpty {
                Text(String(localized: "最近使った絵文字はまだありません。"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(filteredRecentEmoji, id: \.self) { value in
                        emojiButton(value)
                    }
                }
            }
        }
    }

    private func emojiSection(title: String, emoji: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(emoji, id: \.self) { value in
                    emojiButton(value)
                }
            }
        }
    }

    private func emojiButton(_ value: String) -> some View {
        Button {
            select(value)
        } label: {
            Text(value)
                .font(.system(size: 28))
                .frame(width: 38, height: 38)
                .background(selection == value ? Color.accentColor.opacity(0.22) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay {
                    if selection == value {
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(Color.accentColor, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "絵文字 \(value)"))
        .accessibilityAddTraits(selection == value ? [.isSelected] : [])
    }

    private func filtered(_ emoji: [String]) -> [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return emoji }

        return emoji.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    private func selectCustomEmoji() {
        guard let normalized = EmojiValidation.normalizedSingleEmoji(from: customEmoji) else {
            customEmojiError = String(localized: "絵文字を1つ入力してください。")
            return
        }

        customEmojiError = nil
        customEmoji = normalized
        select(normalized)
    }

    private func select(_ emoji: String) {
        selection = emoji
        storeRecentEmoji(emoji)
        dismiss()
    }

    private func storeRecentEmoji(_ emoji: String) {
        var values = recentEmoji.filter { $0 != emoji }
        values.insert(emoji, at: 0)
        values = Array(values.prefix(20))

        guard let data = try? JSONEncoder().encode(values),
              let raw = String(data: data, encoding: .utf8) else {
            return
        }

        recentEmojiRaw = raw
    }
}

struct EmojiCategory: Identifiable {
    let name: String
    let emoji: [String]

    var id: String { name }
}

private let emojiCategories: [EmojiCategory] = [
    EmojiCategory(
        name: String(localized: "People"),
        emoji: ["😀", "😄", "😊", "😌", "🙂", "😎", "🤔", "🥳", "👍", "👏", "🙏", "💪", "🧑‍💻", "👩‍🎓", "🧑‍🏫", "🧘"]
    ),
    EmojiCategory(
        name: String(localized: "Activities"),
        emoji: ["🎯", "✅", "🔥", "🏃‍♂️", "🏋️", "🚴", "🏊", "🎮", "🎧", "🎨", "🎹", "📷", "🧩", "🧘", "🚶", "🏆"]
    ),
    EmojiCategory(
        name: String(localized: "Work & Study"),
        emoji: ["💼", "📚", "📝", "🧠", "💻", "📈", "📅", "✍️", "📖", "🎓", "🧪", "🗂️", "📌", "💡", "🛠️", "💬"]
    ),
    EmojiCategory(
        name: String(localized: "Objects"),
        emoji: ["📦", "🧾", "💰", "🛒", "📱", "⌚️", "🎒", "🔑", "🧰", "🪴", "🛏️", "🪑", "💊", "📎", "🖊️", "📓"]
    ),
    EmojiCategory(
        name: String(localized: "Food"),
        emoji: ["🍎", "🥗", "🍱", "☕️", "🍵", "🥐", "🍳", "🍜", "🍣", "🍙", "🥛", "🍫", "🍊", "🥑", "🍞", "🍰"]
    ),
    EmojiCategory(
        name: String(localized: "Travel"),
        emoji: ["🌍", "🧳", "🗾", "✈️", "🚆", "🚗", "🚲", "⛵️", "🏕️", "🏙️", "🏠", "🗺️", "🗽", "⛰️", "🏖️", "🚀"]
    ),
    EmojiCategory(
        name: String(localized: "Nature"),
        emoji: ["🌱", "🌙", "☀️", "⭐️", "🌿", "🌲", "🌊", "🔥", "🌧️", "❄️", "🌸", "🍀", "🌵", "🌻", "⛰️", "☁️"]
    ),
    EmojiCategory(
        name: String(localized: "Symbols"),
        emoji: ["❤️", "⭐️", "✅", "☑️", "🔵", "🟢", "🟡", "🔴", "🟣", "⚪️", "⚫️", "🔁", "➡️", "⬆️", "💤", "♻️"]
    )
]
