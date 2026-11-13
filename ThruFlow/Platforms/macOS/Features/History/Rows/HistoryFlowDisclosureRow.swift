#if os(macOS)
import SwiftData
import SwiftUI

struct HistoryFlowDisclosureRow: View {
    @Environment(\.locale) private var locale

    let flow: DayHistoryFlow
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: flow.areaColorHex))
                    .frame(width: 4, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(flow.taskTitle)
                        .font(.callout)
                        .lineLimit(1)
                    Text("\(time(flow.startedAt))–\(time(flow.endedAt))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(duration(flow.focusSeconds))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, 56)
        .padding(.trailing, 12)
        .padding(.vertical, 7)
        .accessibilityLabel(String(localized: "集中記録を編集"))
    }

    private func time(_ date: Date) -> String {
        date.formatted(.dateTime.locale(locale).hour().minute())
    }

    private func duration(_ seconds: Int) -> String {
        String(localized: "\(max(0, seconds) / 60)分")
    }
}
#endif
