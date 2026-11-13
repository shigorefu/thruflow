import Foundation

struct StatisticsPeriodBuilder: Sendable {
    private let calendar: Calendar
    private let dayBoundary: AppDayBoundary

    nonisolated init(
        calendar: Calendar = .current,
        dayBoundary: AppDayBoundary = .midnight
    ) {
        self.calendar = calendar
        self.dayBoundary = dayBoundary
    }

    nonisolated func anchorDate(
        forCalendarSelection selectedDate: Date,
        maximumDate: Date
    ) -> Date {
        min(
            calendar.startOfDay(for: selectedDate),
            calendar.startOfDay(for: maximumDate)
        )
    }

    nonisolated func bounds(for filter: StatisticsPeriodFilter) -> StatisticsPeriodBounds {
        // A picker anchor is a calendar date, not a recorded activity timestamp.
        let anchorDay = calendar.startOfDay(for: filter.anchorDate)
        let current: DateInterval
        if let rawStart = filter.customStartDate,
           let rawEnd = filter.customEndDate {
            let firstDay = calendar.startOfDay(for: min(rawStart, rawEnd))
            let finalDay = calendar.startOfDay(for: max(rawStart, rawEnd))
            let exclusiveEnd = calendar.date(byAdding: .day, value: 1, to: finalDay)
                ?? finalDay.addingTimeInterval(86_400)
            current = DateInterval(start: firstDay, end: exclusiveEnd)
        } else {
            switch filter.period {
            case .week:
                current = calendar.dateInterval(of: .weekOfYear, for: anchorDay)
                    ?? DateInterval(start: anchorDay, duration: 7 * 86_400)
            case .month:
                current = calendar.dateInterval(of: .month, for: anchorDay)
                    ?? DateInterval(start: anchorDay, duration: 31 * 86_400)
            case .year:
                current = calendar.dateInterval(of: .year, for: anchorDay)
                    ?? DateInterval(start: anchorDay, duration: 365 * 86_400)
            }
        }

        let currentStart = calendar.startOfDay(for: current.start)
        let currentEnd = calendar.startOfDay(for: current.end)
        let previousStart: Date
        if filter.usesCustomRange {
            let dayCount = max(
                1,
                calendar.dateComponents([.day], from: currentStart, to: currentEnd).day ?? 1
            )
            previousStart = calendar.date(byAdding: .day, value: -dayCount, to: currentStart)
                ?? currentStart.addingTimeInterval(TimeInterval(-dayCount * 86_400))
        } else {
            previousStart = filter.period.offset(currentStart, by: -1, calendar: calendar)
        }
        let previousEnd = currentStart

        return StatisticsPeriodBounds(
            currentStart: currentStart,
            currentEnd: currentEnd,
            previousStart: previousStart,
            previousEnd: previousEnd,
            fetchInterval: DateInterval(
                start: dayBoundary.interval(for: previousStart, calendar: calendar).start,
                end: dayBoundary.interval(
                    for: calendar.date(byAdding: .day, value: -1, to: currentEnd) ?? currentEnd,
                    calendar: calendar
                ).end
            )
        )
    }

    nonisolated func build(
        flowRecords: [StatisticsPeriodFlowRecord],
        achievementRecords: [StatisticsPeriodAchievementRecord],
        filter: StatisticsPeriodFilter,
        habitRecords: [HabitCompletionRecord] = [],
        now: Date = .now
    ) -> StatisticsPeriodSnapshot {
        let input = prepare(
            flowRecords: flowRecords, achievementRecords: achievementRecords,
            filter: filter, habitRecords: habitRecords, now: now
        )
        return makeSnapshot(
            for: input, summary: summary(for: input), trend: trend(for: input),
            distribution: distribution(for: input), habits: habits(for: input),
            days: days(for: input), dailyFocus: dailyFocus(for: input),
            estimateAccuracy: estimateAccuracy(for: input), csvRows: csvRows(for: input)
        )
    }

    nonisolated struct ReportInput: Sendable {
        let filter: StatisticsPeriodFilter
        let bounds: StatisticsPeriodBounds
        let currentFlows: [StatisticsPeriodFlowRecord]
        let previousFlows: [StatisticsPeriodFlowRecord]
        let currentAchievements: [StatisticsPeriodAchievementRecord]
        let previousAchievements: [StatisticsPeriodAchievementRecord]
        let habitRecords: [HabitCompletionRecord]
        let today: Date
    }

