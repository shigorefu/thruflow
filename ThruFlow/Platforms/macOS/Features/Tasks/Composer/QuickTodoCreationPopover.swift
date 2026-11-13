#if os(macOS)
import SwiftData
import SwiftUI

struct QuickTodoCreationPopover: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.modelContext) private var modelContext

    let areas: [Area]
    let showsQuickInputLegend: Bool
    let suggestionsBelow: Bool
    let initialDraft: TodoDraft?
    let isPresented: Binding<Bool>?
    let onCreated: ((Todo) -> Void)?

    @State private var title = ""
    @State private var selectedAreaID: UUID?
    @State private var selectedProject: Project?
    @State private var volume: QuickTodoVolume = .unspecified
    @State private var priority: TodoPriority = .medium
    @State private var isRoomIfPossible = false
    @State private var dateOption: QuickTodoDate = .today
    @State private var timeMinutes: Int?
    @State private var reminderEnabled = false
    @State private var hashtags: [String] = []
    @State private var validationMessage: String?

    init(
        areas: [Area],
        scheduledDate: Date? = .now,
        showsQuickInputLegend: Bool = true,
        suggestionsBelow: Bool = false,
        initialDraft: TodoDraft? = nil,
        isPresented: Binding<Bool>? = nil,
        onCreated: ((Todo) -> Void)? = nil
    ) {
        self.areas = areas
        self.showsQuickInputLegend = showsQuickInputLegend
        self.suggestionsBelow = suggestionsBelow
        self.initialDraft = initialDraft
        self.isPresented = isPresented
        self.onCreated = onCreated

        let resolvedScheduledDate: Date?
        let initialVolume: QuickTodoVolume
        if let initialDraft {
            resolvedScheduledDate = initialDraft.scheduledDate
            switch initialDraft.measurement {
            case .checkbox:
                initialVolume = .checkbox
            case .focusBlocks:
                initialVolume = .blocks(max(1, initialDraft.plannedAmount ?? 1))
            case .minutes:
                initialVolume = .minutes(max(1, initialDraft.plannedAmount ?? 1))
            }
        } else {
            resolvedScheduledDate = scheduledDate
            initialVolume = .unspecified
        }

        _title = State(initialValue: initialDraft?.title ?? "")
        _selectedAreaID = State(initialValue: initialDraft?.area?.id)
        _selectedProject = State(initialValue: initialDraft?.project)
        _volume = State(initialValue: initialVolume)
        _priority = State(initialValue: initialDraft?.priority ?? .medium)
        _isRoomIfPossible = State(
            initialValue: initialDraft?.priority == .low && initialDraft?.isRoomIfPossible == true
        )
        _dateOption = State(
            initialValue: resolvedScheduledDate.map(QuickTodoDate.custom) ?? .none
        )
        _timeMinutes = State(initialValue: initialDraft?.scheduledTimeMinutes)
        _reminderEnabled = State(initialValue: initialDraft?.reminderEnabled ?? false)
        _hashtags = State(initialValue: initialDraft?.hashtags ?? [])
        _validationMessage = State(initialValue: nil)
    }

    private var activeAreas: [Area] {
        areas.filter { !$0.isArchived }
    }

    private var selectableAreas: [Area] {
        activeAreas.filter { !DefaultAreas.isTaskInbox($0) }
    }

    var body: some View {
        MessengerTodoComposer(
            title: $title,
            selectedAreaID: $selectedAreaID,
            selectedProject: $selectedProject,
            volume: $volume,
            priority: $priority,
            isRoomIfPossible: $isRoomIfPossible,
            dateOption: $dateOption,
            timeMinutes: $timeMinutes,
            reminderEnabled: $reminderEnabled,
            hashtags: $hashtags,
            areas: selectableAreas,
            validationMessage: validationMessage,
            allowsDateSelection: true,
            showsOuterBackground: false,
            suggestionsBelow: suggestionsBelow,
            allowsQuickInputLegend: showsQuickInputLegend,
            onCancel: closeComposer,
            onSubmit: createTodo
        )
        .frame(width: 520)
        .onExitCommand(perform: closeComposer)
    }

    private func closeComposer() {
        if let isPresented {
            isPresented.wrappedValue = false
        } else {
            dismiss()
        }
    }

    private func createTodo() -> Bool {
        validationMessage = nil
        let selectedArea = selectedAreaID.flatMap { id in
            selectableAreas.first { $0.id == id }
        }
        let draft = TodoDraft(
            title: title,
            notes: initialDraft?.notes ?? "",
            hashtags: hashtags,
            area: selectedArea,
            project: selectedProject,
            measurement: volume.measurement,
            priority: priority,
            isRoomIfPossible: priority == .low && isRoomIfPossible,
            plannedAmount: volume.plannedAmount,
            actualProgress: initialDraft?.actualProgress ?? 0,
            scheduledDate: dateOption.resolvedDate(calendar: calendar, dayBoundary: dayBoundary),
            scheduledTimeMinutes: timeMinutes,
            reminderEnabled: reminderEnabled,
            deadline: initialDraft?.deadline
        )
        do {
            let todo = try TaskEditingService().save(draft: draft, modelContext: modelContext)
            if todo.reminderEnabled { TaskReminderAuthorization.requestForUserAction() }
            onCreated?(todo)
            closeComposer()
            return true
        } catch TaskEditingError.validation(let errors) {
            validationMessage = errors.map(\.localizedDescription).joined(separator: "\n")
            return false
        } catch {
            validationMessage = String(localized: "記録を保存できませんでした。")
            return false
        }
    }
}
#endif
