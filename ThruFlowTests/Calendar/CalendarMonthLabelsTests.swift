import Foundation
import Testing
@testable import ThruFlow

struct CalendarMonthLabelsTests {
    @Test func englishMonthPickerUsesNamesInsteadOfNumericCaptions() {
        let calendar = calendar()
        let labels = (1...12).map {
            CalendarMonthLabels.title(for: $0, calendar: calendar, locale: Locale(identifier: "en_US"))
        }
        #expect(labels == [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        ])
    }

    @Test func russianStandaloneMonthsUseNominativeCase() {
        let calendar = calendar()
        let labels = (1...12).map {
            CalendarMonthLabels.title(for: $0, calendar: calendar, locale: Locale(identifier: "ru_RU"))
        }
        #expect(labels == [
            "январь", "февраль", "март", "апрель", "май", "июнь",
            "июль", "август", "сентябрь", "октябрь", "ноябрь", "декабрь"
        ])
    }

    @Test func allSupportedLocalesHaveMonthNamesAndLocalizedYearContext() {
        let calendar = calendar()
        for identifier in ["ja_JP", "en_US", "ru_RU", "zh_Hans_CN", "zh_Hant_TW"] {
            let locale = Locale(identifier: identifier)
            let names = (1...12).map {
                CalendarMonthLabels.title(for: $0, calendar: calendar, locale: locale)
            }
            #expect(Set(names).count == 12)
            #expect(names.allSatisfy { !$0.isEmpty })
            for month in [1, 12] {
                let label = CalendarMonthLabels.accessibilityLabel(
                    for: month, year: 2026, calendar: calendar, locale: locale
                )
                #expect(label.contains("2026"))
                #expect(!label.contains("2025"))
                #expect(!label.contains("2027"))
                if identifier == "en_US" { #expect(label.contains(names[month - 1])) }
                if identifier == "ru_RU" { #expect(label.contains(names[month - 1])) }
                if identifier == "ja_JP" || identifier.hasPrefix("zh_") {
                    #expect(names[month - 1].contains("月"))
                    #expect(label.contains("月"))
                }
            }
        }
    }

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        // An explicit zone prevents month/year labels from depending on the host.
        calendar.timeZone = TimeZone(secondsFromGMT: -11 * 60 * 60)!
        return calendar
    }
}
