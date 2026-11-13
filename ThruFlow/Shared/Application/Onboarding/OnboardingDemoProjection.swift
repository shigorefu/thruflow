import Foundation

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
