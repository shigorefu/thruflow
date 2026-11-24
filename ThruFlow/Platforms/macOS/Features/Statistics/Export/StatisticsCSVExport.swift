#if os(macOS)
import Foundation

extension StatisticsCSVContent {
    var displayName: String {
        switch self {
        case .all:
            String(localized: "すべて")
        case .flow:
            String(localized: "集中記録")
        case .task:
            String(localized: "タスク")
        }
    }
}

struct StatisticsExportConfiguration: Hashable, Sendable {
    let content: StatisticsCSVContent
    let filter: StatisticsPeriodFilter
}

struct StatisticsCSVTemporaryFileWriter {
    nonisolated init() {}

    nonisolated func write(csv: String, filename: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ThruFlow Statistics", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let url = directory.appendingPathComponent(filename)
        try Data(csv.utf8).write(to: url, options: .atomic)
        return url
    }
}
#endif
