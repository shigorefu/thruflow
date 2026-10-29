import Foundation

/// Calendar UI labels use locale grammar rather than a translated numeric suffix.
nonisolated enum CalendarMonthLabels {
    static func title(for month: Int, calendar: Calendar, locale: Locale) -> String {
        let formatter = formatter(calendar: calendar, locale: locale)
        guard let names = formatter.standaloneMonthSymbols,
              names.indices.contains(month - 1) else { return String(month) }
        return names[month - 1]
    }

    static func accessibilityLabel(
        for month: Int, year: Int, calendar: Calendar, locale: Locale
    ) -> String {
        let components = DateComponents(
            calendar: calendar, timeZone: calendar.timeZone,
            year: year, month: month, day: 1, hour: 12
        )
        guard let date = calendar.date(from: components) else {
            return title(for: month, calendar: calendar, locale: locale)
        }
        let formatter = formatter(calendar: calendar, locale: locale)
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: date)
    }

    private static func formatter(calendar: Calendar, locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        return formatter
    }
}
