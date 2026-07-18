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
                    TextField("🎯", text: $symbolName)
                        .font(.largeTitle)
                        .multilineTextAlignment(.center)
                        .frame(width: 58, height: 58)
                        .background(Color(hex: colorHex).opacity(0.18), in: RoundedRectangle(cornerRadius: 10))

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
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && symbolName.first != nil
    }

    private func save() {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let emoji = symbolName.first.map(String.init) ?? "🎯"
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
