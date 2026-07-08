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

                    Text(draft.type.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("表示") {
                    Picker("シンボル", selection: $draft.symbolName) {
                        ForEach(symbolOptions, id: \.self) { symbolName in
                            Label(symbolName, systemImage: symbolName).tag(symbolName)
                        }
                    }

                    Picker("色", selection: $draft.colorHex) {
                        ForEach(colorOptions, id: \.hex) { option in
                            Label(option.name, systemImage: "circle.fill")
                                .foregroundStyle(Color(hex: option.hex))
                                .tag(option.hex)
                        }
                    }
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

private let symbolOptions = [
    "circle",
    "briefcase",
    "book.closed",
    "graduationcap",
    "figure.run",
    "house",
    "cloud",
    "character.book.closed"
]

private let colorOptions: [(name: String, hex: String)] = [
    ("青", "#3B82F6"),
    ("緑", "#10B981"),
    ("オレンジ", "#F97316"),
    ("ピンク", "#EC4899"),
    ("藍", "#6366F1"),
    ("グレー", "#6B7280")
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
