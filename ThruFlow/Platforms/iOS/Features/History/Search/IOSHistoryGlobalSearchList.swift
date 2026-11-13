#if os(iOS)
import SwiftUI

struct IOSHistoryGlobalSearchList: View {
    let items: [HistoryCalendarItem]
    let searchText: String
    @Binding var selection: HistoryCalendarItem?

    var body: some View {
        if items.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(items) { item in
                        Button {
                            selection = item
                        } label: {
                            IOSHistoryGlobalSearchRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
    }
}

private struct IOSHistoryGlobalSearchRow: View {
    @Environment(\.locale) private var locale
    let item: HistoryCalendarItem

    var body: some View {
        HStack(spacing: 12) {
            Text(item.symbol)
                .font(.title3)
                .frame(width: 38, height: 38)
                .background(
                    Color(hex: item.colorHex).opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 8)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(item.startedAt, format: .dateTime.locale(locale).year().month().day())
                    .font(.caption.weight(.semibold))
                Text(item.startedAt, format: .dateTime.locale(locale).hour().minute())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
    }
}
#endif
