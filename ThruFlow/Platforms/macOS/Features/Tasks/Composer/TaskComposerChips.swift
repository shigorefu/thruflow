#if os(macOS)
import SwiftData
import SwiftUI

struct PriorityChip: View {
    @Binding var priority: TodoPriority
    @Binding var isRoomIfPossible: Bool
    @Binding var isExplicit: Bool

    var body: some View {
        Menu {
            ForEach(TodoPriority.allCases) { option in
                Button {
                    priority = option
                    isExplicit = true
                    if option != .low {
                        isRoomIfPossible = false
                    }
                } label: {
                    menuRow(text: option.displayName, isSelected: priority == option)
                }
            }

            if priority == .low {
                Divider()

                Button {
                    isRoomIfPossible.toggle()
                    isExplicit = true
                } label: {
                    menuRow(text: String(localized: "余裕があれば"), isSelected: isRoomIfPossible)
                }
            }
        } label: {
            Text(labelText)
                .chipStyle(tint: tint)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel(String(localized: "優先度を選択"))
    }

    private var labelText: String {
        isExplicit ? priority.displayName : String(localized: "優先度")
    }

    private var tint: Color {
        switch priority {
        case .high:
            .red
        case .medium:
            .secondary
        case .low:
            .green
        }
    }

    @ViewBuilder
    private func menuRow(text: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(text, systemImage: "checkmark").labelStyle(.titleAndIcon)
        } else {
            Text(text)
        }
    }
}

struct RoomIfPossibleChip: View {
    @Binding var isSelected: Bool

    var body: some View {
        Button {
            isSelected.toggle()
        } label: {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.green, lineWidth: 1.4)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isSelected ? Color.green : Color.clear)
                    )
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 13, height: 13)

                Text(String(localized: "余裕があれば"))
            }
            .chipStyle(tint: .green)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "余裕があれば"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct AreaChip: View {
    @Binding var selectedAreaID: UUID?
    @Binding var isExplicit: Bool

    let areas: [Area]

    private var selectedArea: Area? {
        guard let selectedAreaID else { return nil }
        return areas.first { $0.id == selectedAreaID }
    }

    private var labelText: String {
        guard isExplicit else {
            return String(localized: "分野")
        }
        guard let selectedArea else {
            return String(localized: "その他")
        }

        return "\(selectedArea.symbolName) \(selectedArea.name)"
    }

    var body: some View {
        Menu {
            ForEach(areas) { area in
                Button {
                    selectedAreaID = area.id
                    isExplicit = true
                } label: {
                    menuRow(
                        text: "\(area.symbolName) \(area.name)",
                        isSelected: selectedAreaID == area.id
                    )
                }
            }

            if !areas.isEmpty { Divider() }

            Button {
                selectedAreaID = nil
                isExplicit = true
            } label: {
                menuRow(text: String(localized: "その他"), isSelected: selectedAreaID == nil)
            }
        } label: {
            Text(labelText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .chipStyle(tint: chipColor)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel(String(localized: "方向を選択"))
    }

    @ViewBuilder
    private func menuRow(text: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(text, systemImage: "checkmark").labelStyle(.titleAndIcon)
        } else {
            Text(text)
        }
    }

    private var chipColor: Color {
        guard let selectedArea, !DefaultAreas.isTaskInbox(selectedArea) else {
            return .secondary
        }
        return Color(hex: selectedArea.colorHex)
    }
}

struct VolumeChip: View {
    @Binding var volume: QuickTodoVolume

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: typeIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 13, height: 16)
                .contentTransition(.symbolEffect(.replace))

            if volume.measurement == .checkbox {
                Text(typeLabel)
                    .foregroundStyle(volume == .unspecified ? .secondary : .primary)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            } else {
                TextField("1", value: amountBinding, format: .number)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .frame(width: 25)

                Text(volume.measurement == .focusBlocks ? String(localized: "ブロック") : String(localized: "分"))
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }

            Menu {
                Button { volume = .checkbox } label: {
                    menuRow(String(localized: "チェック"), selected: volume.measurement == .checkbox && volume != .unspecified)
                }
                Button { volume = .blocks(max(1, volume.plannedAmount ?? 1)) } label: {
                    menuRow(String(localized: "ブロック"), selected: volume.measurement == .focusBlocks)
                }
                Button { volume = .minutes(max(1, volume.plannedAmount ?? 25)) } label: {
                    menuRow(TodoMeasurement.minutes.displayName, selected: volume.measurement == .minutes)
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 20)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
        .font(.caption.weight(.medium))
        .padding(.leading, 9)
        .padding(.trailing, 5)
        .frame(height: 30)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
        }
        .animation(.snappy(duration: 0.22), value: volume.measurement)
        .accessibilityLabel(String(localized: "タスクの分量を選択"))
    }

    private var typeIcon: String {
        switch volume {
        case .unspecified: "square.dashed"
        case .checkbox: "checkmark.square"
        case .blocks: "circle"
        case .minutes: "circle.lefthalf.filled"
        }
    }

    private var iconColor: Color {
        volume == .unspecified ? .secondary : .accentColor
    }

    private var typeLabel: String {
        switch volume {
        case .unspecified: String(localized: "種類")
        case .checkbox: String(localized: "チェック")
        case .blocks: String(localized: "ブロック")
        case .minutes: TodoMeasurement.minutes.displayName
        }
    }

    private var amountBinding: Binding<Int> {
        Binding(
            get: { max(1, volume.plannedAmount ?? 1) },
            set: { value in
                let amount = max(1, value)
                volume = volume.measurement == .focusBlocks ? .blocks(amount) : .minutes(amount)
            }
        )
    }

    @ViewBuilder
    private func menuRow(_ text: String, selected: Bool) -> some View {
        if selected { Label(text, systemImage: "checkmark").labelStyle(.titleAndIcon) } else { Text(text) }
    }
}

struct DateChip: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar

    @Binding var dateOption: QuickTodoDate
    @Binding var isExplicit: Bool

    @State private var showingCustomPicker = false
    @State private var customDate = Date.now

    var body: some View {
        Menu {
            Button {
                dateOption = .today
                isExplicit = true
            } label: {
                menuRow(text: String(localized: "今日"), isSelected: dateOption == .today)
            }

            Button {
                dateOption = .tomorrow
                isExplicit = true
            } label: {
                menuRow(text: String(localized: "明日"), isSelected: dateOption == .tomorrow)
            }

            Button {
                dateOption = .none
                isExplicit = true
            } label: {
                menuRow(text: String(localized: "日付なし"), isSelected: dateOption == .none)
            }

            Divider()

            Button(String(localized: "他の日付...")) {
                customDate = dateOption.resolvedDate(
                    calendar: calendar,
                    dayBoundary: dayBoundary
                ) ?? .now
                showingCustomPicker = true
            }
        } label: {
            Text(isExplicit ? dateOption.chipLabel : String(localized: "日付"))
                .chipStyle(tint: .secondary)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel(String(localized: "日付を選択"))
        .popover(isPresented: $showingCustomPicker) {
            VStack(spacing: 12) {
                DatePicker(String(localized: "日付"), selection: $customDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()

                Button(String(localized: "設定")) {
                    dateOption = .custom(customDate)
                    isExplicit = true
                    showingCustomPicker = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(minWidth: 280)
        }
    }

    @ViewBuilder
    private func menuRow(text: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(text, systemImage: "checkmark").labelStyle(.titleAndIcon)
        } else {
            Text(text)
        }
    }
}

extension View {
    func chipStyle(tint: Color) -> some View {
        self
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.16))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }
}
#endif