    nonisolated func prepare(
        flowRecords: [StatisticsPeriodFlowRecord],
        achievementRecords: [StatisticsPeriodAchievementRecord],
        filter: StatisticsPeriodFilter,
        habitRecords: [HabitCompletionRecord],
        now: Date = .now
    ) -> ReportInput {
        let periodBounds = bounds(for: filter)
        var currentFlows: [StatisticsPeriodFlowRecord] = []
        var previousFlows: [StatisticsPeriodFlowRecord] = []
        var currentAchievements: [StatisticsPeriodAchievementRecord] = []
        var previousAchievements: [StatisticsPeriodAchievementRecord] = []
        for record in flowRecords where matchesArea(record.areaID, filter: filter) && matchesQuery(record, query: filter.query) {
            let day = dayBoundary.day(containing: record.startedAt, calendar: calendar)
            if periodBounds.containsCurrent(day) {
                currentFlows.append(record)
            } else if periodBounds.containsPrevious(day) {
                previousFlows.append(record)
            }
        }
        for record in achievementRecords where matchesArea(record.areaID, filter: filter) && matchesQuery(record, query: filter.query) {
            let day = dayBoundary.day(containing: record.completedAt, calendar: calendar)
            if periodBounds.containsCurrent(day) {
                currentAchievements.append(record)
            } else if periodBounds.containsPrevious(day) {
                previousAchievements.append(record)
            }
        }
        return ReportInput(
            filter: filter, bounds: periodBounds,
            currentFlows: currentFlows, previousFlows: previousFlows,
            currentAchievements: currentAchievements, previousAchievements: previousAchievements,
            habitRecords: habitRecords, today: dayBoundary.day(containing: now, calendar: calendar)
        )
    }

    nonisolated func summary(for input: ReportInput) -> StatisticsPresentationSummary {
        StatisticsPresentationSummary(
            summary: makeSummary(flows: input.currentFlows, achievements: input.currentAchievements),
            previousSummary: makeSummary(flows: input.previousFlows, achievements: input.previousAchievements)
        )
    }

    nonisolated func trend(for input: ReportInput) -> StatisticsPresentationTrend {
        let period = trendPeriod(for: input.filter, bounds: input.bounds)
        return StatisticsPresentationTrend(
            period: period,
            points: makeTrend(
                period: period, bounds: input.bounds,
                currentFlows: input.currentFlows, previousFlows: input.previousFlows,
                currentAchievements: input.currentAchievements, previousAchievements: input.previousAchievements
            )
        )
    }

    nonisolated func distribution(for input: ReportInput) -> StatisticsPresentationDistribution {
        StatisticsPresentationDistribution(
            task: makeDistribution(flows: input.currentFlows, dimension: .task),
            area: makeDistribution(flows: input.currentFlows, dimension: .area),
            project: makeDistribution(flows: input.currentFlows, dimension: .project),
            totalFocusSeconds: input.currentFlows.reduce(0) { $0 + max(0, $1.focusSeconds) }
        )
    }

    nonisolated func habits(for input: ReportInput) -> HabitCompletionSummary {
        HabitCompletionBuilder().build(
            records: input.habitRecords, filter: input.filter, bounds: input.bounds, today: input.today
        )
    }

    nonisolated func days(for input: ReportInput) -> StatisticsPresentationDays {
        let dates = dates(from: input.bounds.currentStart, to: input.bounds.currentEnd)
        return StatisticsPresentationDays(
            flow: makeFlowDays(days: dates, flows: input.currentFlows),
            achievement: makeAchievementDays(days: dates, achievements: input.currentAchievements)
        )
    }

    nonisolated func dailyFocus(for input: ReportInput) -> [StatisticsDailyFocusPoint] {
        var secondsByDay: [Date: Int] = [:]
        for flow in input.currentFlows {
            let day = dayBoundary.day(containing: flow.startedAt, calendar: calendar)
            secondsByDay[day, default: 0] += max(0, flow.focusSeconds)
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: input.today) ?? input.today
        let end = min(input.bounds.currentEnd, tomorrow)
        return dates(from: input.bounds.currentStart, to: end).map { day in
            StatisticsDailyFocusPoint(date: day, focusSeconds: secondsByDay[day, default: 0])
        }
    }

