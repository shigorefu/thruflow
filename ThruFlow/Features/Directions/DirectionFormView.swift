//
//  DirectionFormView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import SwiftData
import SwiftUI

struct DirectionFormView: View {
    enum Mode {
        case create
        case edit(Direction)

        var title: String {
            switch self {
            case .create:
                "新しい方向"
            case .edit:
                "方向を編集"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let mode: Mode

    @State private var draft: DirectionDraft
    @State private var validationErrors: [DirectionValidationError] = []

    private let validator = DirectionValidator()

    init(mode: Mode) {
        self.mode = mode

        switch mode {
        case .create:
            _draft = State(initialValue: DirectionDraft())
        case .edit(let direction):
            _draft = State(initialValue: DirectionDraft(direction: direction))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本") {
                    HStack(spacing: 12) {
                        EmojiPopoverButton(selection: $draft.symbolName)

                        TextField("方向名", text: $draft.name)
                            .textFieldStyle(.plain)

                        ColorPopoverButton(selection: $draft.colorHex)
                    }
                    .padding(.vertical, 4)
                }

                Section("種類") {
                    Picker("種類", selection: $draft.type) {
                        ForEach(DirectionType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(draft.type.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if draft.type == .must {
                    Section("目標") {
                        HStack {
                            Text("目標値")

                            TextField("1", value: goalTargetBinding, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 90)

                            Picker("単位", selection: goalUnitBinding) {
                                ForEach(goalUnitOptions) { unit in
                                    Text(unit.displayName).tag(unit)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 180)
                        }

                        Picker("頻度", selection: goalScheduleBinding) {
                            ForEach(GoalScheduleKind.allCases) { schedule in
                                Text(schedule.displayName).tag(schedule)
                            }
                        }
                        .pickerStyle(.segmented)

                        goalScheduleDetails
                    }
                }

                if !validationErrors.isEmpty {
                    Section {
                        ForEach(validationErrors, id: \.self) { error in
                            Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(mode.title)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                }
            }
        }
        .onAppear {
            normalizeGoalState(for: draft.type)
        }
        .onChange(of: draft.type) { _, newType in
            normalizeGoalState(for: newType)
        }
        .onChange(of: draft.goalSchedule) { _, _ in
            normalizeGoalState(for: draft.type)
        }
    }

    private var goalTargetBinding: Binding<Int> {
        Binding(
            get: { draft.goalTarget ?? 1 },
            set: { draft.goalTarget = $0 }
        )
    }

    private var goalUnitBinding: Binding<GoalUnit> {
        Binding(
            get: { draft.goalUnit ?? .focusBlocks },
            set: { draft.goalUnit = $0 }
        )
    }

    private var goalScheduleBinding: Binding<GoalScheduleKind> {
        Binding(
            get: { draft.goalSchedule ?? .everyDay },
            set: { draft.goalSchedule = $0 }
        )
    }

    private var weeklyTargetCountBinding: Binding<Int> {
        Binding(
            get: { draft.weeklyTargetCount ?? 1 },
            set: { draft.weeklyTargetCount = $0 }
        )
    }

    @ViewBuilder
    private var goalScheduleDetails: some View {
        switch draft.goalSchedule ?? .everyDay {
        case .everyDay:
            Text("毎日この目標を達成します。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .weeklyCount:
            Stepper("週 \(draft.weeklyTargetCount ?? 1) 回", value: weeklyTargetCountBinding, in: 1...7)

            VStack(alignment: .leading, spacing: 8) {
                Text("任意: 曜日も選べます")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                WeekdaySelectionView(selection: $draft.weekdayMask)
            }
        case .weekdays:
            VStack(alignment: .leading, spacing: 8) {
                Text("取り組む曜日")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                WeekdaySelectionView(selection: $draft.weekdayMask)
            }
        }
    }

    private func save() {
        normalizeGoalState(for: draft.type)
        validationErrors = validator.validate(draft)
        guard validationErrors.isEmpty else { return }

        let requiresGoal = draft.type == .must
        let goalSchedule = requiresGoal ? draft.goalSchedule : nil
        let goalTarget = requiresGoal ? draft.goalTarget : nil
        let goalPeriod = goalSchedule?.goalPeriod
        let goalUnit = requiresGoal ? draft.goalUnit : nil
        let weeklyTargetCount = requiresGoal && goalSchedule == .weeklyCount ? draft.weeklyTargetCount : nil
        let weekdayMask = requiresGoal && goalSchedule != .everyDay ? draft.weekdayMask : nil

        switch mode {
        case .create:
            let direction = Direction(
                name: draft.trimmedName,
                type: draft.type,
                symbolName: draft.normalizedSymbolName,
                colorHex: draft.colorHex,
                goalTarget: goalTarget,
                goalPeriod: goalPeriod,
                goalUnit: goalUnit,
                goalSchedule: goalSchedule,
                weeklyTargetCount: weeklyTargetCount,
                weekdayMask: weekdayMask
            )
            modelContext.insert(direction)
        case .edit(let direction):
            direction.update(
                name: draft.trimmedName,
                type: draft.type,
                symbolName: draft.normalizedSymbolName,
                colorHex: draft.colorHex,
                goalTarget: goalTarget,
                goalPeriod: goalPeriod,
                goalUnit: goalUnit,
                goalSchedule: goalSchedule,
                weeklyTargetCount: weeklyTargetCount,
                weekdayMask: weekdayMask
            )
        }

        dismiss()
    }

    private func normalizeGoalState(for type: DirectionType) {
        guard type == .must else {
            draft.goalEnabled = false
            draft.goalTarget = nil
            draft.goalPeriod = nil
            draft.goalUnit = nil
            draft.goalSchedule = nil
            draft.weeklyTargetCount = nil
            draft.weekdayMask = nil
            return
        }

        draft.goalEnabled = true
        draft.goalTarget = draft.goalTarget ?? 1
        draft.goalUnit = draft.goalUnit ?? .focusBlocks
        draft.goalSchedule = draft.goalSchedule ?? .everyDay
        draft.goalPeriod = draft.goalSchedule?.goalPeriod

        if draft.goalSchedule == .weeklyCount {
            draft.weeklyTargetCount = draft.weeklyTargetCount ?? 1
        }
    }
}

private struct EmojiPopoverButton: View {
    @Binding var selection: String

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Text(selection)
                .font(.largeTitle)
                .frame(width: 52, height: 52)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("絵文字")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            EmojiGrid(selection: $selection)
                .frame(width: 320, height: 280)
                .padding()
        }
    }
}

private struct EmojiGrid: View {
    @Binding var selection: String

    private let columns = [
        GridItem(.adaptive(minimum: 36), spacing: 6)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("絵文字")
                .font(.headline)

            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                    ForEach(emojiOptions, id: \.self) { emoji in
                        Button {
                            selection = emoji
                        } label: {
                            Text(emoji)
                                .font(.title2)
                                .frame(width: 36, height: 36)
                                .background(selection == emoji ? Color.accentColor.opacity(0.2) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("絵文字 \(emoji)")
                    }
                }
            }

            TextField("絵文字を入力", text: $selection)
                .textFieldStyle(.roundedBorder)
        }
    }
}

private struct ColorPopoverButton: View {
    @Binding var selection: String

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Circle()
                .fill(Color(hex: selection))
                .frame(width: 24, height: 24)
                .padding(8)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("カラー")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ColorGrid(selection: $selection)
                .frame(width: 260)
                .padding()
        }
    }
}

private struct ColorGrid: View {
    @Binding var selection: String

    private let columns = [
        GridItem(.adaptive(minimum: 44), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("カラー")
                .font(.headline)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(colorOptions, id: \.hex) { option in
                    Button {
                        selection = option.hex
                    } label: {
                        Circle()
                            .fill(Color(hex: option.hex))
                            .frame(width: 28, height: 28)
                            .overlay {
                                if selection == option.hex {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: 44, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.name)
                }
            }
        }
    }
}

private struct WeekdaySelectionView: View {
    @Binding var selection: Int?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(GoalWeekday.allCases) { weekday in
                Button {
                    toggle(weekday)
                } label: {
                    Text(weekday.displayName)
                        .font(.body.weight(isSelected(weekday) ? .semibold : .regular))
                        .frame(width: 34, height: 30)
                        .background(isSelected(weekday) ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(weekday.displayName)
            }
        }
    }

    private func isSelected(_ weekday: GoalWeekday) -> Bool {
        ((selection ?? 0) & weekday.rawValue) != 0
    }

    private func toggle(_ weekday: GoalWeekday) {
        var mask = selection ?? 0

        if isSelected(weekday) {
            mask &= ~weekday.rawValue
        } else {
            mask |= weekday.rawValue
        }

        selection = mask == 0 ? nil : mask
    }
}

private let emojiOptions = [
    "🎯", "📝", "💼", "📚", "🧠", "💻", "☁️", "🗾",
    "🏃‍♂️", "🏋️", "🧹", "🚶", "🍱", "😴", "🎮", "🏠",
    "📌", "⭐️", "✅", "🔥", "💡", "📈", "📅", "✍️",
    "📖", "🎧", "🎨", "🎹", "📷", "🌱", "🌙", "☀️",
    "❤️", "🧘", "🚴", "🏊", "🛠️", "💬", "💰", "🧾",
    "🧩", "🧪", "🗂️", "📦", "🚀", "🛒", "🍎", "🥗",
    "☕️", "🌍", "🧳"
]

private let colorOptions: [(name: String, hex: String)] = [
    ("ブルー", "#007AFF"),
    ("グリーン", "#34C759"),
    ("ミント", "#00C7BE"),
    ("ティール", "#30B0C7"),
    ("シアン", "#32ADE6"),
    ("インディゴ", "#5856D6"),
    ("パープル", "#AF52DE"),
    ("ピンク", "#FF2D55"),
    ("レッド", "#FF3B30"),
    ("オレンジ", "#FF9500"),
    ("イエロー", "#FFCC00"),
    ("グレー", "#8E8E93")
]

private let goalUnitOptions: [GoalUnit] = [
    .focusBlocks,
    .minutes
]

extension Color {
    init(hex: String) {
        let sanitized = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255

        self.init(red: red, green: green, blue: blue)
    }
}

#Preview("方向を作成") {
    DirectionFormView(mode: .create)
        .modelContainer(for: Direction.self, inMemory: true)
}
