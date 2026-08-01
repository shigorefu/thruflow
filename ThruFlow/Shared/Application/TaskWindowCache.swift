import Combine
import Foundation

/// Keeps the task screen's hot date window ready before the user opens it.
/// SwiftData models stay on the main actor; only immutable index records are
/// processed off the main actor.
@MainActor
final class TaskWindowCache: ObservableObject {
    struct SourceRevision: Hashable {
        let count: Int
        let latestUpdate: Date?
        let applicationDay: Date
    }

    private struct IndexRecord: Sendable {
        let id: UUID
        let scheduledDate: Date?
    }

    @Published private(set) var revision = 0
    @Published private(set) var isFullyIndexed = false

    private var generation = 0
    private var modelsByID: [UUID: Todo] = [:]
    private var warmIDsByDay: [Date: [UUID]] = [:]
    private var allIDsByDay: [Date: [UUID]]?
    private var backlog = TaskBacklogSnapshot(overdue: [], unscheduled: [])
    private var indexingTask: Task<Void, Never>?
    private var calendar = Calendar.current

    static func sourceRevision(
        todoCount: Int,
        latestUpdate: Date?,
        calendar: Calendar,
        dayBoundary: AppDayBoundary,
        now: Date = .now
    ) -> SourceRevision {
        SourceRevision(
            count: todoCount,
            latestUpdate: latestUpdate,
            applicationDay: dayBoundary.day(containing: now, calendar: calendar)
        )
    }

    func refresh(
        todos: [Todo],
        calendar: Calendar,
        dayBoundary: AppDayBoundary,
        now: Date = .now
    ) {
        generation += 1
        let currentGeneration = generation
        indexingTask?.cancel()

        self.calendar = calendar
        modelsByID.removeAll(keepingCapacity: true)
        for todo in todos {
            modelsByID[todo.id] = todo
        }
        backlog = TaskBacklogBuilder(
            calendar: calendar,
            dayBoundary: dayBoundary
        ).build(todos: todos, now: now)

        let today = dayBoundary.day(containing: now, calendar: calendar)
        let warmStart = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        let warmEnd = calendar.date(byAdding: .day, value: 15, to: today) ?? today
        let records = todos.map { IndexRecord(id: $0.id, scheduledDate: $0.scheduledDate) }
        warmIDsByDay = Self.makeIndex(
            records: records,
            calendar: calendar,
            limitedTo: DateInterval(start: warmStart, end: warmEnd)
        )
        allIDsByDay = nil
        isFullyIndexed = false
        revision &+= 1

        indexingTask = Task { [weak self] in
            await Task.yield()
            guard !Task.isCancelled else { return }

            let index = await Task.detached(priority: .utility) {
                Self.makeIndex(records: records, calendar: calendar)
            }.value

            guard !Task.isCancelled,
                  let self,
                  self.generation == currentGeneration else {
                return
            }

            self.allIDsByDay = index
            self.isFullyIndexed = true
            self.revision &+= 1
        }
    }

    func todos(on date: Date) -> [Todo] {
        _ = revision
        let day = calendar.startOfDay(for: date)
        let ids = allIDsByDay?[day] ?? warmIDsByDay[day] ?? []
        return ids.compactMap { modelsByID[$0] }
    }

    func todos(in dates: [Date]) -> [Todo] {
        _ = revision
        var seen = Set<UUID>()
        return dates.flatMap(todos(on:)).filter { seen.insert($0.id).inserted }
    }

    func backlogSnapshot() -> TaskBacklogSnapshot {
        _ = revision
        return backlog
    }

    func waitForBackgroundIndex() async {
        await indexingTask?.value
    }

    private nonisolated static func makeIndex(
        records: [IndexRecord],
        calendar: Calendar,
        limitedTo interval: DateInterval? = nil
    ) -> [Date: [UUID]] {
        var result: [Date: [UUID]] = [:]
        result.reserveCapacity(min(records.count, 64))

        for record in records {
            guard let scheduledDate = record.scheduledDate,
                  interval?.contains(scheduledDate) ?? true else {
                continue
            }
            result[calendar.startOfDay(for: scheduledDate), default: []].append(record.id)
        }

        return result
    }
}
