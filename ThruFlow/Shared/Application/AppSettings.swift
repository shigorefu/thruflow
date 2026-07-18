//
//  AppSettings.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/17.
//

import Combine
import Foundation

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
}

enum AppWeekStart: String, CaseIterable, Identifiable {
    case system
    case sunday
    case monday
    case saturday

    var id: String { rawValue }

    var calendarWeekday: Int? {
        switch self {
        case .system:
            nil
        case .sunday:
            1
        case .monday:
            2
        case .saturday:
            7
        }
    }
}

enum AppClockFormat: String, CaseIterable, Identifiable {
    case system
    case twelveHour
    case twentyFourHour

    var id: String { rawValue }

    fileprivate var localeHourCycle: String? {
        switch self {
        case .system:
            nil
        case .twelveHour:
            "h12"
        case .twentyFourHour:
            "h23"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let systemLanguageCode = "system"

    @Published var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    @Published var languageCode: String {
        didSet {
            defaults.set(languageCode, forKey: Keys.languageCode)
            applyLanguagePreference()
        }
    }

    @Published var weekStart: AppWeekStart {
        didSet { defaults.set(weekStart.rawValue, forKey: Keys.weekStart) }
    }

    @Published var clockFormat: AppClockFormat {
        didSet { defaults.set(clockFormat.rawValue, forKey: Keys.clockFormat) }
    }

    @Published var showsTaskQuickInputLegend: Bool {
        didSet { defaults.set(showsTaskQuickInputLegend, forKey: Keys.showsTaskQuickInputLegend) }
    }

    let launchLanguageCode: String

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        appearance = AppAppearance(
            rawValue: defaults.string(forKey: Keys.appearance) ?? ""
        ) ?? .system
        let storedLanguageCode = defaults.string(forKey: Keys.languageCode) ?? Self.systemLanguageCode
        languageCode = storedLanguageCode
        weekStart = AppWeekStart(
            rawValue: defaults.string(forKey: Keys.weekStart) ?? ""
        ) ?? .system
        clockFormat = AppClockFormat(
            rawValue: defaults.string(forKey: Keys.clockFormat) ?? ""
        ) ?? .system
        showsTaskQuickInputLegend = defaults.object(forKey: Keys.showsTaskQuickInputLegend) as? Bool ?? true
        launchLanguageCode = storedLanguageCode
        applyLanguagePreference()
    }

    var requiresRestartForLanguage: Bool {
        languageCode != launchLanguageCode
    }

    var effectiveCalendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = effectiveLocale
        if let firstWeekday = weekStart.calendarWeekday {
            calendar.firstWeekday = firstWeekday
        }
        return calendar
    }

    var effectiveLocale: Locale {
        let baseIdentifier = launchLanguageCode == Self.systemLanguageCode
            ? Locale.autoupdatingCurrent.identifier
            : launchLanguageCode

        guard let hourCycle = clockFormat.localeHourCycle else {
            return Locale(identifier: baseIdentifier)
        }

        let separator = baseIdentifier.contains("@") ? ";" : "@"
        return Locale(identifier: "\(baseIdentifier)\(separator)hours=\(hourCycle)")
    }

    private func applyLanguagePreference() {
        if languageCode == Self.systemLanguageCode {
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set([languageCode], forKey: "AppleLanguages")
        }
    }

    private enum Keys {
        static let appearance = "settings.appearance"
        static let languageCode = "settings.languageCode"
        static let weekStart = "settings.weekStart"
        static let clockFormat = "settings.clockFormat"
        static let showsTaskQuickInputLegend = "settings.showsTaskQuickInputLegend"
    }
}
