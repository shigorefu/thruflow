import Foundation
import Testing
@testable import ThruFlow

struct FlowPaletteTransitionTests {
    @Test func paletteChangesPreserveOldColorsUntilTheWaveFinishes() {
        let now = Date(timeIntervalSince1970: 100)
        var transition = FlowPaletteTransition()
        transition.receive(["blue"], at: now, animated: true)
        #expect(transition.startedAt == nil)
        transition.receive(["orange"], at: now, animated: true)
        #expect(transition.previous == ["blue"])
        #expect(transition.target == ["orange"])
        #expect(transition.progress(at: now) == 0)
        #expect(abs(transition.progress(at: now.addingTimeInterval(1.2)) - 0.5) < 0.0001)
        transition.advance(at: now.addingTimeInterval(3))
        #expect(transition.previous == ["orange"])
        #expect(transition.startedAt == nil)
    }

    @Test func rapidChangesQueueOnlyTheLatestPaletteWithoutRestartingTheWave() {
        let now = Date(timeIntervalSince1970: 100)
        var transition = FlowPaletteTransition()
        transition.receive(["blue"], at: now, animated: true)
        transition.receive(["orange"], at: now, animated: true)
        transition.receive(["green"], at: now.addingTimeInterval(0.5), animated: true)
        transition.receive(["purple"], at: now.addingTimeInterval(1), animated: true)
        #expect(transition.startedAt == now)
        #expect(transition.target == ["orange"])
        transition.advance(at: now.addingTimeInterval(3))
        #expect(transition.previous == ["orange"])
        #expect(transition.target == ["purple"])
        #expect(transition.pending == nil)
        transition.receive(["purple"], at: now.addingTimeInterval(4), animated: false)
        #expect(transition.previous == ["purple"])
        #expect(transition.startedAt == nil)
    }
}
