import Combine
import Foundation

@MainActor
final class OnboardingStore: ObservableObject {
    @Published private(set) var isPresented: Bool
    @Published private(set) var step: OnboardingStep

    let isPreviewMode: Bool

    private let defaults: UserDefaults

    init(
        defaults: UserDefaults = .standard,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        self.defaults = defaults
        isPreviewMode = arguments.contains("--onboarding-preview")
        isPresented = isPreviewMode || !defaults.bool(forKey: Keys.didComplete)
        step = isPreviewMode ? Self.previewStep(in: arguments) ?? .welcome : .welcome
    }

    func present() {
        step = .welcome
        isPresented = true
    }

    func advance() {
        guard let next = step.next else {
            complete()
            return
        }
        step = next
    }

    func goBack() {
        guard let previous = step.previous else { return }
        step = previous
    }

    func complete() {
        if !isPreviewMode {
            defaults.set(true, forKey: Keys.didComplete)
        }
        isPresented = false
    }

    private enum Keys {
        static let didComplete = "onboarding.didComplete.v1"
    }

    private static func previewStep(in arguments: [String]) -> OnboardingStep? {
        let prefix = "--onboarding-step="
        guard let argument = arguments.first(where: { $0.hasPrefix(prefix) }),
              let rawValue = Int(argument.dropFirst(prefix.count)) else {
            return nil
        }
        return OnboardingStep(rawValue: rawValue)
    }
}

enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome
    case flow
    case directions
    case tasks
    case history
    case statistics
    case workflow

    var next: OnboardingStep? {
        Self(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        Self(rawValue: rawValue - 1)
    }

    var screen: OnboardingScreen {
        switch self {
        case .welcome, .flow, .workflow: .flow
        case .directions: .directions
        case .tasks: .tasks
        case .history: .history
        case .statistics: .statistics
        }
    }

    var isFinal: Bool {
        self == .workflow
    }
}

enum OnboardingScreen: Sendable {
    case flow
    case directions
    case tasks
    case history
    case statistics
}
