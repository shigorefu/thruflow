//
//  AppSettingsTests.swift
//  ThruFlowTests
//
//  Created by Codex on 2026/07/17.
//

import Foundation
import Testing
@testable import ThruFlow

@MainActor
struct AppSettingsTests {
    @Test func newInstallationDefaultsToJapanese() {
        let settings = AppSettings(defaults: makeDefaults())

        #expect(settings.languageCode == "ja")
        #expect(settings.effectiveLocale.language.languageCode?.identifier == "ja")
    }

    @Test func persistsEveryPreference() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.appearance = .dark
        settings.languageCode = "ja"
        settings.weekStart = .monday
        settings.clockFormat = .twentyFourHour
        settings.showsTaskQuickInputLegend = false

        let restored = AppSettings(defaults: defaults)
        #expect(restored.appearance == .dark)
        #expect(restored.languageCode == "ja")
        #expect(restored.weekStart == .monday)
        #expect(restored.clockFormat == .twentyFourHour)
        #expect(restored.showsTaskQuickInputLegend == false)
        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["ja"])
    }

    @Test func calendarUsesSelectedFirstWeekday() {
        let settings = AppSettings(defaults: makeDefaults())

        settings.weekStart = .sunday
        #expect(settings.effectiveCalendar.firstWeekday == 1)

        settings.weekStart = .monday
        #expect(settings.effectiveCalendar.firstWeekday == 2)

        settings.weekStart = .saturday
        #expect(settings.effectiveCalendar.firstWeekday == 7)
    }

    @Test func calendarWeekdaysUseReadableLocalizedAbbreviations() {
        var englishCalendar = Calendar(identifier: .gregorian)
        englishCalendar.locale = Locale(identifier: "en_US")
        englishCalendar.firstWeekday = 2

        var russianCalendar = Calendar(identifier: .gregorian)
        russianCalendar.locale = Locale(identifier: "ru_RU")
        russianCalendar.firstWeekday = 2

        var japaneseCalendar = Calendar(identifier: .gregorian)
        japaneseCalendar.locale = Locale(identifier: "ja_JP")
        japaneseCalendar.firstWeekday = 2

        let english = CalendarWeekdaySymbols.orderedAbbreviated(calendar: englishCalendar)
        let russian = CalendarWeekdaySymbols.orderedAbbreviated(calendar: russianCalendar)
        let japanese = CalendarWeekdaySymbols.orderedAbbreviated(calendar: japaneseCalendar)

        #expect(english.first == "Mon")
        #expect(russian.first == "Пн")
        #expect(japanese.first == "月")
        #expect(english.allSatisfy { $0.count > 1 })
        #expect(russian.allSatisfy { $0.count > 1 })
    }

    @Test func clockFormatOverridesLocaleHourCycle() {
        let settings = AppSettings(defaults: makeDefaults())
        settings.languageCode = "ja"

        settings.clockFormat = .twelveHour
        let twelveHourPattern = DateFormatter.dateFormat(
            fromTemplate: "j:mm",
            options: 0,
            locale: settings.effectiveLocale
        ) ?? ""

        settings.clockFormat = .twentyFourHour
        let twentyFourHourPattern = DateFormatter.dateFormat(
            fromTemplate: "j:mm",
            options: 0,
            locale: settings.effectiveLocale
        ) ?? ""

        #expect(twelveHourPattern.contains("h"))
        #expect(twentyFourHourPattern.contains("H"))
    }

    @Test func languageChangeRequestsRestartAndSystemClearsOverride() {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let settings = AppSettings(defaults: defaults)

        #expect(!settings.requiresRestartForLanguage)
        settings.languageCode = "en"
        #expect(settings.requiresRestartForLanguage)

        settings.languageCode = AppSettings.systemLanguageCode
        #expect(settings.requiresRestartForLanguage)
        #expect(defaults.persistentDomain(forName: suiteName)?["AppleLanguages"] == nil)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
