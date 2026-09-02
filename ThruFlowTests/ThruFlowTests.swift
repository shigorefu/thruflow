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

    @Test func areaDraftRequiresName() {
        let draft = AreaDraft(name: "   ", type: .neutral)
        let errors = AreaValidator().validate(draft)

        #expect(errors == [.emptyName])
    }

    @Test func areaDraftNormalizesSymbolToFirstEmojiCharacter() {
        let draft = AreaDraft(symbolName: "📚🎯")

        #expect(draft.normalizedSymbolName == "📚")
    }

    @Test func areaDraftRejectsPlainTextSymbol() {
        let draft = AreaDraft(symbolName: "book")

        #expect(draft.normalizedSymbolName == "🎯")
    }

    @Test func emojiValidationSupportsJoinedEmojiAndSkinTone() {
        #expect(EmojiValidation.normalizedSingleEmoji(from: "🧑🏽‍💻") == "🧑🏽‍💻")
        #expect(EmojiValidation.normalizedSingleEmoji(from: "👍🏽") == "👍🏽")
    }

    @Test func enabledGoalRequiresPositiveTargetPeriodAndUnit() {
        let draft = AreaDraft(
            name: "Training",
            type: .habit,
            goalEnabled: true,
            goalTarget: 0,
            goalPeriod: nil,
            goalUnit: nil,
            goalSchedule: nil
        )

        let errors = AreaValidator().validate(draft)

        #expect(errors == [.invalidGoalTarget, .missingGoalUnit, .missingGoalSchedule])
    }

    @Test func disabledGoalAllowsMissingGoalFields() {
        let draft = AreaDraft(
            name: "Work",
            type: .neutral,
            goalEnabled: false,
            goalTarget: nil,
            goalPeriod: nil,
            goalUnit: nil
        )

        let errors = AreaValidator().validate(draft)

        #expect(errors.isEmpty)
    }

    @Test func weekdayGoalRequiresSelectedWeekdays() {
        let draft = AreaDraft(
            name: "Training",
            type: .habit,
            goalTarget: 1,
            goalUnit: .focusBlocks,
            goalSchedule: .weekdays,
            weekdayMask: nil
        )

        let errors = AreaValidator().validate(draft)

        #expect(errors == [.missingWeekdays])
    }

    @Test func areaArchivesWithoutChangingStableIdentifier() {
        let id = UUID()
        let now = Date(timeIntervalSince1970: 100)
        let area = Area(
            id: id,
            name: "Reading",
            type: .habit,
            createdAt: now,
            updatedAt: now
        )

        let archivedAt = Date(timeIntervalSince1970: 200)
        area.archive(now: archivedAt)

        #expect(area.id == id)
        #expect(area.isArchived)
        #expect(area.archivedAt == archivedAt)
        #expect(area.updatedAt == archivedAt)
    }

    @Test func areaUpdateNormalizesGoalRawValues() {
        let area = Area(name: "Japanese", type: .nice)

        area.update(
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

        #expect(area.typeRawValue == "habit")
        #expect(area.goalPeriodRawValue == "weekly")
        #expect(area.goalUnitRawValue == "hours")
        #expect(area.goalScheduleRawValue == "weeklyCount")
        #expect(area.weeklyTargetCount == 3)
        #expect(area.hasGoal)
    }

    @Test func areaTypeReadsLegacyRawValues() {
        let habit = Area(name: "Anki", type: .neutral)
        habit.typeRawValue = "must"

        let nice = Area(name: "散歩", type: .neutral)
        nice.typeRawValue = "bonus"

        #expect(habit.type == .habit)
        #expect(nice.type == .nice)
    }

}
