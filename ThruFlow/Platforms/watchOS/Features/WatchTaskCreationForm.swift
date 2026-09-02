import SwiftData
import SwiftUI

struct WatchTaskCreationForm: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Area.sortIndex) private var areas: [Area]
    @Query private var todos: [Todo]

    @State private var areaID: UUID?
    @State private var measurement = TodoMeasurement.checkbox
    @State private var plannedAmount = 1
    @State private var priority = TodoPriority.medium
    @State private var schedule = WatchTaskSchedule.today

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(String(localized: "分野"), selection: $areaID) {
                        ForEach(activeAreas) { area in
                            Label {
                                Text(area.name)
                            } icon: {
                                Text(area.symbolName)
                            }
                            .tag(Optional(area.id))
                        }
                    }

                    Picker(String(localized: "種類"), selection: $measurement) {
                        ForEach(TodoMeasurement.allCases) { value in
                            Text(value.displayName)
                                .tag(value)
                        }
                    }

                    if measurement != .checkbox {
                        Stepper(
                            value: $plannedAmount,
                            in: amountRange,
                            step: amountStep
                        ) {
                            LabeledContent(
                                String(localized: "目標値"),
                                value: amountText
                            )
                        }
                    }
                }

                Section {
                    Picker(String(localized: "優先度"), selection: $priority) {
                        ForEach(TodoPriority.allCases) { value in
                            Text(value.displayName)
                                .tag(value)
                        }
                    }

                    Picker(String(localized: "予定日"), selection: $schedule) {
                        ForEach(WatchTaskSchedule.allCases) { value in
                            Text(value.displayName)
                                .tag(value)
                        }
                    }
                }

                Button {
                    save()
                } label: {
                    Label(String(localized: "タスクを追加"), systemImage: "plus.circle.fill")
                }
                .disabled(selectedArea == nil)
            }
            .navigationTitle(String(localized: "タスクを追加"))
            .task {
                guard areaID == nil else { return }
                areaID = (
                    DefaultAreas.existingTaskInbox(in: activeAreas)
                        ?? activeAreas.first
                )?.id
            }
        }
    }

    private var activeAreas: [Area] {
        areas.filter { !$0.isArchived }
    }

    private var selectedArea: Area? {
        activeAreas.first { $0.id == areaID }
    }

    private var amountRange: ClosedRange<Int> {
        measurement == .minutes ? 5...240 : 1...20
    }

    private var amountStep: Int {
        measurement == .minutes ? 5 : 1
    }

    private var amountText: String {
        switch measurement {
        case .checkbox:
            return ""
        case .focusBlocks:
            return "\(plannedAmount) \(String(localized: "ブロック"))"
        case .minutes:
            return "\(plannedAmount) \(String(localized: "分"))"
        }
    }

    private func save() {
        guard let area = selectedArea else { return }

        let todo = Todo(
            title: "",
            area: area,
            measurement: measurement,
            priority: priority,
            plannedAmount: measurement == .checkbox ? nil : plannedAmount,
            scheduledDate: schedule.date(
                calendar: calendar,
                dayBoundary: dayBoundary
            ),
            sortIndex: (todos.map(\.sortIndex).max() ?? -1) + 1
        )
        modelContext.insert(todo)
        _ = modelContext.saveReporting(.taskUpdate)
        dismiss()
    }
}

private enum WatchTaskSchedule: String, CaseIterable, Identifiable {
    case today
    case tomorrow
    case noDate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .today:
            String(localized: "今日")
        case .tomorrow:
            String(localized: "明日")
        case .noDate:
            String(localized: "日付なし")
        }
    }

    func date(
        calendar: Calendar,
        dayBoundary: AppDayBoundary
    ) -> Date? {
        let today = dayBoundary.day(containing: .now, calendar: calendar)
        return switch self {
        case .today:
            today
        case .tomorrow:
            calendar.date(
                byAdding: .day,
                value: 1,
                to: today
            )
        case .noDate:
            nil
        }
    }
}
