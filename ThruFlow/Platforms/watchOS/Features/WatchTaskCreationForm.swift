import SwiftData
import SwiftUI

struct WatchTaskCreationForm: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Area.sortIndex) private var areas: [Area]

    @State private var saveErrorMessage: String?
    @State private var areaID: UUID?
    @State private var project: Project?
    @State private var measurement = TodoMeasurement.checkbox
    @State private var plannedAmount = 1
    @State private var priority = TodoPriority.medium
    @State private var schedule = WatchTaskSchedule.today
    @State private var scheduledTimeMinutes: Int?
    @State private var reminderEnabled = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(String(localized: "分野"), selection: $areaID) {
                        Text(String(localized: "その他")).tag(nil as UUID?)
                        ForEach(activeAreas.filter { !DefaultAreas.isTaskInbox($0) }) { area in
                            Label {
                                Text(area.name)
                            } icon: {
                                Text(area.symbolName)
                            }
                            .tag(Optional(area.id))
                        }
                    }

                    TaskProjectPicker(area: selectedArea, selection: $project)

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

                Section {
                    TaskTimingControls(
                        scheduledDate: schedule.date(calendar: calendar, dayBoundary: dayBoundary),
                        timeMinutes: $scheduledTimeMinutes,
                        reminderEnabled: $reminderEnabled
                    )
                }

                Button {
                    save()
                } label: {
                    Label(String(localized: "タスクを追加"), systemImage: "plus.circle.fill")
                }

                if let saveErrorMessage {
                    Text(saveErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .taskTimingDefaults(timeMinutes: $scheduledTimeMinutes, reminderEnabled: $reminderEnabled)
            .navigationTitle(String(localized: "タスクを追加"))
            .onChange(of: areaID) { _, newValue in
                if project?.area?.id != newValue { project = nil }
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
        saveErrorMessage = nil
        let draft = TodoDraft(
            area: selectedArea,
            project: project,
            measurement: measurement,
            priority: priority,
            plannedAmount: measurement == .checkbox ? nil : plannedAmount,
            scheduledDate: schedule.date(calendar: calendar, dayBoundary: dayBoundary),
            scheduledTimeMinutes: scheduledTimeMinutes,
            reminderEnabled: reminderEnabled
        )
        do {
            _ = try TaskEditingService().save(draft: draft, modelContext: modelContext)
            if draft.scheduledTimeMinutes != nil && draft.reminderEnabled {
                TaskReminderAuthorization.requestForUserAction()
            }
            dismiss()
        } catch TaskEditingError.validation(let errors) {
            saveErrorMessage = errors.map(\.localizedDescription).joined(separator: "\n")
        } catch {
            saveErrorMessage = String(localized: "記録を保存できませんでした。")
        }
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
