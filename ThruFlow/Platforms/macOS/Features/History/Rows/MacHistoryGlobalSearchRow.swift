#if os(macOS)
import SwiftUI

struct MacHistoryGlobalSearchRow: View {
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
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
#endif
