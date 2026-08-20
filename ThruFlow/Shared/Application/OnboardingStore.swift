import Combine
import Foundation

@MainActor
final class OnboardingStore: ObservableObject {
    @Published private(set) var isPresented: Bool
    @Published private(set) var step: OnboardingStep
    @Published private(set) var launchKind: OnboardingLaunchKind
    @Published private(set) var experience: OnboardingExperience
    @Published private(set) var presentation: OnboardingPresentation?
    @Published private(set) var createdAreaID: UUID?
    @Published private(set) var createdTaskID: UUID?
    @Published private(set) var createdTaskPresentation: OnboardingTaskPresentation?
    @Published private(set) var demoState: OnboardingDemoState = .idle

    let isPreviewMode: Bool

    private let defaults: UserDefaults
    private var hasPendingExistingWorkspace = false

    init(
        defaults: UserDefaults = .standard,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        self.defaults = defaults

        let isPreviewMode = arguments.contains("--onboarding-preview")
        self.isPreviewMode = isPreviewMode
        launchKind = isPreviewMode ? .preview : .firstRun
        experience = isPreviewMode
            ? Self.previewExperience(in: arguments) ?? .guided
            : .undecided
        isPresented = isPreviewMode || !defaults.bool(forKey: Keys.didComplete)
        step = isPreviewMode ? Self.previewStep(in: arguments) ?? .welcome : .welcome
        presentation = nil
        createdAreaID = nil
        createdTaskID = nil
        createdTaskPresentation = nil
    }

    var canOfferAreaCreation: Bool {
        isPresented &&
            experience == .guided &&
            step == .areas &&
            presentation == nil &&
            createdAreaID == nil
    }

    var canOfferTaskCreation: Bool {
        isPresented &&
            experience == .guided &&
            step == .tasks &&
            presentation == nil &&
            createdAreaID != nil &&
            createdTaskID == nil
    }

    var canAdvance: Bool {
        guard isPresented else { return false }

        switch (experience, step) {
        case (.undecided, _):
            return false
        case (.guided, .areas):
            return createdAreaID != nil
        case (.guided, .tasks):
            return createdTaskID != nil
        default:
            return true
        }
    }

    /// Resolves a first-run journey after the real workspace becomes available.
    /// Repeating the guide is always read-only, while an empty first-run or
    /// preview workspace may offer user-confirmed Area and Task creation.
    func resolveWorkspace(hasUserContent: Bool) {
        guard isPresented, launchKind != .replay else { return }
        guard experience != .tour else { return }

        if hasUserContent {
            if presentation == nil {
                experience = .tour
                hasPendingExistingWorkspace = false
            } else {
                // CloudKit can import an existing workspace after a creation
                // sheet has already opened. Keep the user's draft intact and
                // switch to the read-only tour after they save or dismiss it.
                hasPendingExistingWorkspace = true
            }
        } else if presentation == nil, experience == .undecided {
            experience = .guided
        }
    }

    /// Compatibility entry point for existing Settings call sites. A manually
    /// requested journey is a read-only replay and never offers sample creation.
    func present() {
        presentReplay()
    }

    func presentReplay() {
        launchKind = isPreviewMode ? .preview : .replay
        experience = .tour
        step = .welcome
        presentation = nil
        createdAreaID = nil
        createdTaskID = nil
        createdTaskPresentation = nil
        hasPendingExistingWorkspace = false
        demoState = .idle
        isPresented = true
    }

    @discardableResult
    func requestAreaCreation() -> Bool {
        guard canOfferAreaCreation else { return false }
        presentation = .areaEditor
        return true
    }

    @discardableResult
    func requestTaskCreation() -> Bool {
        guard canOfferTaskCreation else { return false }
        presentation = .taskComposer
        return true
    }

    func dismissPresentation() {
        presentation = nil
        if hasPendingExistingWorkspace {
            hasPendingExistingWorkspace = false
            experience = .tour
        }
    }

    @discardableResult
    func recordArea(id: UUID) -> Bool {
        guard isPresented, experience == .guided, step == .areas else { return false }
        createdAreaID = id
        presentation = nil
        step = .tasks
        if hasPendingExistingWorkspace {
            hasPendingExistingWorkspace = false
            experience = .tour
        }
        return true
    }

    @discardableResult
    func recordTask(id: UUID, presentation: OnboardingTaskPresentation) -> Bool {
        guard isPresented,
              experience == .guided,
              step == .tasks,
              createdAreaID != nil else {
            return false
        }

        createdTaskID = id
        createdTaskPresentation = presentation
        self.presentation = nil
        step = .flow
        if hasPendingExistingWorkspace {
            hasPendingExistingWorkspace = false
            experience = .tour
        }
        return true
    }

    func advance() {
        guard canAdvance else { return }
        guard let next = step.next else {
            complete()
            return
        }

        leaveCurrentStep()
        step = next
    }

    func goBack() {
        guard isPresented, let previous = step.previous else { return }
        leaveCurrentStep()
        step = previous
    }

    func skip() {
        complete()
    }

    func complete() {
        if !isPreviewMode {
            defaults.set(true, forKey: Keys.didComplete)
        }

        presentation = nil
        hasPendingExistingWorkspace = false
        demoState = .idle
        isPresented = false
    }

