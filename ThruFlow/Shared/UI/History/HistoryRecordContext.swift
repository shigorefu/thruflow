#if os(macOS) || os(iOS)
import SwiftData
import SwiftUI

enum HistoryRecordContext: Equatable {
    case flow
    case task
    case area

    init(_ mode: DayHistoryMode) {
        switch mode {
        case .calendar:
            self = .flow
        case .tasks:
            self = .task
        case .areas:
            self = .area
        }
    }

    var targetSectionTitle: String {
        switch self {
        case .flow, .task:
            String(localized: "対象タスク")
        case .area:
            String(localized: "分野")
        }
    }

    var targetPickerLabel: String {
        switch self {
        case .flow:
            String(localized: "タスク・習慣・方向を選択")
        case .task:
            String(localized: "タスクを選択")
        case .area:
            String(localized: "方向を選択")
        }
    }

    var emptyTargetTitle: String {
        switch self {
        case .flow:
            String(localized: "タスクなし")
        case .task:
            String(localized: "タスクを選択")
        case .area:
            String(localized: "方向を選択")
        }
    }
}

#endif
