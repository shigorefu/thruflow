#if os(macOS)
import SwiftUI

struct TasksSearchResults<Row: View>: View {
    @Environment(\.locale) private var locale

    let searchText: String
    let searchSections: [DatabaseTaskSearchSection]
    @ViewBuilder let row: (Todo) -> Row

    @ViewBuilder
    var body: some View {
        if searchSections.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(searchSections) { section in
                    Section {
                        ForEach(section.todos) { todo in
                            row(todo)
                        }
                    } header: {
                        searchSectionTitle(section)
                    }
                    .listSectionSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private func searchSectionTitle(_ section: DatabaseTaskSearchSection) -> some View {
        if let date = section.date {
            Text(date, format: .dateTime.locale(locale).year().month().day().weekday())
        } else {
            Label(String(localized: "日付なし"), systemImage: "tray")
        }
    }
}
#endif
