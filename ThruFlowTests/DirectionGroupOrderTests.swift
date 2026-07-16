import Testing
@testable import ThruFlow

struct DirectionGroupOrderTests {
    @Test func defaultsToNormalHabitNice() {
        #expect(DirectionGroupOrder.decode("") == [.neutral, .habit, .nice])
    }

    @Test func restoresValidUniqueValuesAndAppendsMissingTypes() {
        #expect(
            DirectionGroupOrder.decode("nice,nice,habit,unknown") == [.nice, .habit, .neutral]
        )
    }

    @Test func movesAColumnForwardAndBackward() {
        let initial: [DirectionType] = [.neutral, .habit, .nice]

        let movedForward = DirectionGroupOrder.moving(.neutral, relativeTo: .nice, in: initial)
        #expect(movedForward == [.habit, .nice, .neutral])

        let movedBackward = DirectionGroupOrder.moving(.neutral, relativeTo: .habit, in: movedForward)
        #expect(movedBackward == [.neutral, .habit, .nice])
    }

    @Test func encodingNormalizesIncompleteOrder() {
        #expect(DirectionGroupOrder.encode([.nice]) == "nice,neutral,habit")
    }
}
