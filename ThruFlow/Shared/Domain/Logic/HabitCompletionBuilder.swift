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
            let key = OccurrenceKey(ownerKey: record.ownerKey, day: record.scheduledDay)
            // A sync collision is one obligation, not two. Never sum duplicated progress.
            if let existing = occurrences[key],
               existing.fraction > record.fraction ||
                (existing.fraction == record.fraction && existing.id.uuidString < record.id.uuidString) {
                continue
            }
            occurrences[key] = record
        }
        let grouped = Dictionary(grouping: occurrences.values, by: \.ownerKey)
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
            completedFraction: occurrences.values.reduce(0) { $0 + $1.fraction },
            occurrenceCount: occurrences.count,
            areas: areas
        )
    }
}
