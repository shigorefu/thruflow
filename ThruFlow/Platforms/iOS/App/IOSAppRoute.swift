#if os(iOS)
import SwiftUI

enum IOSAppRoute: Hashable, CaseIterable, Identifiable {
    case flow
    case tasks
    case history
    case areas
    case statistics
    case connectors
    case settings

    var id: String { String(describing: self) }

    var title: String {
        switch self {
        case .flow: String(localized: "Flow")
        case .tasks: String(localized: "タスク")
        case .history: String(localized: "履歴")
        case .areas: String(localized: "方向")
        case .statistics: String(localized: "統計")
        case .connectors: String(localized: "コネクタ")
        case .settings: String(localized: "設定")
        }
    }

    var systemImage: String {
        switch self {
        case .flow: "waveform.path"
        case .tasks: "checklist"
        case .history: "clock.arrow.circlepath"
        case .areas: ProductSymbol.area
        case .statistics: "chart.bar.xaxis"
        case .connectors: "puzzlepiece.extension"
        case .settings: "gearshape"
        }
    }

    static var tabs: [IOSAppRoute] {
        [.flow, .tasks, .history, .areas, .statistics]
    }
}
#endif
