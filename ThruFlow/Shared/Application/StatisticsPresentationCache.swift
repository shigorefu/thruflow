import Foundation

/// Retains a small set of report projections when their view is removed.
struct StatisticsPresentationCache {
    private struct Entry {
        let snapshot: StatisticsPeriodSnapshot
        let calendar: Calendar
        let dayBoundary: AppDayBoundary

        func matches(
            _ filter: StatisticsPeriodFilter,
            calendar: Calendar,
            dayBoundary: AppDayBoundary
        ) -> Bool {
            snapshot.filter == filter && self.calendar == calendar && self.dayBoundary == dayBoundary
        }
    }

    private var entries: [Entry] = []

    func snapshot(
        for filter: StatisticsPeriodFilter,
        calendar: Calendar,
        dayBoundary: AppDayBoundary
    ) -> StatisticsPeriodSnapshot? {
        entries.first { $0.matches(filter, calendar: calendar, dayBoundary: dayBoundary) }?.snapshot
    }

    mutating func store(
        _ snapshot: StatisticsPeriodSnapshot,
        calendar: Calendar,
        dayBoundary: AppDayBoundary
    ) {
        entries.removeAll { entry in
            entry.calendar != calendar || entry.dayBoundary != dayBoundary ||
                entry.snapshot.filter == snapshot.filter
        }
        entries.insert(Entry(snapshot: snapshot, calendar: calendar, dayBoundary: dayBoundary), at: 0)
        if entries.count > 4 {
            entries.removeLast()
        }
    }
}
