#if os(iOS)
import SwiftUI

struct IOSTaskHabitStructureSection: View {
    let todo: Todo

    var body: some View {
        Section {
            LabeledContent(String(localized: "分野")) {
                Text("\(todo.area?.symbolName ?? "📝") \(TodoDisplay.flowContextName(for: todo))")
            }

            LabeledContent(String(localized: "種類"), value: todo.measurement.displayName)

            if todo.measurement != .checkbox {
                LabeledContent(String(localized: "目標")) {
                    Text(habitTargetText(todo))
                        .monospacedDigit()
                }
            }

            LabeledContent(String(localized: "優先度"), value: todo.priority.displayName)

            if todo.priority == .low, todo.isRoomIfPossible {
                LabeledContent(String(localized: "余裕があれば")) {
                    Image(systemName: "checkmark")
                }
            }

            LabeledContent(String(localized: "日付")) {
                if let date = todo.scheduledDate {
                    Text(date, format: .dateTime.year().month().day())
                } else {
                    Text(String(localized: "日付なし"))
                }
            }

            if let deadline = todo.deadline {
                LabeledContent(String(localized: "期限")) {
                    Text(deadline, format: .dateTime.year().month().day())
                }
            }
        }
    }

    private func habitTargetText(_ todo: Todo) -> String {
        let amount = todo.plannedAmount ?? 1
        switch todo.measurement {
        case .checkbox:
            return ""
        case .focusBlocks:
            return "\(amount) \(String(localized: "ブロック"))"
        case .minutes:
            return "\(amount) \(String(localized: "分"))"
        }
    }
}
#endif
