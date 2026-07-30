import Foundation

struct HabitPausePeriod: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let startsOn: Date
    var endsBefore: Date?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        startsOn: Date,
        endsBefore: Date?,
        createdAt: Date = .now
    ) {
        self.id = id
        self.startsOn = startsOn
        self.endsBefore = endsBefore
        self.createdAt = createdAt
    }

    func contains(_ day: Date) -> Bool {
        guard day >= startsOn else { return false }
        return endsBefore.map { day < $0 } ?? true
    }
}

enum HabitPausePeriodCodec {
    static func decode(_ rawValue: String?) -> [HabitPausePeriod] {
        guard let rawValue,
              let data = rawValue.data(using: .utf8),
              let periods = try? JSONDecoder().decode([HabitPausePeriod].self, from: data) else {
            return []
        }

        return periods
    }

    static func encode(_ periods: [HabitPausePeriod]) -> String? {
        guard !periods.isEmpty,
              let data = try? JSONEncoder().encode(periods) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}

struct HabitPauseService {
    var calendar: Calendar = .current
    var dayBoundary: AppDayBoundary = .midnight

    func isPaused(_ direction: Direction, on day: Date) -> Bool {
        guard direction.type == .habit else { return false }
        let normalizedDay = calendar.startOfDay(for: day)
        return normalizedPeriods(for: direction).contains { $0.contains(normalizedDay) }
    }

    func activePeriod(for direction: Direction, on day: Date) -> HabitPausePeriod? {
        let normalizedDay = calendar.startOfDay(for: day)
        return normalizedPeriods(for: direction).first { $0.contains(normalizedDay) }
    }

    @discardableResult
    func pauseToday(
        _ direction: Direction,
        todos: [Todo],
        now: Date = .now
    ) -> Bool {
        let today = dayBoundary.day(containing: now, calendar: calendar)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)
            ?? today.addingTimeInterval(86_400)
        return pause(
            direction,
            startsOn: today,
            endsBefore: tomorrow,
            todos: todos,
            now: now
        )
    }

    @discardableResult
    func pause(
        _ direction: Direction,
        through inclusiveEndDate: Date,
        todos: [Todo],
        now: Date = .now
    ) -> Bool {
        let today = dayBoundary.day(containing: now, calendar: calendar)
        let normalizedEnd = max(today, calendar.startOfDay(for: inclusiveEndDate))
        let endsBefore = calendar.date(byAdding: .day, value: 1, to: normalizedEnd)
            ?? normalizedEnd.addingTimeInterval(86_400)
        return pause(
            direction,
            startsOn: today,
            endsBefore: endsBefore,
            todos: todos,
            now: now
        )
    }

    @discardableResult
    func pauseIndefinitely(
        _ direction: Direction,
        todos: [Todo],
        now: Date = .now
    ) -> Bool {
        pause(
            direction,
            startsOn: dayBoundary.day(containing: now, calendar: calendar),
            endsBefore: nil,
            todos: todos,
            now: now
        )
    }

    @discardableResult
    func resume(_ direction: Direction, now: Date = .now) -> Bool {
        let today = dayBoundary.day(containing: now, calendar: calendar)
        var changed = false
        var periods: [HabitPausePeriod] = []

        for var period in normalizedPeriods(for: direction) {
            guard period.contains(today) else {
                periods.append(period)
                continue
            }

            changed = true
            if period.startsOn < today {
                period.endsBefore = today
                periods.append(period)
            }
        }

        guard changed else { return false }
        direction.habitPausePeriods = normalized(periods)
        direction.updatedAt = now
        return true
    }

    private func pause(
        _ direction: Direction,
        startsOn: Date,
        endsBefore: Date?,
        todos: [Todo],
        now: Date
    ) -> Bool {
        guard direction.type == .habit else { return false }

        let period = HabitPausePeriod(
            startsOn: calendar.startOfDay(for: startsOn),
            endsBefore: endsBefore.map { calendar.startOfDay(for: $0) },
            createdAt: now
        )
        direction.habitPausePeriods = normalized(direction.habitPausePeriods + [period])
        direction.updatedAt = now
        suppressUnstartedTodos(for: direction, during: period, in: todos, now: now)
        return true
    }

    private func suppressUnstartedTodos(
        for direction: Direction,
        during period: HabitPausePeriod,
        in todos: [Todo],
        now: Date
    ) {
        for todo in todos {
            guard todo.direction?.id == direction.id,
                  !todo.isArchived,
                  !todo.isDeleted,
                  !todo.isCompleted,
                  todo.actualProgress == 0,
                  todo.recordedFocusSeconds == 0,
                  let scheduledDate = todo.scheduledDate,
                  period.contains(calendar.startOfDay(for: scheduledDate)) else {
                continue
            }

            todo.softDelete(now: now)
        }
    }

    private func normalizedPeriods(for direction: Direction) -> [HabitPausePeriod] {
        normalized(direction.habitPausePeriods)
    }

    private func normalized(_ periods: [HabitPausePeriod]) -> [HabitPausePeriod] {
        let sorted = periods.sorted {
            if $0.startsOn == $1.startsOn {
                return ($0.endsBefore ?? .distantFuture) < ($1.endsBefore ?? .distantFuture)
            }
            return $0.startsOn < $1.startsOn
        }

        var result: [HabitPausePeriod] = []
        for period in sorted {
            guard var previous = result.last else {
                result.append(period)
                continue
            }

            let overlaps = previous.endsBefore.map { period.startsOn <= $0 } ?? true
            guard overlaps else {
                result.append(period)
                continue
            }

            result.removeLast()
            if previous.endsBefore == nil || period.endsBefore == nil {
                previous.endsBefore = nil
            } else if let previousEnd = previous.endsBefore,
                      let periodEnd = period.endsBefore {
                previous.endsBefore = max(previousEnd, periodEnd)
            }
            result.append(previous)
        }

        return result
    }
}
