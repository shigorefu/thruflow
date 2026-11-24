#if os(macOS)
import SwiftUI

struct StatisticsExportPopover: View {
    @Binding var exportContent: StatisticsCSVContent
    @Binding var exportStartDate: Date
    @Binding var exportEndDate: Date
    @Binding var exportAreaIDs: Set<UUID>
    @Binding var exportQuery: String
    let today: Date
    let activeAreas: [Area]
    let isPreparingExport: Bool
    let exportShareURL: URL?
    let preparedExportConfiguration: StatisticsExportConfiguration?
    let exportConfiguration: StatisticsExportConfiguration
    let prepareExportShareURL: (StatisticsExportConfiguration) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "CSVを書き出す"))
                .font(.headline)

            Picker(String(localized: "書き出す内容"), selection: $exportContent) {
                ForEach(StatisticsCSVContent.allCases) { content in
                    Text(content.displayName).tag(content)
                }
            }
            .pickerStyle(.segmented)

            DatePicker(
                String(localized: "開始日"),
                selection: $exportStartDate,
                in: ...today,
                displayedComponents: .date
            )
            .datePickerStyle(.field)
            DatePicker(
                String(localized: "終了日"),
                selection: $exportEndDate,
                in: ...today,
                displayedComponents: .date
            )
            .datePickerStyle(.field)

            StatisticsAreaSelectionMenu(
                selectedAreaIDs: $exportAreaIDs,
                areas: activeAreas,
                showsSelection: true
            )

            TextField(String(localized: "検索"), text: $exportQuery)
                .textFieldStyle(.roundedBorder)

            Divider()

            HStack {
                if isPreparingExport {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                if let exportShareURL,
                   preparedExportConfiguration == exportConfiguration {
                    ShareLink(item: exportShareURL) {
                        Label(String(localized: "CSVを書き出す"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {} label: {
                        Label(String(localized: "CSVを書き出す"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
                }
            }
        }
        .padding(16)
        .frame(width: 340)
        .task(id: exportConfiguration) {
            await prepareExportShareURL(exportConfiguration)
        }
        .onChange(of: exportStartDate) { _, newValue in
            if exportEndDate < newValue {
                exportEndDate = newValue
            }
        }
    }
}
#endif
