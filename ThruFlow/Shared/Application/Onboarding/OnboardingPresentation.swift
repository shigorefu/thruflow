import Foundation

enum OnboardingLaunchKind: String, Sendable {
    case firstRun
    case replay
    case preview
}

enum OnboardingExperience: String, Sendable {
    case undecided
    case guided
    case tour
}

enum OnboardingPresentation: String, Identifiable, Sendable {
    case areaEditor
    case taskComposer

    var id: String { rawValue }
}

struct OnboardingTaskPresentation: Equatable, Sendable {
    let title: String
    let areaName: String
    let areaSymbol: String
    let areaColorHex: String

    static var sample: OnboardingTaskPresentation {
        OnboardingTaskPresentation(
            title: String(localized: "レポートを仕上げる"),
            areaName: String(localized: "仕事"),
            areaSymbol: "💼",
            areaColorHex: "#007AFF"
        )
    }
}
