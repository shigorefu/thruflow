#if !os(watchOS)
import SwiftUI

struct ProjectHabitFormSection: View {
    @Binding var settings: ProjectHabitSettings

    var body: some View {
#if os(macOS)
        EditorSectionCard(title: String(localized: "プロジェクトの習慣")) {
            Toggle(String(localized: "習慣を設定"), isOn: $settings.isEnabled)
                .toggleStyle(.switch)
            explanation
        }
        if settings.isEnabled {
            EditorSectionCard(title: String(localized: "目標")) {
                HStack(spacing: 10) {
                    TextField("1", value: $settings.goalTarget, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 82)
                        .accessibilityLabel(String(localized: "目標値"))
                    unitPicker.labelsHidden().frame(maxWidth: 180)
                    Spacer(minLength: 0)
                }
                schedulePicker.pickerStyle(.segmented)
                scheduleDetails
            }
        }
#else
        Section {
            Toggle(String(localized: "習慣を設定"), isOn: $settings.isEnabled)
        } header: {
            Text(String(localized: "プロジェクトの習慣"))
        } footer: {
            explanation
        }
        if settings.isEnabled {
            Section(String(localized: "目標")) {
                Stepper(value: $settings.goalTarget, in: 1...999) {
                    Text("\(String(localized: "目標値")): \(settings.goalTarget)")
                }
                unitPicker
                schedulePicker
                scheduleDetails
            }
        }
#endif
    }

    private var explanation: some View {
        Text(String(localized: "設定したスケジュールに合わせて、このプロジェクトの習慣タスクを自動で作成します。"))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var unitPicker: some View {
        Picker(String(localized: "単位"), selection: $settings.goalUnit) {
            ForEach(GoalUnit.allCases) { Text($0.displayName).tag($0) }
        }
    }

    private var schedulePicker: some View {
        Picker(String(localized: "頻度"), selection: $settings.goalSchedule) {
            ForEach(GoalScheduleKind.allCases) { Text($0.displayName).tag($0) }
        }
    }

    @ViewBuilder
    private var scheduleDetails: some View {
        if settings.goalSchedule == .everyDay {
            Text(String(localized: "毎日この目標を達成します。"))
                .font(.footnote).foregroundStyle(.secondary)
        } else {
            if settings.goalSchedule == .weeklyCount {
                WeeklyFrequencySlider(value: $settings.weeklyTargetCount)
                    .frame(maxWidth: 260)
                    .padding(.horizontal, 8)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(settings.goalSchedule == .weekdays
                     ? String(localized: "取り組む曜日") : String(localized: "任意: 曜日も選べます"))
                    .font(.footnote).foregroundStyle(.secondary)
                HStack(spacing: 7) {
                    ForEach(GoalWeekday.allCases) { weekday in
                        weekdayButton(weekday)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func weekdayButton(_ weekday: GoalWeekday) -> some View {
        let selection = weekdaySelection(weekday)
#if os(macOS)
        Toggle(weekday.displayName, isOn: selection)
            .toggleStyle(.button)
            .frame(maxWidth: .infinity)
#else
        Button { selection.wrappedValue.toggle() } label: {
            Text(weekday.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selection.wrappedValue ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(selection.wrappedValue ? Color.accentColor : Color.primary.opacity(0.06), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection.wrappedValue ? .isSelected : [])
#endif
    }

    private func weekdaySelection(_ weekday: GoalWeekday) -> Binding<Bool> {
        Binding(get: { (settings.weekdayMask ?? 0) & weekday.rawValue != 0 }, set: { selected in
            let mask = settings.weekdayMask ?? 0
            settings.weekdayMask = selected ? mask | weekday.rawValue : mask & ~weekday.rawValue
        })
    }
}
#endif