    nonisolated func estimateAccuracy(for input: ReportInput) -> StatisticsEstimateAccuracy {
        var planned = 0.0
        var actual = 0.0
        var matched = 0.0
        var compared = 0.0
        var countedTasks: Set<UUID> = []
        for task in input.currentAchievements {
            guard let estimate = task.timeEstimate,
                  estimate.plannedSeconds > 0, estimate.actualSeconds > 0,
                  countedTasks.insert(task.todoID).inserted else { continue }
            planned += estimate.plannedSeconds
            actual += estimate.actualSeconds
            matched += min(estimate.plannedSeconds, estimate.actualSeconds)
            compared += max(estimate.plannedSeconds, estimate.actualSeconds)
        }
        return StatisticsEstimateAccuracy(
            plannedSeconds: planned, actualSeconds: actual,
            rate: compared > 0 ? matched / compared : nil
        )
    }

    nonisolated func csvRows(for input: ReportInput) -> [StatisticsCSVRow] {
        makeCSVRows(flows: input.currentFlows, achievements: input.currentAchievements)
    }

    nonisolated func makeSnapshot(
        for input: ReportInput,
        summary: StatisticsPresentationSummary,
        trend: StatisticsPresentationTrend,
        distribution: StatisticsPresentationDistribution,
        habits: HabitCompletionSummary,
        days: StatisticsPresentationDays,
        dailyFocus: [StatisticsDailyFocusPoint],
        estimateAccuracy: StatisticsEstimateAccuracy,
        csvRows: [StatisticsCSVRow]
    ) -> StatisticsPeriodSnapshot {
        StatisticsPeriodSnapshot(
            filter: input.filter, bounds: input.bounds,
            summary: summary.summary, previousSummary: summary.previousSummary,
            trend: trend.points, trendPeriod: trend.period,
            dailyFocus: dailyFocus, estimateAccuracy: estimateAccuracy,
            taskDistribution: distribution.task, areaDistribution: distribution.area,
            projectDistribution: distribution.project, habitCompletion: habits,
            flowDays: days.flow, achievementDays: days.achievement, csvRows: csvRows
        )
    }

    nonisolated private func trendPeriod(
        for filter: StatisticsPeriodFilter,
        bounds: StatisticsPeriodBounds
    ) -> StatisticsPeriod {
        guard filter.usesCustomRange else { return filter.period }
        let dayCount = max(
            1,
            calendar.dateComponents(
                [.day],
                from: bounds.currentStart,
                to: bounds.currentEnd
            ).day ?? 1
        )
        if dayCount <= 14 { return .week }
        if dayCount <= 120 { return .month }
        return .year
    }

    nonisolated private func matchesArea(_ areaID: UUID?, filter: StatisticsPeriodFilter) -> Bool {
        guard !filter.areaIDs.isEmpty else { return true }
        guard let areaID else { return false }
        return filter.areaIDs.contains(areaID)
    }

    nonisolated private func matchesQuery(_ record: StatisticsPeriodFlowRecord, query: String) -> Bool {
        matchesQuery(
            query,
            candidates: [
                record.todoTitle,
                record.todoNotes,
                record.todoHashtags.joined(separator: " "),
                record.areaName,
                record.areaSymbol,
                record.intent,
                record.result
            ]
        )
    }

    nonisolated private func matchesQuery(_ record: StatisticsPeriodAchievementRecord, query: String) -> Bool {
        matchesQuery(
            query,
            candidates: [
                record.todoTitle,
                record.todoNotes,
                record.todoHashtags.joined(separator: " "),
                record.areaName,
                record.areaSymbol
            ]
        )
    }

