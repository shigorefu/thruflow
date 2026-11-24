import Foundation

/// A saved occurrence, detached from SwiftData before computing statistics.
struct HabitCompletionRecord: Equatable, Sendable {
    let id: UUID
    let scheduledDay: Date
    let areaID: UUID
    let ownerKey: String
    let areaName: String
    let areaSymbol: String
    let areaColorHex: String
    let searchText: String
    let fraction: Double
    let weeklyTargetCount: Int?
    let completedDay: Date?

    nonisolated init?(todo: Todo, calendar: Calendar, dayBoundary: AppDayBoundary = .midnight) {
        guard let habit = HabitDefinition(todo: todo), !todo.isDeleted,
              let area = todo.area, let scheduledDate = todo.scheduledDate else { return nil }
        let started = todo.isCompleted || todo.actualProgress > 0 || todo.recordedFocusSeconds > 0
        let day = calendar.startOfDay(for: scheduledDate)
        let predatesAreaArchive = area.archivedAt.map {
            day < dayBoundary.day(containing: $0, calendar: calendar)
        } ?? true
        guard started || (!todo.isArchived && predatesAreaArchive &&
            !habit.isPaused(on: day, calendar: calendar)) else { return nil }
        weeklyTargetCount = habit.goalSchedule == .weeklyCount ? max(1, habit.weeklyTargetCount ?? 1) : nil
        id = todo.id
        // scheduledDate is already a logical calendar date, not a Flow timestamp.
        scheduledDay = day
        areaID = area.id
        ownerKey = habit.ownerKey
        areaName = todo.project.map { "\(area.name) / \($0.name)" } ?? area.name
        areaSymbol = area.symbolName
        areaColorHex = area.colorHex
        searchText = [todo.title, todo.notes ?? "", todo.hashtags.joined(separator: " "),
                      area.name, area.symbolName, todo.project?.name ?? ""].joined(separator: " ")
        if todo.isCompleted {
            fraction = 1
        } else if todo.measurement == .checkbox {
            fraction = todo.actualProgress > 0 ? 1 : 0
        } else if let target = todo.plannedAmount, target > 0 {
            let unitSeconds = todo.measurement == .minutes ? 60 : BlockUnit.secondsPerBlock
            // A nil seconds field is a legacy record; an explicit zero is authoritative.
            let seconds = todo.focusDurationSeconds.map { Double(max(0, $0)) }
                ?? Double(max(0, todo.actualProgress)) * Double(unitSeconds)
            fraction = min(1, seconds / (Double(target) * Double(unitSeconds)))
        } else {
            fraction = 0
        }
        completedDay = fraction == 1
            ? dayBoundary.day(containing: todo.completedAt ?? todo.updatedAt, calendar: calendar)
            : nil
    }
}

struct HabitCompletionArea: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let symbol: String
    let colorHex: String
    let rate: Double
    let occurrenceCount: Int
}

struct HabitCompletionSummary: Equatable, Sendable {
    let completedFraction: Double
    let occurrenceCount: Int
    let areas: [HabitCompletionArea]

    nonisolated var rate: Double? {
        occurrenceCount > 0 ? completedFraction / Double(occurrenceCount) : nil
    }
}

nonisolated struct HabitCompletionBuilder: Sendable {
    var calendar: Calendar = .current

    private struct WeeklyKey: Hashable {
        let ownerKey: String
        let weekStart: Date
    }
    private nonisolated struct OccurrenceKey: Hashable, Sendable {
        let ownerKey: String
        let day: Date
    }

    nonisolated func build(
        records: [HabitCompletionRecord],
        filter: StatisticsPeriodFilter,
        bounds: StatisticsPeriodBounds,
        today: Date
    ) -> HabitCompletionSummary {
        let term = filter.query.trimmingCharacters(in: .whitespacesAndNewlines)
        var occurrences: [OccurrenceKey: HabitCompletionRecord] = [:]
        for record in records where bounds.containsCurrent(record.scheduledDay) && record.scheduledDay <= today {
            guard (filter.areaIDs.isEmpty || filter.areaIDs.contains(record.areaID)),
                  term.isEmpty || record.searchText.localizedCaseInsensitiveContains(term) else { continue }
            // An open logical day contributes only fully met goals.
            guard record.scheduledDay < today || record.fraction == 1 else { continue }
            let key = OccurrenceKey(ownerKey: record.ownerKey, day: record.scheduledDay)
            // A sync collision is one obligation, not two. Never sum duplicated progress.
            if let existing = occurrences[key],
               existing.fraction > record.fraction ||
                (existing.fraction == record.fraction && existing.id.uuidString < record.id.uuidString) {
                continue
            }
            occurrences[key] = record
        }
        // Extra attempts do not create extra obligations beyond a weekly quota.
        let weekly = Dictionary(grouping: occurrences.values.filter { $0.weeklyTargetCount != nil }) {
            WeeklyKey(ownerKey: $0.ownerKey,
                      weekStart: calendar.dateInterval(of: .weekOfYear, for: $0.scheduledDay)?.start ?? $0.scheduledDay)
        }
        var counted = occurrences.values.filter { $0.weeklyTargetCount == nil }
        for records in weekly.values {
            let ranked = records.sorted {
                if $0.fraction != $1.fraction { return $0.fraction > $1.fraction }
                if $0.scheduledDay != $1.scheduledDay { return $0.scheduledDay < $1.scheduledDay }
                return $0.id.uuidString < $1.id.uuidString
            }
            counted.append(contentsOf: ranked.prefix(ranked.first?.weeklyTargetCount ?? 1))
        }
        let grouped = Dictionary(grouping: counted, by: \.ownerKey)
        let areas = grouped.map { id, records in
            let metadata = records.sorted { $0.id.uuidString < $1.id.uuidString }[0]
            return HabitCompletionArea(
                id: id, name: metadata.areaName, symbol: metadata.areaSymbol,
                colorHex: metadata.areaColorHex,
                rate: records.reduce(0) { $0 + $1.fraction } / Double(records.count),
                occurrenceCount: records.count
            )
        }.sorted {
            if $0.name == $1.name { return $0.id < $1.id }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        return HabitCompletionSummary(
            completedFraction: counted.reduce(0) { $0 + $1.fraction },
            occurrenceCount: counted.count,
            areas: areas
        )
    }
}
