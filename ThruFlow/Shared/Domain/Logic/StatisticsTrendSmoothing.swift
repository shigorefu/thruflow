import Foundation

struct StatisticsSmoothedPoint: Identifiable, Equatable, Sendable {
    let index: Int
    let focusMinutes: Double
    let completedTasks: Double
    var id: Int { index }
}

/// Trailing means include recorded zero days, exclude future buckets, and use
/// only the available portion of the selected period at its leading edge.
nonisolated enum StatisticsTrendSmoothing {
    static func build(points: [StatisticsTrendPoint], period: StatisticsPeriod, today: Date) -> [StatisticsSmoothedPoint] {
        let elapsed = points.filter { $0.date <= today }
        let window = period == .year ? 3 : 7
        return elapsed.indices.map { index in
            let values = elapsed[max(0, index - window + 1)...index]
            return StatisticsSmoothedPoint(index: elapsed[index].index,
                focusMinutes: values.reduce(0.0) { $0 + Double($1.focusSeconds) / 60 } / Double(values.count),
                completedTasks: values.reduce(0.0) { $0 + Double($1.completedTaskCount) } / Double(values.count))
        }
    }
}