    nonisolated private func matchesQuery(_ query: String, candidates: [String]) -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return true }
        return candidates.contains { $0.localizedCaseInsensitiveContains(term) }
    }

    nonisolated private func makeSummary(
        flows: [StatisticsPeriodFlowRecord],
        achievements: [StatisticsPeriodAchievementRecord]
    ) -> StatisticsPeriodSummary {
        StatisticsPeriodSummary(
            totalFocusSeconds: flows.reduce(0) { $0 + max(0, $1.focusSeconds) },
            flowCount: Set(flows.map(\.sessionID)).count,
            completedTaskCount: achievements.count,
            activeFlowDayCount: Set(flows.map {
                dayBoundary.day(containing: $0.startedAt, calendar: calendar)
            }).count
        )
    }

    nonisolated private func makeTrend(
        period: StatisticsPeriod,
        bounds: StatisticsPeriodBounds,
        currentFlows: [StatisticsPeriodFlowRecord],
        previousFlows: [StatisticsPeriodFlowRecord],
        currentAchievements: [StatisticsPeriodAchievementRecord],
        previousAchievements: [StatisticsPeriodAchievementRecord]
    ) -> [StatisticsTrendPoint] {
        let currentBuckets = trendBuckets(
            for: period,
            from: bounds.currentStart,
            to: bounds.currentEnd
        )
        let previousBuckets = trendBuckets(
            for: period,
            from: bounds.previousStart,
            to: bounds.previousEnd
        )

        return currentBuckets.enumerated().map { index, bucket in
            let comparisonBucket = previousBuckets.indices.contains(index)
                ? previousBuckets[index]
                : TrendBucket(start: bounds.previousStart, end: bounds.previousStart)
            return StatisticsTrendPoint(
                index: index,
                date: bucket.start,
                comparisonDate: comparisonBucket.start,
                focusSeconds: totalFocus(in: bucket, records: currentFlows),
                previousFocusSeconds: totalFocus(in: comparisonBucket, records: previousFlows),
                completedTaskCount: completionCount(in: bucket, records: currentAchievements),
                previousCompletedTaskCount: completionCount(
                    in: comparisonBucket,
                    records: previousAchievements
                ),
                hasComparison: previousBuckets.indices.contains(index)
            )
        }
    }

    private struct TrendBucket {
        let start: Date
        let end: Date

        nonisolated func contains(_ date: Date) -> Bool {
            date >= start && date < end
        }
    }

    nonisolated private func totalFocus(
        in bucket: TrendBucket,
        records: [StatisticsPeriodFlowRecord]
    ) -> Int {
        records.reduce(0) { result, record in
            let day = dayBoundary.day(containing: record.startedAt, calendar: calendar)
            return result + (bucket.contains(day) ? max(0, record.focusSeconds) : 0)
        }
    }

    nonisolated private func completionCount(
        in bucket: TrendBucket,
        records: [StatisticsPeriodAchievementRecord]
    ) -> Int {
        records.reduce(0) { result, record in
            let day = dayBoundary.day(containing: record.completedAt, calendar: calendar)
            return result + (bucket.contains(day) ? 1 : 0)
        }
    }

    nonisolated private func trendBuckets(
        for period: StatisticsPeriod,
        from start: Date,
        to end: Date
    ) -> [TrendBucket] {
        guard start < end else { return [] }

        let component: Calendar.Component
        let step: Int
        switch period {
        case .week:
            component = .day
            step = 1
        case .month:
            component = .day
            step = 1
        case .year:
            component = .month
            step = 1
        }

        var buckets: [TrendBucket] = []
        var bucketStart = start
        while bucketStart < end {
            let proposedEnd = calendar.date(
                byAdding: component,
                value: step,
                to: bucketStart
            ) ?? end
            let bucketEnd = proposedEnd < end ? proposedEnd : end
            buckets.append(TrendBucket(start: bucketStart, end: bucketEnd))
            guard bucketEnd > bucketStart else { break }
            bucketStart = bucketEnd
        }
        return buckets
    }

    private enum DistributionDimension {
        case task
        case area
        case project
    }

    private struct DistributionAccumulator {
        var name: String
        var symbol: String?
        var colors: [WeightedHexColor]
        var focusSeconds: Int
        var records: [StatisticsPeriodFlowRecord] = []
    }

    nonisolated private func makeDistribution(
        flows: [StatisticsPeriodFlowRecord],
        dimension: DistributionDimension
    ) -> [StatisticsDistributionItem] {
        var grouped: [String: DistributionAccumulator] = [:]

        for record in flows where record.focusSeconds > 0 {
            let key: String
            let name: String
            let symbol: String?
            switch dimension {
            case .task:
                let title = record.todoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                key = title.isEmpty ? "task:unassigned" : "task:\(title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))"
                name = title.isEmpty ? String(localized: "タスクなし") : title
                symbol = nil
            case .area:
                key = record.areaID.map { "area:\($0.uuidString)" } ?? "area:other"
                name = record.areaName.isEmpty ? String(localized: "その他") : record.areaName
                symbol = record.areaSymbol.isEmpty ? nil : record.areaSymbol
            case .project:
                key = record.projectID.map { "project:\($0.uuidString)" } ?? "project:unassigned"
                let projectName = record.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
                name = record.projectID == nil || projectName.isEmpty ? String(localized: "プロジェクトなし") : projectName
                symbol = record.areaSymbol.isEmpty ? nil : record.areaSymbol
            }

            var accumulator = grouped[key] ?? DistributionAccumulator(
                name: name,
                symbol: symbol,
                colors: [],
                focusSeconds: 0
            )
            accumulator.records.append(record)
            accumulator.focusSeconds += record.focusSeconds
            if let color = record.areaColorHex {
                accumulator.colors.append(WeightedHexColor(hex: color, weight: record.focusSeconds))
            }
            grouped[key] = accumulator
        }

        let sorted = grouped.map { key, value in
            StatisticsDistributionItem(
                id: key,
                name: value.name,
                symbol: value.symbol,
                colorHex: StatisticsHeatmapBuilder.mixedHexColor(value.colors),
                focusSeconds: value.focusSeconds,
                details: makeDistributionDetails(flows: value.records, dimension: dimension)
            )
        }.sorted {
            if $0.focusSeconds != $1.focusSeconds { return $0.focusSeconds > $1.focusSeconds }
            let nameOrder = $0.name.localizedStandardCompare($1.name)
            return nameOrder == .orderedSame ? $0.id < $1.id : nameOrder == .orderedAscending
        }

        guard sorted.count > 6 else { return sorted }
        let visible = Array(sorted.prefix(5))
        let remainder = Array(sorted.dropFirst(5))
        let remainderSeconds = remainder.reduce(0) { $0 + $1.focusSeconds }
        let colors = remainder.compactMap { item -> WeightedHexColor? in
            guard let color = item.colorHex else { return nil }
            return WeightedHexColor(hex: color, weight: item.focusSeconds)
        }
        return visible + [StatisticsDistributionItem(
            id: "distribution:other",
            name: String(localized: "その他"),
            symbol: nil,
            colorHex: StatisticsHeatmapBuilder.mixedHexColor(colors),
            focusSeconds: remainderSeconds,
            details: makeDistributionDetails(
                flows: remainder.flatMap { grouped[$0.id]?.records ?? [] },
                dimension: dimension
            )
        )]
    }

    nonisolated private func makeDistributionDetails(
        flows: [StatisticsPeriodFlowRecord],
        dimension: DistributionDimension
    ) -> [StatisticsDistributionDetail] {
        switch dimension {
        case .task:
            let days = Dictionary(grouping: flows) {
                dayBoundary.day(containing: $0.startedAt, calendar: calendar)
            }
            return days.keys.sorted().map { day in
                StatisticsDistributionDetail(
                    id: "day:\(day.timeIntervalSinceReferenceDate)", date: day, name: "",
                    focusSeconds: days[day, default: []].reduce(0) { $0 + $1.focusSeconds }
                )
            }
        case .project:
            // Projects and their Tasks are grouped by stable identity, including
            // same-named and unnamed Tasks. Legacy Area-only Flow has no Task.
            let tasks = Dictionary(grouping: flows) { $0.todoID?.uuidString ?? "unassigned" }
            return tasks.map { key, records in
                let record = records[0]
                let title = record.todoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let projectName = record.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
                let fallback = record.todoID != nil && !projectName.isEmpty
                    ? projectName : String(localized: "タスクなし")
                return StatisticsDistributionDetail(
                    id: "task:\(key)", date: nil, name: title.isEmpty ? fallback : title,
                    focusSeconds: records.reduce(0) { $0 + $1.focusSeconds }
                )
            }.sorted {
                if $0.focusSeconds != $1.focusSeconds { return $0.focusSeconds > $1.focusSeconds }
                if $0.name != $1.name { return $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                return $0.id < $1.id
            }
        case .area:
            let tasks = Dictionary(grouping: flows) {
                $0.todoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            }
            return tasks.map { key, records in
                let title = records[0].todoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                return StatisticsDistributionDetail(
                    id: "task:\(key)", date: nil,
                    name: title.isEmpty ? String(localized: "タスクなし") : title,
                    focusSeconds: records.reduce(0) { $0 + $1.focusSeconds }
                )
            }.sorted {
                if $0.focusSeconds != $1.focusSeconds { return $0.focusSeconds > $1.focusSeconds }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }
    }

    nonisolated private func makeFlowDays(
        days: [Date],
        flows: [StatisticsPeriodFlowRecord]
    ) -> [StatisticsDay] {
        let grouped = Dictionary(grouping: flows) {
            dayBoundary.day(containing: $0.startedAt, calendar: calendar)
        }
        return days.map { date in
            let records = grouped[date] ?? []
            return StatisticsDay(
                date: date,
                totalFocusSeconds: records.reduce(0) { $0 + max(0, $1.focusSeconds) },
                mixedColorHex: StatisticsHeatmapBuilder.mixedHexColor(records.compactMap {
                    guard let color = $0.areaColorHex else { return nil }
                    return WeightedHexColor(hex: color, weight: $0.focusSeconds)
                }),
                areaCount: Set(records.compactMap(\.areaID)).count,
                sessionCount: Set(records.map(\.sessionID)).count
            )
        }
    }

    nonisolated private func makeAchievementDays(
        days: [Date],
        achievements: [StatisticsPeriodAchievementRecord]
    ) -> [AchievementDay] {
        let grouped = Dictionary(grouping: achievements) {
            dayBoundary.day(containing: $0.completedAt, calendar: calendar)
        }
        return days.map { date in
            let records = grouped[date] ?? []
            return AchievementDay(
                date: date,
                completedCount: records.count,
                mixedColorHex: StatisticsHeatmapBuilder.mixedHexColor(records.compactMap {
                    guard let color = $0.areaColorHex else { return nil }
                    return WeightedHexColor(hex: color, weight: 1)
                }),
                areaCount: Set(records.compactMap(\.areaID)).count
            )
        }
    }

    nonisolated private struct CSVKey: Hashable {
        let day: Date
        let task: String
        let area: String

        nonisolated static func == (lhs: CSVKey, rhs: CSVKey) -> Bool {
            lhs.day == rhs.day && lhs.task == rhs.task && lhs.area == rhs.area
        }

        nonisolated func hash(into hasher: inout Hasher) {
            hasher.combine(day)
            hasher.combine(task)
            hasher.combine(area)
        }
    }

    private struct CSVAccumulator {
        var task: String
        var area: String
        var hashtags: Set<String>
        var focusedSeconds: Int
        var sessionIDs: Set<UUID>
        var completedTaskCount: Int
    }

    nonisolated private func makeCSVRows(
        flows: [StatisticsPeriodFlowRecord],
        achievements: [StatisticsPeriodAchievementRecord]
    ) -> [StatisticsCSVRow] {
        var grouped: [CSVKey: CSVAccumulator] = [:]

        for record in flows {
            let day = dayBoundary.day(containing: record.startedAt, calendar: calendar)
            let task = record.todoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let area = record.areaName.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = CSVKey(day: day, task: normalized(task), area: normalized(area))
            var value = grouped[key] ?? CSVAccumulator(
                task: task,
                area: area,
                hashtags: [],
                focusedSeconds: 0,
                sessionIDs: [],
                completedTaskCount: 0
            )
            value.focusedSeconds += max(0, record.focusSeconds)
            value.sessionIDs.insert(record.sessionID)
            value.hashtags.formUnion(record.todoHashtags)
            grouped[key] = value
        }

        for record in achievements {
            let day = dayBoundary.day(containing: record.completedAt, calendar: calendar)
            let task = record.todoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let area = record.areaName.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = CSVKey(day: day, task: normalized(task), area: normalized(area))
            var value = grouped[key] ?? CSVAccumulator(
                task: task,
                area: area,
                hashtags: [],
                focusedSeconds: 0,
                sessionIDs: [],
                completedTaskCount: 0
            )
            value.completedTaskCount += 1
            value.hashtags.formUnion(record.todoHashtags)
            grouped[key] = value
        }

        return grouped.map { key, value in
            StatisticsCSVRow(
                date: key.day,
                task: value.task,
                area: value.area,
                hashtags: value.hashtags.sorted { $0.localizedStandardCompare($1) == .orderedAscending },
                focusedSeconds: value.focusedSeconds,
                flowCount: value.sessionIDs.count,
                completedTaskCount: value.completedTaskCount
            )
        }.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.task != $1.task { return $0.task.localizedStandardCompare($1.task) == .orderedAscending }
            return $0.area.localizedStandardCompare($1.area) == .orderedAscending
        }
    }

    nonisolated private func normalized(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    nonisolated private func dates(from start: Date, to end: Date) -> [Date] {
        guard start < end else { return [] }
        var result: [Date] = []
        var date = start
        while date < end {
            result.append(date)
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return result
    }

}
