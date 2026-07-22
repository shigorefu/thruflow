import Foundation

enum DayHistoryMode: String, CaseIterable, Identifiable {
    case calendar
    case tasks
    case directions

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .calendar: String(localized: "Flow")
        case .tasks: String(localized: "タスク")
        case .directions: String(localized: "方向")
        }
    }
}
