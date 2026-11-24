import Foundation

struct AppDayBoundary: Equatable, Sendable {
    nonisolated static let midnight = AppDayBoundary(hour: 0)

    let hour: Int

    nonisolated init(hour: Int) {
        self.hour = min(max(hour, 0), 23)
    }

    nonisolated func day(containing instant: Date, calendar: Calendar) -> Date {
        let calendarDay = calendar.startOfDay(for: instant)
        guard hour > 0 else { return calendarDay }

        let boundary = start(of: calendarDay, calendar: calendar)
        guard instant < boundary else { return calendarDay }

        return calendar.date(byAdding: .day, value: -1, to: calendarDay)
            ?? calendarDay.addingTimeInterval(-86_400)
    }

    nonisolated func interval(for day: Date, calendar: Calendar) -> DateInterval {
        let normalizedDay = calendar.startOfDay(for: day)
        let intervalStart = start(of: normalizedDay, calendar: calendar)
        let nextCalendarDay = calendar.date(byAdding: .day, value: 1, to: normalizedDay)
            ?? normalizedDay.addingTimeInterval(86_400)
        let intervalEnd = start(of: nextCalendarDay, calendar: calendar)
        return DateInterval(start: intervalStart, end: intervalEnd)
    }

    nonisolated func contains(_ instant: Date, in day: Date, calendar: Calendar) -> Bool {
        let dayInterval = interval(for: day, calendar: calendar)
        return instant >= dayInterval.start && instant < dayInterval.end
    }

    nonisolated private func start(of calendarDay: Date, calendar: Calendar) -> Date {
        calendar.date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: calendarDay,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) ?? calendarDay.addingTimeInterval(TimeInterval(hour * 3_600))
    }
}
