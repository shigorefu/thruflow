import Foundation

enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome
    case areas
    case tasks
    case flow
    case timer
    case demo
    case history
    case statistics
    case workflow
    case privacy

    var next: OnboardingStep? {
        Self(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        Self(rawValue: rawValue - 1)
    }

    var screen: OnboardingScreen {
        switch self {
        case .welcome, .flow, .timer, .demo, .workflow, .privacy:
            .flow
        case .areas:
            .areas
        case .tasks:
            .tasks
        case .history:
            .history
        case .statistics:
            .statistics
        }
    }

    var isFinal: Bool {
        self == .privacy
    }
}

enum OnboardingScreen: Sendable {
    case flow
    case areas
    case tasks
    case history
    case statistics
}
