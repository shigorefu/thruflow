import Foundation

/// Identifies zero-completion days that follow the fulfillment of every
/// weekly Habit quota in the filtered week. Saved fixed-day obligations veto a rest day.
nonisolated struct WeeklyHabitRestDays {
    let calendar: Calendar

    func dates(
        records: [HabitCompletionRecord],
        filter: StatisticsPeriodFilter,
        ordinaryTaskDays: Set<Date>,
        today: Date
    ) -> Set<Date> {
        let term = filter.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let relevant = records.filter {
            $0.scheduledDay <= today &&
                (filter.areaIDs.isEmpty || filter.areaIDs.contains($0.areaID)) &&
                (term.isEmpty || $0.searchText.localizedCaseInsensitiveContains(term))
        }
        let weeks = Dictionary(grouping: relevant) {
            calendar.dateInterval(of: .weekOfYear, for: $0.scheduledDay)?.start ?? $0.scheduledDay
        }
        var result = Set<Date>()
        for (start, records) in weeks {
            let weeklyOwners = Dictionary(grouping: records.filter { $0.weeklyTargetCount != nil }, by: \.ownerKey)
            guard !weeklyOwners.isEmpty,
                  let end = calendar.dateInterval(of: .weekOfYear, for: start)?.end else { continue }
            var day = start
            while day < end && day <= today {
                let hasFixedObligation = records.contains { $0.weeklyTargetCount == nil && $0.scheduledDay == day }
                let allQuotasMet = weeklyOwners.values.allSatisfy { attempts in
                    let completions = Set(attempts.filter { attempt in
                        guard attempt.fraction == 1, attempt.scheduledDay < day,
                              let completedDay = attempt.completedDay else { return false }
                        return completedDay < day
                    }.map(\.scheduledDay))
                    return completions.count >= (attempts.first?.weeklyTargetCount ?? 1)
                }
                if allQuotasMet && !hasFixedObligation && !ordinaryTaskDays.contains(day) {
                    result.insert(day)
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
                day = next
            }
        }
        return result
    }
}
