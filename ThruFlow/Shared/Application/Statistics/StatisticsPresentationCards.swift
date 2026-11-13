import Foundation

enum StatisticsPresentationUpdate: Sendable {
    case summary(StatisticsPresentationSummary)
    case trend(StatisticsPresentationTrend)
    case dailyFocus([StatisticsDailyFocusPoint])
    case estimateAccuracy(StatisticsEstimateAccuracy)
    case distribution(StatisticsPresentationDistribution)
    case habits(HabitCompletionSummary)
    case days(StatisticsPresentationDays)
    case report(StatisticsPeriodSnapshot)
}

nonisolated struct StatisticsPresentationCards: Sendable {
    private(set) var summary: StatisticsPresentationSummary?
    private(set) var trend: StatisticsPresentationTrend?
    private(set) var dailyFocus: [StatisticsDailyFocusPoint]?
    private(set) var estimateAccuracy: StatisticsEstimateAccuracy?
    private(set) var distribution: StatisticsPresentationDistribution?
    private(set) var habits: HabitCompletionSummary?
    private(set) var days: StatisticsPresentationDays?

    init() {}

    init(snapshot: StatisticsPeriodSnapshot) {
        summary = StatisticsPresentationSummary(
            summary: snapshot.summary, previousSummary: snapshot.previousSummary
        )
        trend = StatisticsPresentationTrend(period: snapshot.trendPeriod, points: snapshot.trend)
        dailyFocus = snapshot.dailyFocus
        estimateAccuracy = snapshot.estimateAccuracy
        distribution = StatisticsPresentationDistribution(
            task: snapshot.taskDistribution, area: snapshot.areaDistribution,
            project: snapshot.projectDistribution, totalFocusSeconds: snapshot.summary.totalFocusSeconds
        )
        habits = snapshot.habitCompletion
        days = StatisticsPresentationDays(flow: snapshot.flowDays, achievement: snapshot.achievementDays)
    }

    mutating func apply(_ update: StatisticsPresentationUpdate) {
        switch update {
        case .summary(let value): summary = value
        case .trend(let value): trend = value
        case .dailyFocus(let value): dailyFocus = value
        case .estimateAccuracy(let value): estimateAccuracy = value
        case .distribution(let value): distribution = value
        case .habits(let value): habits = value
        case .days(let value): days = value
        case .report(let snapshot): self = Self(snapshot: snapshot)
        }
    }
}
