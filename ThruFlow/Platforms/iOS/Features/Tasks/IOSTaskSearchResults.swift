#if os(iOS)
import SwiftUI

struct IOSTaskSearchResults: View {
    let searchText: String
    let sections: [DatabaseTaskSearchSection]
    let onEditTodo: (Todo) -> Void

    @ViewBuilder
    var body: some View {
        if sections.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            searchSectionTitle(section)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(section.todos) { todo in
                                IOSTaskRow(todo: todo) {
                                    onEditTodo(todo)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 9)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(14)
                        .background(
                            Color.primary.opacity(0.035),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                }
                .padding(12)
            }
        }
    }

    @ViewBuilder
    private func searchSectionTitle(_ section: DatabaseTaskSearchSection) -> some View {
        if let date = section.date {
            Text(date, format: .dateTime.year().month().day().weekday())
        } else {
            Label(String(localized: "日付なし"), systemImage: "tray")
        }
    }
}
#endif
