#if os(iOS)
import AppIntents
import Foundation

@MainActor
final class FlowLiveActivityControl: @unchecked Sendable {
    typealias Action = @MainActor @Sendable () -> Void

    private let togglePauseAction: Action
    private let finishAction: Action

    init(togglePause: @escaping Action, finish: @escaping Action) {
        togglePauseAction = togglePause
        finishAction = finish
    }

    func togglePause() {
        togglePauseAction()
    }

    func finish() {
        finishAction()
    }
}

struct ToggleFlowPauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "一時停止・再開"
    static var description = IntentDescription("Flowの一時停止と再開を切り替えます。")

    @Dependency private var control: FlowLiveActivityControl

    @MainActor
    func perform() async throws -> some IntentResult {
        control.togglePause()
        return .result()
    }
}

struct FinishFlowIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Flowを終了"
    static var description = IntentDescription("現在のFlowをメモなしで終了します。")

    @Dependency private var control: FlowLiveActivityControl

    @MainActor
    func perform() async throws -> some IntentResult {
        control.finish()
        return .result()
    }
}
#endif