    @discardableResult
    func startDemo(
        at date: Date = .now,
        duration: TimeInterval = OnboardingDemoState.defaultDuration
    ) -> Bool {
        guard isPresented, step == .demo else { return false }
        demoState = .running(
            startedAt: date,
            duration: max(duration, OnboardingDemoState.minimumDuration)
        )
        return true
    }

    func updateDemo(at date: Date = .now) {
        guard case .running(let startedAt, let duration) = demoState else { return }
        guard date.timeIntervalSince(startedAt) >= duration else { return }
        demoState = .completed
    }

    func finishDemo() {
        guard isPresented, step == .demo else { return }
        demoState = .completed
    }

    func cancelDemo() {
        demoState = .idle
    }

    func demoProgress(at date: Date = .now) -> Double {
        demoState.progress(at: date)
    }

    var demoTaskPresentation: OnboardingTaskPresentation {
        createdTaskPresentation ?? .sample
    }

    private func leaveCurrentStep() {
        presentation = nil
        hasPendingExistingWorkspace = false
        if step == .demo {
            demoState = .idle
        }
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

    private static func previewExperience(in arguments: [String]) -> OnboardingExperience? {
        let prefix = "--onboarding-experience="
        guard let argument = arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }
        return OnboardingExperience(rawValue: String(argument.dropFirst(prefix.count)))
    }
}

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

enum OnboardingDemoState: Equatable, Sendable {
    nonisolated static let defaultDuration: TimeInterval = OnboardingDemoProjection.totalDuration
    nonisolated static let minimumDuration: TimeInterval = 0.1

    case idle
    case running(startedAt: Date, duration: TimeInterval)
    case completed

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var isCompleted: Bool {
        self == .completed
    }

    func progress(at date: Date) -> Double {
        switch self {
        case .idle:
            0
        case .running(let startedAt, let duration):
            min(max(date.timeIntervalSince(startedAt) / max(duration, Self.minimumDuration), 0), 1)
        case .completed:
            1
        }
    }

    func projection(at date: Date) -> OnboardingDemoProjection {
        OnboardingDemoProjection(elapsed: progress(at: date) * OnboardingDemoProjection.totalDuration)
    }
}

enum OnboardingDemoPhase: Equatable, Sendable {
    case idle
    case focusing
    case breakTime
}

enum OnboardingDemoStage: Equatable, Sendable {
    case awaitingTask
    case pressingContext
    case ready
    case pressingPlay
    case focusing
    case pressingBreak
    case breakTime
}

struct OnboardingDemoProjection: Equatable, Sendable {
    nonisolated static let totalDuration: TimeInterval = 8
    nonisolated static let contextPressStart: TimeInterval = 0.35
    nonisolated static let contextSelectedAt: TimeInterval = 0.65
    nonisolated static let playPressStart: TimeInterval = 1.35
    nonisolated static let focusStart: TimeInterval = 1.65
    nonisolated static let focusEnd: TimeInterval = 5.45
    nonisolated static let breakTransition: TimeInterval = 5.65
    nonisolated static let focusDurationSeconds = FlowMode.sprint.initialFocusDurationSeconds
    nonisolated static let breakDurationSeconds = FlowMode.sprint.breakDurationSeconds

    let stage: OnboardingDemoStage
    let phase: OnboardingDemoPhase
    let remainingSeconds: Int
    let timerProgress: Double

    init(elapsed rawElapsed: TimeInterval) {
        let elapsed = min(max(rawElapsed, 0), Self.totalDuration)

        switch elapsed {
        case ..<Self.contextPressStart:
            stage = .awaitingTask
            phase = .idle
            remainingSeconds = Self.focusDurationSeconds
            timerProgress = 0
        case ..<Self.contextSelectedAt:
            stage = .pressingContext
            phase = .idle
            remainingSeconds = Self.focusDurationSeconds
            timerProgress = 0
        case ..<Self.playPressStart:
            stage = .ready
            phase = .idle
            remainingSeconds = Self.focusDurationSeconds
            timerProgress = 0
        case ..<Self.focusStart:
            stage = .pressingPlay
            phase = .idle
            remainingSeconds = Self.focusDurationSeconds
            timerProgress = 0
        case ..<Self.focusEnd:
            let focusProgress = min(max(
                (elapsed - Self.focusStart) / (Self.focusEnd - Self.focusStart),
                0
            ), 1)
            stage = .focusing
            phase = .focusing
            remainingSeconds = Int(ceil(Double(Self.focusDurationSeconds) * (1 - focusProgress)))
            timerProgress = focusProgress
        case ..<Self.breakTransition:
            stage = .pressingBreak
            phase = .focusing
            remainingSeconds = 0
            timerProgress = 1
        default:
            stage = .breakTime
            phase = .breakTime
            remainingSeconds = Self.breakDurationSeconds
            timerProgress = 1
        }
    }

    var contextIsSelected: Bool {
        switch stage {
        case .awaitingTask, .pressingContext: false
        default: true
        }
    }

    var contextIsPressed: Bool {
        stage == .pressingContext
    }

    var primaryIsPressed: Bool {
        stage == .pressingPlay || stage == .pressingBreak
    }

    var canSeek: Bool {
        stage == .focusing || stage == .pressingBreak
    }

    var hasActiveTimer: Bool {
        switch stage {
        case .focusing, .pressingBreak, .breakTime: true
        default: false
        }
    }

    var canStartBreak: Bool {
        stage == .focusing || stage == .pressingBreak
    }
}

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
            .directions
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
    case directions
    case tasks
    case history
    case statistics
}
