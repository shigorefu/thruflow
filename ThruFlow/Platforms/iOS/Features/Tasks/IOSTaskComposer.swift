import SwiftData
import SwiftUI

struct IOSTaskComposer: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext

    let directions: [Direction]

    @State private var title = ""
    @State private var directionID: UUID?
    @State private var measurement = TodoMeasurement.checkbox
    @State private var plannedAmount = 1
    @State private var priority = TodoPriority.medium
    @State private var dateOption = IOSComposerDate.today
    @State private var unresolvedDirection: String?
    @FocusState private var isFocused: Bool

    private let parser = TaskQuickInputParser()

    var body: some View {
        VStack(spacing: 8) {
            TextField(String(localized: "タスクを入力してください"), text: $title, axis: .vertical)
                .lineLimit(1...4)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit(submit)

            HStack(spacing: 8) {
                measurementMenu
                directionMenu
                priorityMenu
                dateMenu
                Spacer(minLength: 0)

                Button(action: submit) {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(canSubmit ? Color.accentColor : Color.secondary.opacity(0.35), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .accessibilityLabel(String(localized: "タスクを追加"))
            }
            .font(.caption.weight(.medium))
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .task {
            directionID = defaultDirection?.id
        }
        .alert(
            String(localized: "方向"),
            isPresented: Binding(
                get: { unresolvedDirection != nil },
                set: { if !$0 { unresolvedDirection = nil } }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            if let unresolvedDirection {
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "方向「%@」が見つかりません"),
                        unresolvedDirection
                    )
                )
            }
        }
    }

    private var measurementMenu: some View {
        Menu {
            Button { measurement = .checkbox } label: {
                Label(TodoMeasurement.checkbox.displayName, systemImage: "checkmark.square")
            }
            Button { measurement = .focusBlocks } label: {
                Label(TodoMeasurement.focusBlocks.displayName, systemImage: "circle")
            }
            Button { measurement = .minutes } label: {
                Label(TodoMeasurement.minutes.displayName, systemImage: "timer")
            }

            if measurement != .checkbox {
                Divider()
                Stepper(value: $plannedAmount, in: 1...999) {
                    Text(targetText)
                }
            }
        } label: {
            compactLabel(measurementTitle, systemImage: measurementSymbol)
        }
    }

    private var directionMenu: some View {
        Menu {
            ForEach(directions) { direction in
                Button {
                    directionID = direction.id
                } label: {
                    Text("\(direction.symbolName) \(direction.name)")
                }
            }
        } label: {
            compactLabel(selectedDirection?.name ?? String(localized: "方向"), systemImage: "scope")
        }
    }

    private var priorityMenu: some View {
        Menu {
            ForEach(TodoPriority.allCases) { value in
                Button(value.displayName) { priority = value }
            }
        } label: {
            compactLabel(priority.displayName, systemImage: "flag")
        }
    }

    private var dateMenu: some View {
        Menu {
            ForEach(IOSComposerDate.allCases) { value in
                Button(value.displayName) { dateOption = value }
            }
        } label: {
            compactLabel(dateOption.displayName, systemImage: "calendar")
        }
    }

    private func compactLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .lineLimit(1)
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color.primary.opacity(0.05), in: Capsule())
    }

    private var selectedDirection: Direction? {
        directions.first { $0.id == directionID }
    }

    private var defaultDirection: Direction? {
        DefaultDirections.existingTaskInbox(in: directions) ?? directions.first
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && defaultDirection != nil
    }

    private var measurementTitle: String {
        measurement == .checkbox ? measurement.displayName : targetText
    }

    private var measurementSymbol: String {
        switch measurement {
        case .checkbox: "checkmark.square"
        case .focusBlocks: "circle"
        case .minutes: "timer"
        }
    }

    private var targetText: String {
        switch measurement {
        case .checkbox: measurement.displayName
        case .focusBlocks: "\(plannedAmount) \(String(localized: "ブロック"))"
        case .minutes: "\(plannedAmount) \(String(localized: "分"))"
        }
    }

    private func submit() {
        let parserDirections = directions.map { TaskQuickInputDirection(id: $0.id, name: $0.name) }
        let result = parser.parse(
            title,
            directions: parserDirections,
            anchorDate: .now,
            calendar: calendar
        )
        if let unresolved = result.unresolvedDirection {
            unresolvedDirection = unresolved
            return
        }

        let normalizedTitle = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty,
              let direction = directions.first(where: { $0.id == result.directionID ?? directionID })
                ?? defaultDirection else { return }

        let resolvedMeasurement = result.measurement ?? measurement
        let resolvedPlannedAmount = result.measurement == nil ? plannedAmount : result.plannedAmount ?? 1
        let todo = Todo(
            title: normalizedTitle,
            hashtags: result.hashtags,
            direction: direction,
            measurement: resolvedMeasurement,
            priority: result.priority ?? priority,
            isRoomIfPossible: result.isRoomIfPossible ?? false,
            plannedAmount: resolvedMeasurement == .checkbox ? nil : resolvedPlannedAmount,
            scheduledDate: resolvedDate(from: result.date)
        )
        modelContext.insert(todo)
        try? modelContext.save()

        title = ""
        measurement = .checkbox
        plannedAmount = 1
        priority = .medium
        dateOption = .today
        directionID = defaultDirection?.id
        isFocused = true
    }

    private func resolvedDate(from parsedDate: TaskQuickInputDate?) -> Date? {
        if let parsedDate {
            switch parsedDate {
            case .scheduled(let date): return date
            case .noDate: return nil
            }
        }

        switch dateOption {
        case .today:
            return calendar.startOfDay(for: .now)
        case .tomorrow:
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now))
        case .noDate:
            return nil
        }
    }
}

private enum IOSComposerDate: String, CaseIterable, Identifiable {
    case today
    case tomorrow
    case noDate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .today: String(localized: "今日")
        case .tomorrow: String(localized: "明日")
        case .noDate: String(localized: "日付なし")
        }
    }
}
