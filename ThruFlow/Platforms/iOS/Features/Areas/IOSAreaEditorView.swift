import SwiftData
import SwiftUI

struct IOSAreaEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.modelContext) private var modelContext

    let mode: IOSAreaEditorMode
    let onSaved: ((Area) -> Void)?

    @State private var name: String
    @State private var symbolName: String
    @State private var type: AreaType
    @State private var colorHex: String
    @State private var goalTarget: Int
    @State private var goalUnit: GoalUnit
    @State private var goalSchedule: GoalScheduleKind
    @State private var weeklyTargetCount: Int
    @State private var weekdayMask: Int
    @State private var showsEmojiPicker = false
    @State private var saveErrorMessage: String?

    private let colors = [
        "#007AFF", "#34C759", "#00C7BE", "#32ADE6", "#5856D6", "#AF52DE",
        "#FF2D55", "#FF3B30", "#FF9500", "#FFCC00", "#8E8E93"
    ]
    private let typeOptions: [AreaType] = [.neutral, .habit, .nice]

    init(
        mode: IOSAreaEditorMode,
        initialDraft: AreaDraft? = nil,
        onSaved: ((Area) -> Void)? = nil
    ) {
        self.mode = mode
        self.onSaved = onSaved

        let draft: AreaDraft
        switch mode {
        case .create(let name):
            if let initialDraft {
                draft = initialDraft.normalizedForEditing
            } else {
                draft = AreaDraft(name: name ?? "").normalizedForEditing
            }
        case .edit(let value):
            draft = AreaDraft(area: value).normalizedForEditing
        }

        _name = State(initialValue: draft.name)
        _symbolName = State(initialValue: draft.symbolName)
        _type = State(initialValue: draft.type)
        _colorHex = State(initialValue: draft.colorHex)
        _goalTarget = State(initialValue: max(1, draft.goalTarget ?? 1))
        _goalUnit = State(initialValue: draft.goalUnit ?? .occurrences)
        _goalSchedule = State(initialValue: draft.goalSchedule ?? .everyDay)
        _weeklyTargetCount = State(initialValue: max(1, draft.weeklyTargetCount ?? 1))
        _weekdayMask = State(initialValue: draft.weekdayMask ?? 0)
        _saveErrorMessage = State(initialValue: nil)
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
                    ForEach(typeOptions) { type in
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
                        WeeklyFrequencySlider(value: $weeklyTargetCount)
                            .frame(maxWidth: 260)
                            .padding(.horizontal, 8)
                    }

                    if goalSchedule != .everyDay {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(
                                goalSchedule == .weekdays
                                    ? String(localized: "曜日")
                                    : String(localized: "曜日（任意）")
                            )
                            .font(.subheadline.weight(.semibold))

                            HStack(spacing: 7) {
                                ForEach(GoalWeekday.allCases) { weekday in
                                    weekdayButton(weekday)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if case .edit(let area) = mode {
                Section {
                    Button(String(localized: "方向を削除"), role: .destructive) {
                        area.archive(calendar: calendar, dayBoundary: dayBoundary)
                        guard modelContext.saveReporting(.areaUpdate) else { return }
                        dismiss()
                    }
                }
            }

            if !draft.trimmedName.isEmpty, !validationErrors.isEmpty {
                Section {
                    ForEach(validationErrors, id: \.self) { error in
                        Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }

            if let saveErrorMessage {
                Section {
                    Label(saveErrorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .iosCenteredNavigationTitle(
            isEditing ? String(localized: "方向を編集") : String(localized: "方向を作成")
        )
        .onChange(of: type) { _, _ in
            let normalized = draft.normalizedForEditing
            goalTarget = normalized.goalTarget ?? 1
            goalUnit = normalized.goalUnit ?? .occurrences
            goalSchedule = normalized.goalSchedule ?? .everyDay
            weeklyTargetCount = normalized.weeklyTargetCount ?? 1
            weekdayMask = normalized.weekdayMask ?? 0
        }
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
                    .accessibilityIdentifier("area.editor.save")
            }
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func weekdayButton(_ weekday: GoalWeekday) -> some View {
        let isSelected = weekdayMask & weekday.rawValue != 0
        return Button {
            if isSelected {
                weekdayMask &= ~weekday.rawValue
            } else {
                weekdayMask |= weekday.rawValue
            }
        } label: {
            Text(weekday.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(isSelected ? Color.accentColor : Color.primary.opacity(0.06), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var draft: AreaDraft {
        AreaDraft(
            name: name,
            type: type,
            symbolName: symbolName,
            colorHex: colorHex,
            goalTarget: goalTarget,
            goalUnit: goalUnit,
            goalSchedule: goalSchedule,
            weeklyTargetCount: weeklyTargetCount,
            weekdayMask: weekdayMask
        )
    }

    private var editingService: AreaEditingService {
        AreaEditingService(calendar: calendar, dayBoundary: dayBoundary)
    }

    private var validationErrors: [AreaValidationError] {
        editingService.validationErrors(for: draft)
    }

    private var canSave: Bool {
        validationErrors.isEmpty
    }

    private func save() {
        saveErrorMessage = nil
        let editedArea: Area?
        if case .edit(let area) = mode { editedArea = area } else { editedArea = nil }

        do {
            let area = try editingService.save(
                draft: draft,
                editing: editedArea,
                modelContext: modelContext
            )
            onSaved?(area)
            dismiss()
        } catch AreaEditingError.validation(let errors) {
            saveErrorMessage = errors.map(\.localizedDescription).joined(separator: "\n")
        } catch {
            saveErrorMessage = String(localized: "記録を保存できませんでした。")
        }
    }
}

private struct IOSEmojiPickerView: View {
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
