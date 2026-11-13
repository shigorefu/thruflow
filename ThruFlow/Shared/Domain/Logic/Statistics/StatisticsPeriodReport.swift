import Foundation

struct StatisticsPeriodFlowRecord: Equatable, Sendable {
    let sessionID: UUID
    let startedAt: Date
    let focusSeconds: Int
    let areaID: UUID?
    let areaName: String
    let areaSymbol: String
    let areaColorHex: String?
    let todoID: UUID?
    let todoTitle: String
    let todoHashtags: [String]
    let todoNotes: String
    let intent: String
    let result: String
    var projectID: UUID? = nil
    var projectName: String = ""
}

struct StatisticsPeriodAchievementRecord: Equatable, Sendable {
    let completedAt: Date
    let todoID: UUID
    let todoTitle: String
    let todoHashtags: [String]
    let todoNotes: String
    let areaID: UUID?
    let areaName: String
    let areaSymbol: String
    let areaColorHex: String?
    var timeEstimate: StatisticsTaskTimeEstimate? = nil
}

struct StatisticsTaskTimeEstimate: Equatable, Sendable {
    let plannedSeconds: Double
    let actualSeconds: Double
}

struct StatisticsPeriodSummary: Equatable, Sendable {
    let totalFocusSeconds: Int
    let flowCount: Int
    let completedTaskCount: Int
    let activeFlowDayCount: Int

    nonisolated var totalBlocks: Double {
        BlockUnit.blocks(forFocusedSeconds: totalFocusSeconds)
    }
}

struct StatisticsPresentationSummary: Equatable, Sendable {
    let summary: StatisticsPeriodSummary
    let previousSummary: StatisticsPeriodSummary
}

struct StatisticsPresentationTrend: Equatable, Sendable {
    let period: StatisticsPeriod
    let points: [StatisticsTrendPoint]
}

struct StatisticsPresentationDistribution: Equatable, Sendable {
    let task: [StatisticsDistributionItem]
    let area: [StatisticsDistributionItem]
    let project: [StatisticsDistributionItem]
    let totalFocusSeconds: Int
}

struct StatisticsPresentationDays: Equatable, Sendable {
    let flow: [StatisticsDay]
    let achievement: [AchievementDay]
}

struct StatisticsDailyFocusPoint: Identifiable, Equatable, Sendable {
    let date: Date
    let focusSeconds: Int

    var id: Date { date }
}

struct StatisticsEstimateAccuracy: Equatable, Sendable {
    let plannedSeconds: Double
    let actualSeconds: Double
    let rate: Double?
}

struct StatisticsTrendPoint: Identifiable, Equatable, Sendable {
    let index: Int
    let date: Date
    let comparisonDate: Date
    let focusSeconds: Int
    let previousFocusSeconds: Int
    let completedTaskCount: Int
    let previousCompletedTaskCount: Int
    var hasComparison: Bool = true

    var id: Int { index }
}

struct StatisticsDistributionDetail: Identifiable, Equatable, Sendable {
    let id: String
    let date: Date?
    let name: String
    let focusSeconds: Int
}

struct StatisticsDistributionItem: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let symbol: String?
    let colorHex: String?
    let focusSeconds: Int
    var details: [StatisticsDistributionDetail] = []
}

struct StatisticsCSVRow: Equatable, Sendable {
    let date: Date
    let task: String
    let area: String
    let hashtags: [String]
    let focusedSeconds: Int
    let flowCount: Int
    let completedTaskCount: Int

    nonisolated var focusedMinutes: Double {
        Double(focusedSeconds) / 60
    }

    nonisolated var blocks: Double {
        BlockUnit.blocks(forFocusedSeconds: focusedSeconds)
    }
}

struct StatisticsPeriodSnapshot: Equatable, Sendable {
    let filter: StatisticsPeriodFilter
    let bounds: StatisticsPeriodBounds
    let summary: StatisticsPeriodSummary
    let previousSummary: StatisticsPeriodSummary
    let trend: [StatisticsTrendPoint]
    let trendPeriod: StatisticsPeriod
    let dailyFocus: [StatisticsDailyFocusPoint]
    let estimateAccuracy: StatisticsEstimateAccuracy
    let taskDistribution: [StatisticsDistributionItem]
    let areaDistribution: [StatisticsDistributionItem]
    let projectDistribution: [StatisticsDistributionItem]
    let habitCompletion: HabitCompletionSummary
    let flowDays: [StatisticsDay]
    let achievementDays: [AchievementDay]
    let csvRows: [StatisticsCSVRow]
}
