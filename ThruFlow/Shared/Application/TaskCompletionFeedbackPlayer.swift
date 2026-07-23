import AVFoundation
import Foundation
#if os(iOS)
import UIKit
#endif

@MainActor
final class TaskCompletionFeedbackPlayer {
    static let shared = TaskCompletionFeedbackPlayer()

    private var player: AVAudioPlayer?
    private var lastPlayedAtByTodoID: [UUID: Date] = [:]
    private var lastPlayedAtByFlowID: [UUID: Date] = [:]
#if os(iOS)
    private let completionHaptic = UINotificationFeedbackGenerator()
#endif

    func play(for todoID: UUID, now: Date = .now) {
        guard register(todoID, in: &lastPlayedAtByTodoID, now: now) else { return }

        playSuccessHaptic()
        playCompletionSound()
    }

    func playFlow(for flowID: UUID, now: Date = .now) {
        guard register(flowID, in: &lastPlayedAtByFlowID, now: now) else { return }
        playSuccessHaptic()
    }

    private func register(_ id: UUID, in history: inout [UUID: Date], now: Date) -> Bool {
        if let lastPlayedAt = history[id],
           now.timeIntervalSince(lastPlayedAt) < 0.5 {
            return false
        }
        history[id] = now
        return true
    }

    private func playSuccessHaptic() {
#if os(iOS)
        completionHaptic.prepare()
        completionHaptic.notificationOccurred(.success)
#endif
    }

    private func playCompletionSound() {
        let url = Bundle.main.url(
            forResource: "task-complete",
            withExtension: "caf",
            subdirectory: "Sounds"
        ) ?? Bundle.main.url(
            forResource: "task-complete",
            withExtension: "caf"
        )

        guard let url else {
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            self.player = player
        } catch {
            assertionFailure("Could not play task completion sound: \(error)")
        }
    }
}
