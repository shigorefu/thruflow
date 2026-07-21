import SwiftData
import SwiftUI

struct IOSDirectionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let mode: IOSDirectionEditorMode

    @State private var name: String
    @State private var symbolName: String
    @State private var type: DirectionType
    @State private var colorHex: String
    @State private var goalTarget: Int
    @State private var goalUnit: GoalUnit
    @State private var goalSchedule: GoalScheduleKind
    @State private var weeklyTargetCount: Int
    @State private var showsEmojiPicker = false

    private let colors = [
        "#007AFF", "#34C759", "#00C7BE", "#32ADE6", "#5856D6", "#AF52DE",
        "#FF2D55", "#FF3B30", "#FF9500", "#FFCC00", "#8E8E93"
    ]

    init(mode: IOSDirectionEditorMode) {
        self.mode = mode
        let direction: Direction?
        if case .edit(let value) = mode { direction = value } else { direction = nil }

        _name = State(initialValue: direction?.name ?? "")
        _symbolName = State(initialValue: direction?.symbolName ?? "🎯")
        _type = State(initialValue: direction?.type ?? .neutral)
        _colorHex = State(initialValue: direction?.colorHex ?? "#007AFF")
        _goalTarget = State(initialValue: max(1, direction?.goalTarget ?? 1))
        _goalUnit = State(initialValue: direction?.goalUnit ?? .occurrences)
        _goalSchedule = State(initialValue: direction?.goalSchedule ?? .everyDay)
        _weeklyTargetCount = State(initialValue: max(1, direction?.weeklyTargetCount ?? 1))
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Button {
                        showsEmojiPicker = true
                    } label: {
                        Text(symbolName)
                            .font(.largeTitle)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                        .frame(width: 58, height: 58)
                        .background(Color(hex: colorHex).opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityLabel(String(localized: "絵文字を選択"))

                    TextField(String(localized: "方向名"), text: $name)
                        .font(.title3.weight(.semibold))
                }
            }

            Section(String(localized: "種類")) {
                Picker(String(localized: "種類"), selection: $type) {
                    ForEach(DirectionType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(String(localized: "カラー")) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 34))], spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        Button {
                            colorHex = color
                        } label: {
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if colorHex == color {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            if type == .habit {
                Section(String(localized: "目標")) {
                    Stepper(value: $goalTarget, in: 1...999) {
                        Text("\(String(localized: "目標値")): \(goalTarget)")
                    }
                    Picker(String(localized: "単位"), selection: $goalUnit) {
                        ForEach([GoalUnit.occurrences, .focusBlocks, .minutes]) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    Picker(String(localized: "繰り返し"), selection: $goalSchedule) {
                        ForEach(GoalScheduleKind.allCases) { schedule in
                            Text(schedule.displayName).tag(schedule)
                        }
                    }
                    if goalSchedule == .weeklyCount {
                        Stepper(value: $weeklyTargetCount, in: 1...7) {
                            Text("\(weeklyTargetCount) \(String(localized: "回 / 週"))")
                        }
                    }
                }
            }

            if case .edit(let direction) = mode {
                Section {
                    Button(String(localized: "方向を削除"), role: .destructive) {
                        direction.archive()
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(isEditing ? String(localized: "方向を編集") : String(localized: "方向を作成"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsEmojiPicker) {
            IOSEmojiPickerView(selection: $symbolName)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "キャンセル")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "保存"), action: save)
                    .disabled(!canSave)
            }
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && EmojiValidation.normalizedSingleEmoji(from: symbolName) != nil
    }

    private func save() {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let emoji = EmojiValidation.normalizedSingleEmoji(from: symbolName) ?? "🎯"
        let goalPeriod = type == .habit ? goalSchedule.goalPeriod : nil
        let unit: GoalUnit? = type == .habit ? goalUnit : nil
        let target: Int? = type == .habit ? goalTarget : nil
        let schedule: GoalScheduleKind? = type == .habit ? goalSchedule : nil
        let weeklyCount: Int? = type == .habit && goalSchedule == .weeklyCount ? weeklyTargetCount : nil

        switch mode {
        case .create:
            let direction = Direction(
                name: normalizedName,
                type: type,
                symbolName: emoji,
                colorHex: colorHex,
                goalTarget: target,
                goalPeriod: goalPeriod,
                goalUnit: unit,
                goalSchedule: schedule,
                weeklyTargetCount: weeklyCount
            )
            modelContext.insert(direction)
        case .edit(let direction):
            direction.update(
                name: normalizedName,
                type: type,
                symbolName: emoji,
                colorHex: colorHex,
                goalTarget: target,
                goalPeriod: goalPeriod,
                goalUnit: unit,
                goalSchedule: schedule,
                weeklyTargetCount: weeklyCount,
                weekdayMask: direction.weekdayMask
            )
        }

        try? modelContext.save()
        dismiss()
    }
}

private struct IOSEmojiPickerView: View {
    @Binding var selection: String

    @Environment(\.dismiss) private var dismiss
    @AppStorage("direction.recent-emojis") private var storedRecents = ""

    @State private var searchText = ""
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
            .navigationTitle(String(localized: "絵文字"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: String(localized: "絵文字を検索"))
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
