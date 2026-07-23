#if os(iOS)
import AppIntents
import Foundation

@MainActor
final class FlowLiveActivityControl: @unchecked Sendable {
    typealias Action = @MainActor @Sendable () -> Void

    private let seekBackwardAction: Action
    private let togglePauseAction: Action
    private let finishAction: Action
    private let seekForwardAction: Action

    init(
        seekBackward: @escaping Action,
        togglePause: @escaping Action,
        finish: @escaping Action,
        seekForward: @escaping Action
    ) {
        seekBackwardAction = seekBackward
        togglePauseAction = togglePause
        finishAction = finish
        seekForwardAction = seekForward
    }

    func seekBackward() {
        seekBackwardAction()
    }

    func togglePause() {
        togglePauseAction()
    }

    func finish() {
        finishAction()
    }

    func seekForward() {
        seekForwardAction()
    }
}

struct SeekFlowBackwardIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "残り時間を5分短縮"
    static var description = IntentDescription("集中の残り時間を5分短くします。")

    @Dependency private var control: FlowLiveActivityControl

    @MainActor
    func perform() async throws -> some IntentResult {
        control.seekBackward()
        return .result()
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

struct SeekFlowForwardIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "残り時間を5分延長"
    static var description = IntentDescription("集中の残り時間を5分長くします。")

    @Dependency private var control: FlowLiveActivityControl

    @MainActor
    func perform() async throws -> some IntentResult {
        control.seekForward()
        return .result()
    }
}
#endif
