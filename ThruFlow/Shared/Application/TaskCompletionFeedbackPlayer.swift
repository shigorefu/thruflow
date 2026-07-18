import AVFoundation
import Foundation

@MainActor
final class TaskCompletionFeedbackPlayer {
    static let shared = TaskCompletionFeedbackPlayer()

    private var player: AVAudioPlayer?
    private var lastPlayedAtByTodoID: [UUID: Date] = [:]

    func play(for todoID: UUID, now: Date = .now) {
        if let lastPlayedAt = lastPlayedAtByTodoID[todoID],
           now.timeIntervalSince(lastPlayedAt) < 0.5 {
            return
        }
        lastPlayedAtByTodoID[todoID] = now

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
