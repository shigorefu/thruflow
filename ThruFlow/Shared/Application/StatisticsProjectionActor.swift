//
//  StatisticsProjectionActor.swift
//  ThruFlow
//
//  Created by Codex on 2026/08/02.
//

import Foundation
import SwiftData

struct StatisticsProjection: Sendable {
    let flow: StatisticsHeatmapResult
    let achievement: AchievementHeatmapResult
}

@ModelActor
actor StatisticsProjectionActor {
    func load(
        filter: StatisticsPeriodFilter,
        calendar: Calendar,
        dayBoundary: AppDayBoundary
    ) throws -> StatisticsPeriodSnapshot {
        let builder = StatisticsPeriodBuilder(
            calendar: calendar,
            dayBoundary: dayBoundary
        )
        let interval = builder.bounds(for: filter).fetchInterval
        let lowerBound = interval.start
        let upperBound = interval.end

        // Fetch overlapping Flows so a context segment can start inside the
        // selected comparison range even when its parent Flow started earlier.
        // The pure builder still applies the exact segment/day boundary.
        let sessions = try modelContext.fetch(FetchDescriptor<FlowSession>(
            predicate: #Predicate { session in
                session.startedAt < upperBound &&
                    (session.endedAt ?? upperBound) >= lowerBound
            },
            sortBy: [SortDescriptor(\FlowSession.startedAt)]
        ))
        let missingCompletionDate = Date.distantPast
        let completedTodos = try modelContext.fetch(FetchDescriptor<Todo>(
            predicate: #Predicate { todo in
                (todo.completedAt ?? missingCompletionDate) >= interval.start &&
                    (todo.completedAt ?? missingCompletionDate) < upperBound &&
                    todo.deletedAt == nil
            },
            sortBy: [SortDescriptor(\Todo.completedAt)]
        ))
        let legacyCompletedTodos = try modelContext.fetch(FetchDescriptor<Todo>(
            predicate: #Predicate { todo in
                todo.completedAt == nil &&
                    todo.updatedAt >= interval.start &&
                    todo.updatedAt < upperBound &&
                    todo.deletedAt == nil
            },
            sortBy: [SortDescriptor(\Todo.updatedAt)]
        ))

        return builder.build(
            flowRecords: sessions.flatMap(makePeriodFlowRecords),
            achievementRecords: (completedTodos + legacyCompletedTodos).compactMap(makePeriodAchievementRecord),
            filter: filter
        )
    }

    func load(
        filter: StatisticsFilter,
        calendar: Calendar,
        dayBoundary: AppDayBoundary,
        now: Date
    ) throws -> StatisticsProjection {
        let interval = fetchInterval(
            for: filter.range,
            calendar: calendar,
            dayBoundary: dayBoundary,
            now: now
        )
        let lowerBound = interval.start
        let upperBound = interval.end

        let sessions = try modelContext.fetch(FetchDescriptor<FlowSession>(
            predicate: #Predicate { session in
                session.startedAt >= lowerBound && session.startedAt < upperBound
            },
            sortBy: [SortDescriptor(\FlowSession.startedAt)]
        ))
        let missingCompletionDate = Date.distantPast
        let completedTodos = try modelContext.fetch(FetchDescriptor<Todo>(
            predicate: #Predicate { todo in
                (todo.completedAt ?? missingCompletionDate) >= lowerBound &&
                    (todo.completedAt ?? missingCompletionDate) < upperBound &&
                    todo.deletedAt == nil
            },
            sortBy: [SortDescriptor(\Todo.completedAt)]
        ))
        // Older stores may contain completed tasks created before completedAt
        // became mandatory. Preserve their previous updatedAt-based placement
        // without widening the query to the entire Todo archive.
        let legacyCompletedTodos = try modelContext.fetch(FetchDescriptor<Todo>(
            predicate: #Predicate { todo in
                todo.completedAt == nil &&
                    todo.updatedAt >= lowerBound &&
                    todo.updatedAt < upperBound &&
                    todo.deletedAt == nil
            },
            sortBy: [SortDescriptor(\Todo.updatedAt)]
        ))
        let todos = completedTodos + legacyCompletedTodos

        let flowRecords = sessions.flatMap(makeFlowRecords)
        let achievementRecords = todos.compactMap(makeAchievementRecord)
        let flowBuilder = StatisticsHeatmapBuilder(
            calendar: calendar,
            dayBoundary: dayBoundary
        )
        let achievementBuilder = AchievementHeatmapBuilder(
            calendar: calendar,
            dayBoundary: dayBoundary
        )

        return StatisticsProjection(
            flow: flowBuilder.build(records: flowRecords, filter: filter, now: now),
            achievement: achievementBuilder.build(records: achievementRecords, filter: filter, now: now)
        )
    }

    private func makeFlowRecords(_ session: FlowSession) -> [StatisticsFlowRecord] {
        guard session.status != .interrupted else { return [] }

        let segments = session.resolvedSegments
        if !segments.isEmpty {
            return segments.compactMap { segment in
                guard segment.resolvedFocusSeconds > 0 else { return nil }
                return StatisticsFlowRecord(
                    sessionID: session.id,
                    startedAt: segment.startedAt,
                    directionID: segment.direction?.id,
                    directionColorHex: segment.direction?.colorHex,
                    focusSeconds: segment.resolvedFocusSeconds
                )
            }
        }

        let focusSeconds = session.resolvedActualFocusDurationSeconds
        guard focusSeconds > 0 else { return [] }
        return [StatisticsFlowRecord(
            sessionID: session.id,
            startedAt: session.startedAt,
            directionID: session.direction?.id,
            directionColorHex: session.direction?.colorHex,
            focusSeconds: focusSeconds
        )]
    }

    private func makeAchievementRecord(_ todo: Todo) -> StatisticsAchievementRecord? {
        guard todo.status == .completed, !todo.isDeleted else { return nil }
        return StatisticsAchievementRecord(
            completedAt: todo.completedAt ?? todo.updatedAt,
            directionID: todo.direction?.id,
            directionColorHex: todo.direction?.colorHex
        )
    }

    private func makePeriodFlowRecords(_ session: FlowSession) -> [StatisticsPeriodFlowRecord] {
        guard session.status != .interrupted else { return [] }

        if !session.resolvedSegments.isEmpty {
            return session.resolvedSegments.compactMap { segment in
                let focusSeconds = segment.resolvedFocusSeconds
                guard focusSeconds > 0 else { return nil }
                return makePeriodFlowRecord(
                    session: session,
                    startedAt: segment.startedAt,
                    focusSeconds: focusSeconds,
                    direction: segment.direction,
                    todo: segment.todo
                )
            }
        }

        let focusSeconds = session.resolvedActualFocusDurationSeconds
        guard focusSeconds > 0 else { return [] }
        return [makePeriodFlowRecord(
            session: session,
            startedAt: session.startedAt,
            focusSeconds: focusSeconds,
            direction: session.direction,
            todo: session.todo
        )]
    }

    private func makePeriodFlowRecord(
        session: FlowSession,
        startedAt: Date,
        focusSeconds: Int,
        direction: Direction?,
        todo: Todo?
    ) -> StatisticsPeriodFlowRecord {
        StatisticsPeriodFlowRecord(
            sessionID: session.id,
            startedAt: startedAt,
            focusSeconds: focusSeconds,
            directionID: direction?.id,
            directionName: direction?.name ?? "",
            directionSymbol: direction?.symbolName ?? "",
            directionColorHex: direction?.colorHex,
            todoID: todo?.id,
            todoTitle: todo?.title ?? "",
            todoHashtags: todo?.hashtags ?? [],
            todoNotes: todo?.notes ?? "",
            intent: session.intent,
            result: session.result ?? ""
        )
    }

    private func makePeriodAchievementRecord(_ todo: Todo) -> StatisticsPeriodAchievementRecord? {
        guard todo.status == .completed, !todo.isDeleted else { return nil }
        return StatisticsPeriodAchievementRecord(
            completedAt: todo.completedAt ?? todo.updatedAt,
            todoID: todo.id,
            todoTitle: todo.title,
            todoHashtags: todo.hashtags,
            todoNotes: todo.notes ?? "",
            directionID: todo.direction?.id,
            directionName: todo.direction?.name ?? "",
            directionSymbol: todo.direction?.symbolName ?? "",
            directionColorHex: todo.direction?.colorHex
        )
    }

    private func fetchInterval(
        for range: StatisticsRange,
        calendar: Calendar,
        dayBoundary: AppDayBoundary,
        now: Date
    ) -> DateInterval {
        let today = dayBoundary.day(containing: now, calendar: calendar)
        let start: Date
        let finalDay: Date

        switch range {
        case .currentMonth:
            let components = calendar.dateComponents([.year, .month], from: today)
            start = calendar.date(from: components) ?? today
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: start) ?? today
            finalDay = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? today
        case .days180:
            start = calendar.date(byAdding: .day, value: -179, to: today) ?? today
            finalDay = today
        case .calendarYear:
            let year = calendar.component(.year, from: today)
            start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? today
            finalDay = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? today
        }

        return DateInterval(
            start: dayBoundary.interval(for: start, calendar: calendar).start,
            end: dayBoundary.interval(for: finalDay, calendar: calendar).end
        )
    }
}
