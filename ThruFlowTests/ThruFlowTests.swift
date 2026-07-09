//
//  ThruFlowTests.swift
//  ThruFlowTests
//
//  Created by エドワード on 2026/07/08.
//

import Foundation
import Testing
@testable import ThruFlow

struct ThruFlowTests {

    @Test func directionDraftRequiresName() {
        let draft = DirectionDraft(name: "   ", type: .neutral)
        let errors = DirectionValidator().validate(draft)

        #expect(errors == [.emptyName])
    }

    @Test func directionDraftNormalizesSymbolToFirstEmojiCharacter() {
        let draft = DirectionDraft(symbolName: "📚🎯")

        #expect(draft.normalizedSymbolName == "📚")
    }

    @Test func directionDraftRejectsPlainTextSymbol() {
        let draft = DirectionDraft(symbolName: "book")

        #expect(draft.normalizedSymbolName == "🎯")
    }

    @Test func emojiValidationSupportsJoinedEmojiAndSkinTone() {
        #expect(EmojiValidation.normalizedSingleEmoji(from: "🧑🏽‍💻") == "🧑🏽‍💻")
        #expect(EmojiValidation.normalizedSingleEmoji(from: "👍🏽") == "👍🏽")
    }

    @Test func enabledGoalRequiresPositiveTargetPeriodAndUnit() {
        let draft = DirectionDraft(
            name: "Training",
            type: .habit,
            goalEnabled: true,
            goalTarget: 0,
            goalPeriod: nil,
            goalUnit: nil,
            goalSchedule: nil
        )

        let errors = DirectionValidator().validate(draft)

        #expect(errors == [.invalidGoalTarget, .missingGoalUnit, .missingGoalSchedule])
    }

    @Test func disabledGoalAllowsMissingGoalFields() {
        let draft = DirectionDraft(
            name: "Work",
            type: .neutral,
            goalEnabled: false,
            goalTarget: nil,
            goalPeriod: nil,
            goalUnit: nil
        )

        let errors = DirectionValidator().validate(draft)

        #expect(errors.isEmpty)
    }

    @Test func weekdayGoalRequiresSelectedWeekdays() {
        let draft = DirectionDraft(
            name: "Training",
            type: .habit,
            goalTarget: 1,
            goalUnit: .focusBlocks,
            goalSchedule: .weekdays,
            weekdayMask: nil
        )

        let errors = DirectionValidator().validate(draft)

        #expect(errors == [.missingWeekdays])
    }

    @Test func directionArchivesWithoutChangingStableIdentifier() {
        let id = UUID()
        let now = Date(timeIntervalSince1970: 100)
        let direction = Direction(
            id: id,
            name: "Reading",
            type: .habit,
            createdAt: now,
            updatedAt: now
        )

        let archivedAt = Date(timeIntervalSince1970: 200)
        direction.archive(now: archivedAt)

        #expect(direction.id == id)
        #expect(direction.isArchived)
        #expect(direction.archivedAt == archivedAt)
        #expect(direction.updatedAt == archivedAt)
    }

    @Test func directionUpdateNormalizesGoalRawValues() {
        let direction = Direction(name: "Japanese", type: .nice)

        direction.update(
            name: "Japanese",
            type: .habit,
            symbolName: "character.book.closed",
            colorHex: "#10B981",
            goalTarget: 5,
            goalPeriod: .weekly,
            goalUnit: .hours,
            goalSchedule: .weeklyCount,
            weeklyTargetCount: 3,
            now: Date(timeIntervalSince1970: 300)
        )

        #expect(direction.typeRawValue == "habit")
        #expect(direction.goalPeriodRawValue == "weekly")
        #expect(direction.goalUnitRawValue == "hours")
        #expect(direction.goalScheduleRawValue == "weeklyCount")
        #expect(direction.weeklyTargetCount == 3)
        #expect(direction.hasGoal)
    }

    @Test func directionTypeReadsLegacyRawValues() {
        let habit = Direction(name: "Anki", type: .neutral)
        habit.typeRawValue = "must"

        let nice = Direction(name: "散歩", type: .neutral)
        nice.typeRawValue = "bonus"

        #expect(habit.type == .habit)
        #expect(nice.type == .nice)
    }

}
