import Foundation

enum ScreenshotScreen: String, CaseIterable {
    case flow
    case tasks
    case history
    case directions
    case statistics
    case statisticsDots = "statistics-dots"
}

enum ScreenshotLanguage: String, CaseIterable {
    case ja
    case en
    case ru
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"

    var localeIdentifier: String {
        switch self {
        case .ja: "ja_JP"
        case .en: "en_US"
        case .ru: "ru_RU"
        case .zhHans: "zh_Hans_CN"
        case .zhHant: "zh_Hant_TW"
        }
    }
}

enum ScreenshotMode {
    static let launchArgument = "--screenshot-mode"

    private static let defaultsSuiteName = "com.shigorefu.thruflow.screenshots.\(UUID().uuidString)"

    static let referenceDate: Date = Calendar.current.date(bySettingHour: 18, minute: 30, second: 0, of: .now) ?? .now

    static func isEnabled(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        #if DEBUG
        arguments.contains(launchArgument)
#else
        false
#endif
    }

    static func initialScreen(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> ScreenshotScreen {
        guard isEnabled(arguments: arguments) else { return .flow }
        let prefix = "--screenshot-screen="
        guard let argument = arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return .flow
        }

        return ScreenshotScreen(rawValue: String(argument.dropFirst(prefix.count))) ?? .flow
    }

    static func language(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> ScreenshotLanguage {
        guard isEnabled(arguments: arguments) else { return .ja }
        let prefix = "--screenshot-language="
        guard let argument = arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return .ja
        }

        return ScreenshotLanguage(rawValue: String(argument.dropFirst(prefix.count))) ?? .ja
    }

    /// Screenshot launches use an isolated preference domain so the selected
    /// language, appearance, and player context never touch the user's app.
    static func configuredDefaults(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> UserDefaults {
        guard isEnabled(arguments: arguments) else { return .standard }
        guard let defaults = UserDefaults(suiteName: defaultsSuiteName) else {
            preconditionFailure("Unable to create isolated screenshot preferences")
        }

        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defaults.set("dark", forKey: "settings.appearance")
        defaults.set(language(arguments: arguments).rawValue, forKey: "settings.languageCode")
        defaults.set("monday", forKey: "settings.weekStart")
        defaults.set("twentyFourHour", forKey: "settings.clockFormat")
        defaults.set(0, forKey: "settings.dayStartHour")
        defaults.set(false, forKey: "settings.showsTaskQuickInputLegend")
        defaults.set(true, forKey: "onboarding.didComplete.v1")
        defaults.set(
            ScreenshotDataSeeder.featuredDirectionID.uuidString,
            forKey: "flow.selectedDirectionID"
        )
        defaults.set(
            ScreenshotDataSeeder.featuredTodoID.uuidString,
            forKey: "flow.selectedTodoID"
        )
        defaults.set(FlowMode.twentyFiveFive.rawValue, forKey: "flow.selectedMode")
        defaults.set("", forKey: "flow.lastIntent")
        return defaults
    }
}

struct ScreenshotFlowNotificationService: FlowNotificationService {
    func requestAuthorizationIfNeeded() {}
    func scheduleFocusFinished(mode: FlowMode, focusedSeconds: Int, fireDate: Date) {}
    func scheduleBreakFinished(fireDate: Date) {}
    func scheduleRunningTooLong(phase: FlowNotificationPhase, fireDate: Date) {}
    func cancelPendingFlowNotifications() {}
    func clearBadge() {}
}
