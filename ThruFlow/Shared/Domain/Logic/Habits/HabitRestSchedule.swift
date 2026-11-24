import Foundation

/// Capacity of a repeating seven-day pattern, including the last-to-first gap.
nonisolated enum HabitRestSchedule {
    static func maximumWeeklyCount(minimumRestDays: Int, weekdayMask: Int?) -> Int {
        let suppliedMask = weekdayMask ?? 0
        let allowedMask = suppliedMask > 0 ? suppliedMask & 127 : 127
        var maximum = 0
        for subset in 1...127 where subset & allowedMask == subset {
            let days = (0..<7).filter { subset & (1 << $0) != 0 }
            let gaps = zip(days, days.dropFirst() + [days[0] + 7])
            if gaps.allSatisfy({ gap in gap.1 - gap.0 > minimumRestDays }) {
                maximum = max(maximum, days.count)
            }
        }
        return maximum
    }
}
