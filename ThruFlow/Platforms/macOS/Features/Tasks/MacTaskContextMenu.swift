#if os(macOS)
import SwiftData
import SwiftUI

/// The same task actions in the Tasks workspace and the Flow dashboard.
struct MacTaskContextMenu: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore
    @Query private var todos: [Todo]

    let todo: Todo
    let onEdit: () -> Void
    let onError: (String) -> Void

    var body: some View {
        Button(String(localized: "編集"), systemImage: "pencil", action: onEdit)
        if !todo.isCompleted {
            if todo.taskType == .habit {
                if todo.area?.goalSchedule == .weeklyCount {
                    Menu(String(localized: "移動")) {
                        ForEach(RequiredTodoPlanner(calendar: calendar).weeklyRescheduleOptions(for: todo, in: todos), id: \.date) { option in
                            Button(dateLabel(option.date)) { move(to: option.date) }
                                .disabled(!option.isAllowed)
                                .help(option.isAllowed ? "" : String(localized: "週間目標を達成できなくなるため移動できません"))
                        }
                    }
                }
            } else {
                Menu(String(localized: "移動")) {
                    Button(String(localized: "今日")) { move(to: .now) }
                    Button(String(localized: "明日")) { move(to: calendar.date(byAdding: .day, value: 1, to: .now)) }
                    Button(String(localized: "日付なし")) { move(to: nil) }
                }
            }
        }
        Divider()
        Button(String(localized: "Flowを開始"), systemImage: "play.fill") {
            activeFlowStore.configure(area: todo.area, todo: todo)
        }
        Divider()
        Button(String(localized: "削除"), systemImage: "trash", role: .destructive) {
            todo.softDelete()
            _ = modelContext.saveReporting(.taskUpdate)
        }
    }

    private func move(to date: Date?) {
        if let date {
            let service = TaskRescheduleService(calendar: calendar, dayBoundary: dayBoundary)
            switch service.validate(todo, movingTo: date, among: todos) {
            case .success:
                todo.reschedule(to: calendar.startOfDay(for: date))
                todo.setSortIndex((todos.map(\.sortIndex).min() ?? 0) - 1)
            case .failure(let failure):
                onError(failure.message)
                return
            }
        } else {
            guard !todo.isCompleted, todo.taskType != .habit else { return }
            todo.reschedule(to: nil)
        }
        do { try modelContext.save() }
        catch {
            modelContext.rollback()
            onError(String(localized: "タスクを移動できませんでした。"))
        }
    }

    private func dateLabel(_ date: Date) -> String {
        if calendar.isDateInToday(date) { return String(localized: "今日") }
        if calendar.isDateInTomorrow(date) { return String(localized: "明日") }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MdE")
        return formatter.string(from: date)
    }
}
#endif
