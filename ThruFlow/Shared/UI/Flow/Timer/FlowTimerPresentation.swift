import SwiftUI

enum FlowTimerPanelStyle: Equatable {
    case mobile
    case dashboard

    var timerStyle: FlowTimerDial.Style {
        switch self {
        case .mobile: .mobile
        case .dashboard: .dashboard
        }
    }
}

struct FlowTimerPresentation {
    let progress: Double
    let tint: Color
    let eyebrow: String
    let timeText: String
    let footer: String
    var slices: [FlowTimerRingSlice] = []

    func dial(style: FlowTimerPanelStyle) -> FlowTimerDial {
        FlowTimerDial(progress: progress, tint: tint, eyebrow: eyebrow, timeText: timeText,
                      footer: footer, style: style.timerStyle, slices: slices)
    }
}
