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
                    TextField("名前", text: $draft.name)

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

                Section("表示") {
                    EmojiSelector(selection: $draft.symbolName)

                    ColorSwatchSelector(selection: $draft.colorHex)
                }

                Section("目標") {
                    Toggle("目標を使う", isOn: $draft.goalEnabled)

                    if draft.goalEnabled {
                        Stepper(value: goalTargetBinding, in: 1...1000) {
                            Text("目標値: \(draft.goalTarget ?? 1)")
                        }

                        Picker("期間", selection: goalPeriodBinding) {
                            ForEach(GoalPeriod.allCases) { period in
                                Text(period.displayName).tag(period)
                            }
                        }

                        Picker("単位", selection: goalUnitBinding) {
                            ForEach(GoalUnit.allCases) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
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
    }

    private var goalTargetBinding: Binding<Int> {
        Binding(
            get: { draft.goalTarget ?? 1 },
            set: { draft.goalTarget = $0 }
        )
    }

    private var goalPeriodBinding: Binding<GoalPeriod> {
        Binding(
            get: { draft.goalPeriod ?? .daily },
            set: { draft.goalPeriod = $0 }
        )
    }

    private var goalUnitBinding: Binding<GoalUnit> {
        Binding(
            get: { draft.goalUnit ?? .focusBlocks },
            set: { draft.goalUnit = $0 }
        )
    }

    private func save() {
        validationErrors = validator.validate(draft)
        guard validationErrors.isEmpty else { return }

        let goalTarget = draft.goalEnabled ? draft.goalTarget : nil
        let goalPeriod = draft.goalEnabled ? draft.goalPeriod : nil
        let goalUnit = draft.goalEnabled ? draft.goalUnit : nil

        switch mode {
        case .create:
            let direction = Direction(
                name: draft.trimmedName,
                type: draft.type,
                symbolName: draft.normalizedSymbolName,
                colorHex: draft.colorHex,
                goalTarget: goalTarget,
                goalPeriod: goalPeriod,
                goalUnit: goalUnit
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
                goalUnit: goalUnit
            )
        }

        dismiss()
    }
}

private struct EmojiSelector: View {
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("絵文字")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(emojiOptions, id: \.self) { emoji in
                        Button {
                            selection = emoji
                        } label: {
                            Text(emoji)
                                .font(.title2)
                                .frame(width: 36, height: 36)
                                .background(selection == emoji ? Color.accentColor.opacity(0.18) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("絵文字 \(emoji)")
                    }
                }
                .padding(.vertical, 2)
            }

            TextField("Apple絵文字", text: $selection)
                .textFieldStyle(.roundedBorder)
        }
    }
}

private struct ColorSwatchSelector: View {
    @Binding var selection: String

    private let columns = [
        GridItem(.adaptive(minimum: 44), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("色")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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

private let emojiOptions = [
    "🎯",
    "📝",
    "💼",
    "📚",
    "🧠",
    "💻",
    "☁️",
    "🗾",
    "🏃‍♂️",
    "🏋️",
    "🧹",
    "🚶",
    "🍱",
    "😴",
    "🎮",
    "🏠",
    "📌",
    "⭐️"
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
