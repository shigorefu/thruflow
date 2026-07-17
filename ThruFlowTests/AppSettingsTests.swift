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
    @Test func persistsEveryPreference() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.appearance = .dark
        settings.languageCode = "ja"
        settings.weekStart = .monday
        settings.clockFormat = .twentyFourHour

        let restored = AppSettings(defaults: defaults)
        #expect(restored.appearance == .dark)
        #expect(restored.languageCode == "ja")
        #expect(restored.weekStart == .monday)
        #expect(restored.clockFormat == .twentyFourHour)
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
        settings.languageCode = "ja"
        #expect(settings.requiresRestartForLanguage)

        settings.languageCode = AppSettings.systemLanguageCode
        #expect(!settings.requiresRestartForLanguage)
        #expect(defaults.persistentDomain(forName: suiteName)?["AppleLanguages"] == nil)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
