import Foundation
import Testing
@testable import ThruFlow

struct TaskQuickInputParserTests {
    private let parser = TaskQuickInputParser()
    private let awsID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    @Test func parsesCombinedEnglishInput() {
        let result = parser.parse(
            "[] Prepare materials @AWS !high /today #E3",
            directions: [.init(id: awsID, name: "AWS")],
            anchorDate: referenceDate
        )

        #expect(result.title == "Prepare materials")
        #expect(result.measurement == .checkbox)
        #expect(result.directionID == awsID)
        #expect(result.priority == .high)
        #expect(result.isRoomIfPossible == false)
        #expect(result.date == .scheduled(Calendar.current.startOfDay(for: referenceDate)))
        #expect(result.hashtags == ["E3"])
    }

    @Test func parsesLocalizedMeasurements() {
        #expect(parser.parse("[2b] VPC").measurement == .focusBlocks)
        #expect(parser.parse("[2блока] VPC").plannedAmount == 2)
        #expect(parser.parse("[2ブロック] VPC").measurement == .focusBlocks)
        #expect(parser.parse("[30m] Read").measurement == .minutes)
        #expect(parser.parse("[30мин] Читать").plannedAmount == 30)
        #expect(parser.parse("[30分] 読書").measurement == .minutes)
    }

    @Test func parsesEnglishJapaneseAndRussianPriorities() {
        #expect(parser.parse("Task !later").isRoomIfPossible == true)
        #expect(parser.parse("Task !余裕").isRoomIfPossible == true)
        #expect(parser.parse("Task !потом").isRoomIfPossible == true)
        #expect(parser.parse("Task !h").priority == .high)
        #expect(parser.parse("Task !中").priority == .medium)
        #expect(parser.parse("Task !н").priority == .low)
    }

    @Test func parsesEnglishJapaneseAndRussianDates() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 7, day: 18))!

        #expect(parser.parse("Task /tomorrow", anchorDate: anchor, calendar: calendar).date == .scheduled(calendar.date(byAdding: .day, value: 1, to: anchor)!))
        #expect(parser.parse("Task /月", anchorDate: anchor, calendar: calendar).date == .scheduled(calendar.date(from: DateComponents(year: 2026, month: 7, day: 20))!))
        #expect(parser.parse("Task /пт", anchorDate: anchor, calendar: calendar).date == .scheduled(calendar.date(from: DateComponents(year: 2026, month: 7, day: 24))!))
        #expect(parser.parse("Task /2026-07-20", anchorDate: anchor, calendar: calendar).date == .scheduled(calendar.date(from: DateComponents(year: 2026, month: 7, day: 20))!))
        #expect(parser.parse("Task /без-даты", anchorDate: anchor, calendar: calendar).date == .noDate)
    }

    @Test func keepsUnknownTokensInTitle() {
        let result = parser.parse("[abc] Study @AWX", directions: [.init(id: awsID, name: "AWS")])

        #expect(result.title == "[abc] Study @AWX")
        #expect(result.measurement == nil)
        #expect(result.unresolvedDirection == "AWX")
    }

    @Test func deduplicatesHashtagsCaseInsensitivelyAndPreservesFirstSpelling() {
        let result = parser.parse("Task #AWS #aws #Aws #E3")

        #expect(result.title == "Task")
        #expect(result.hashtags == ["AWS", "E3"])
        #expect(TodoHashtagNormalizer.normalize(["#AWS", "aws", "Aws"]) == ["AWS"])
        #expect(TodoHashtagCodec.decode(TodoHashtagCodec.encode(["#AWS", "aws", "E3"])) == ["AWS", "E3"])
    }

    @Test func englishAliasesRemainUniversalAlongsideLocalizedAliases() {
        let english = parser.parse("[2b] Task !high /tomorrow #AWS")
        let japanese = parser.parse("[2ブロック] タスク !高 /明日 #AWS")
        let russian = parser.parse("[2блока] Задача !высокий /завтра #AWS")

        for result in [english, japanese, russian] {
            #expect(result.measurement == .focusBlocks)
            #expect(result.plannedAmount == 2)
            #expect(result.priority == .high)
            #expect(result.hashtags == ["AWS"])
        }
    }

    @Test func leavesUnfinishedTrailingTokenForHighlighting() {
        let result = parser.parse("Prepare !high", consumeTrailingToken: false)

        #expect(result.title == "Prepare !high")
        #expect(result.priority == nil)
        #expect(result.tokens.last?.kind == .priority(.high, isRoomIfPossible: false))
    }

    @Test func commitsTokenAfterDelimiterForInlineChipPresentation() {
        let result = parser.parse("[] Prepare ", consumeTrailingToken: false)

        #expect(result.title == "Prepare")
        #expect(result.measurement == .checkbox)
        #expect(result.recognizedTokens.map(\.rawValue) == ["[]"])
    }

    private var referenceDate: Date {
        Date(timeIntervalSince1970: 1_768_579_200)
    }
}
