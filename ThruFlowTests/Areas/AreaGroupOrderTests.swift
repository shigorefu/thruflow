import Testing
@testable import ThruFlow

struct AreaGroupOrderTests {
    @Test func defaultsToNormalHabitNice() {
        #expect(AreaGroupOrder.decode("") == [.neutral, .habit, .nice])
    }

    @Test func restoresValidUniqueValuesAndAppendsMissingTypes() {
        #expect(
            AreaGroupOrder.decode("nice,nice,habit,unknown") == [.nice, .habit, .neutral]
        )
    }

    @Test func movesAColumnForwardAndBackward() {
        let initial: [AreaType] = [.neutral, .habit, .nice]

        let movedForward = AreaGroupOrder.moving(.neutral, relativeTo: .nice, in: initial)
        #expect(movedForward == [.habit, .nice, .neutral])

        let movedBackward = AreaGroupOrder.moving(.neutral, relativeTo: .habit, in: movedForward)
        #expect(movedBackward == [.neutral, .habit, .nice])
    }

    @Test func encodingNormalizesIncompleteOrder() {
        #expect(AreaGroupOrder.encode([.nice]) == "nice,neutral,habit")
    }
}
