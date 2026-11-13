//
//  StatisticsProjectionActor.swift
//  ThruFlow
//
//

import Foundation
import SwiftData

struct StatisticsProjection: Sendable {
    let flow: StatisticsHeatmapResult
    let achievement: AchievementHeatmapResult
}

@ModelActor
actor StatisticsProjectionActor {
    /// Read the range once on the model actor. Only immutable value records
    /// leave that actor, so card calculations can run independently.
    static nonisolated func presentationUpdates(
        modelContainer: ModelContainer,
        filter: StatisticsPeriodFilter,
        calendar: Calendar,
        dayBoundary: AppDayBoundary
    ) -> AsyncThrowingStream<StatisticsPresentationUpdate, Error> {
        let (updates, continuation) = AsyncThrowingStream<StatisticsPresentationUpdate, Error>.makeStream()
        let request = Task.detached(priority: .userInitiated) {
            do {
                try Task.checkCancellation()
                let loader = StatisticsProjectionActor(modelContainer: modelContainer)
                let builder = StatisticsPeriodBuilder(calendar: calendar, dayBoundary: dayBoundary)
                let input = try await loader.periodInput(
                    filter: filter, calendar: calendar, dayBoundary: dayBoundary, builder: builder
                )
                try Task.checkCancellation()
                let cards = await withTaskGroup(of: StatisticsPresentationUpdate.self) { group in
                    group.addTask { .summary(builder.summary(for: input)) }
                    group.addTask { .trend(builder.trend(for: input)) }
                    group.addTask { .dailyFocus(builder.dailyFocus(for: input)) }
                    group.addTask { .estimateAccuracy(builder.estimateAccuracy(for: input)) }
                    group.addTask { .distribution(builder.distribution(for: input)) }
                    group.addTask { .habits(builder.habits(for: input)) }
                    group.addTask { .days(builder.days(for: input)) }

                    var cards = StatisticsPresentationCards()
                    for await update in group {
                        guard !Task.isCancelled else {
                            group.cancelAll()
                            break
                        }
                        cards.apply(update)
                        continuation.yield(update)
                    }
                    return cards
                }
                try Task.checkCancellation()
                guard let summary = cards.summary, let trend = cards.trend,
                      let distribution = cards.distribution, let habits = cards.habits,
                      let days = cards.days, let dailyFocus = cards.dailyFocus,
                      let estimateAccuracy = cards.estimateAccuracy else {
                    preconditionFailure("The report requires all card results.")
                }
                let rows = builder.csvRows(for: input)
                try Task.checkCancellation()
                continuation.yield(.report(builder.makeSnapshot(
                    for: input, summary: summary, trend: trend, distribution: distribution,
                    habits: habits, days: days, dailyFocus: dailyFocus,
                    estimateAccuracy: estimateAccuracy, csvRows: rows
                )))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in request.cancel() }
        return updates
    }

    func load(
        filter: StatisticsPeriodFilter,
        calendar: Calendar,
        dayBoundary: AppDayBoundary
    ) throws -> StatisticsPeriodSnapshot {
        let builder = StatisticsPeriodBuilder(calendar: calendar, dayBoundary: dayBoundary)
        let input = try periodInput(
            filter: filter, calendar: calendar, dayBoundary: dayBoundary, builder: builder
        )
        return builder.makeSnapshot(
            for: input, summary: builder.summary(for: input), trend: builder.trend(for: input),
            distribution: builder.distribution(for: input), habits: builder.habits(for: input),
            days: builder.days(for: input), dailyFocus: builder.dailyFocus(for: input),
            estimateAccuracy: builder.estimateAccuracy(for: input), csvRows: builder.csvRows(for: input)
        )
    }

    private func periodInput(
        filter: StatisticsPeriodFilter,
        calendar: Calendar,
        dayBoundary: AppDayBoundary,
        builder: StatisticsPeriodBuilder
    ) throws -> StatisticsPeriodBuilder.ReportInput {
        try Task.checkCancellation()
        let bounds = builder.bounds(for: filter)
        let interval = bounds.fetchInterval
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

        // Habit rates include unfinished saved occurrences. These dates are
        // logical days, so do not shift the query by the Flow day boundary.
        let habitStart = bounds.currentStart
        let habitEnd = bounds.currentEnd
        let scheduledTodos = try modelContext.fetch(FetchDescriptor<Todo>(
            predicate: #Predicate { todo in
                (todo.scheduledDate ?? missingCompletionDate) >= habitStart &&
                    (todo.scheduledDate ?? missingCompletionDate) < habitEnd &&
                    todo.deletedAt == nil
            }
        ))

        try Task.checkCancellation()
        return builder.prepare(
            flowRecords: sessions.flatMap(makePeriodFlowRecords),
            achievementRecords: (completedTodos + legacyCompletedTodos).compactMap(makePeriodAchievementRecord),
            filter: filter,
            habitRecords: scheduledTodos.compactMap {
                HabitCompletionRecord(todo: $0, calendar: calendar, dayBoundary: dayBoundary)
            }
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
                    areaID: segment.area?.id,
                    areaColorHex: segment.area?.colorHex,
                    focusSeconds: segment.resolvedFocusSeconds
                )
            }
        }

        let focusSeconds = session.resolvedActualFocusDurationSeconds
        guard focusSeconds > 0 else { return [] }
        return [StatisticsFlowRecord(
            sessionID: session.id,
            startedAt: session.startedAt,
            areaID: session.area?.id,
            areaColorHex: session.area?.colorHex,
            focusSeconds: focusSeconds
        )]
    }

    private func makeAchievementRecord(_ todo: Todo) -> StatisticsAchievementRecord? {
        guard todo.status == .completed, !todo.isDeleted else { return nil }
        return StatisticsAchievementRecord(
            completedAt: todo.completedAt ?? todo.updatedAt,
            areaID: todo.area?.id,
            areaColorHex: todo.area?.colorHex
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
                    area: segment.area,
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
            area: session.area,
            todo: session.todo
        )]
    }

    private func makePeriodFlowRecord(
        session: FlowSession,
        startedAt: Date,
        focusSeconds: Int,
        area: Area?,
        todo: Todo?
    ) -> StatisticsPeriodFlowRecord {
        StatisticsPeriodFlowRecord(
            sessionID: session.id,
            startedAt: startedAt,
            focusSeconds: focusSeconds,
            areaID: area?.id,
            areaName: area?.name ?? "",
            areaSymbol: area?.symbolName ?? "",
            areaColorHex: area?.colorHex,
            todoID: todo?.id,
            todoTitle: todo?.title ?? "",
            todoHashtags: todo?.hashtags ?? [],
            todoNotes: todo?.notes ?? "",
            intent: session.intent,
            result: session.result ?? "",
            projectID: todo?.project?.id,
            projectName: todo?.project?.name ?? ""
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
            areaID: todo.area?.id,
            areaName: todo.area?.name ?? "",
            areaSymbol: todo.area?.symbolName ?? "",
            areaColorHex: todo.area?.colorHex,
            timeEstimate: makeTaskTimeEstimate(todo)
        )
    }

    private func makeTaskTimeEstimate(_ todo: Todo) -> StatisticsTaskTimeEstimate? {
        guard let amount = todo.plannedAmount, amount > 0, todo.recordedFocusSeconds > 0 else { return nil }
        let secondsPerUnit: Int
        switch todo.measurement {
        case .checkbox: return nil
        case .focusBlocks: secondsPerUnit = BlockUnit.secondsPerBlock
        case .minutes: secondsPerUnit = 60
        }
        return StatisticsTaskTimeEstimate(
            plannedSeconds: Double(amount) * Double(secondsPerUnit),
            actualSeconds: Double(todo.recordedFocusSeconds)
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
