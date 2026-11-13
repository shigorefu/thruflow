#if os(iOS)
import SwiftUI

struct IOSStatisticsExportSheet: View {
    @Binding var exportContent: StatisticsCSVContent
    @Binding var exportStartDate: Date
    @Binding var exportEndDate: Date
    @Binding var exportAreaIDs: Set<UUID>
    @Binding var exportQuery: String

    let maximumDate: Date
    let activeAreas: [Area]
    let exportConfiguration: IOSStatisticsExportConfiguration
    let exportShareURL: URL?
    let isPreparingExport: Bool
    let onClose: () -> Void
    let onPrepareExport: (IOSStatisticsExportConfiguration) async -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(String(localized: "書き出す内容"), selection: $exportContent) {
                        ForEach(StatisticsCSVContent.allCases) { content in
                            Text(content.iosDisplayName).tag(content)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    DatePicker(
                        String(localized: "開始日"),
                        selection: $exportStartDate,
                        in: ...maximumDate,
                        displayedComponents: .date
                    )
                    DatePicker(
                        String(localized: "終了日"),
                        selection: $exportEndDate,
                        in: ...maximumDate,
                        displayedComponents: .date
                    )
                }

                Section {
                    StatisticsAreaSelectionMenu(
                        selectedAreaIDs: $exportAreaIDs,
                        areas: activeAreas,
                        showsSelection: true
                    )

                    TextField(String(localized: "検索"), text: $exportQuery)
                }

                Section {
                    HStack {
                        if isPreparingExport {
                            ProgressView()
                        }
                        Spacer()
                        if let exportShareURL {
                            ShareLink(item: exportShareURL) {
                                Label(
                                    String(localized: "CSVを書き出す"),
                                    systemImage: "square.and.arrow.up"
                                )
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Label(
                                String(localized: "CSVを書き出す"),
                                systemImage: "square.and.arrow.up"
                            )
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .iosCenteredNavigationTitle(String(localized: "CSVを書き出す"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "閉じる")) {
                        onClose()
                    }
                }
            }
            .task(id: exportConfiguration) {
                await onPrepareExport(exportConfiguration)
            }
            .onChange(of: exportStartDate) { _, newValue in
                if exportEndDate < newValue {
                    exportEndDate = newValue
                }
            }
        }
    }
}

private extension StatisticsCSVContent {
    var iosDisplayName: String {
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

struct IOSStatisticsExportConfiguration: Hashable, Sendable {
    let content: StatisticsCSVContent
    let filter: StatisticsPeriodFilter
}

struct IOSStatisticsCSVTemporaryFileWriter {
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
