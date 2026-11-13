#if os(macOS)
import SwiftUI

struct WeekdaySelectionView: View {
    @Binding var selection: Int?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(GoalWeekday.allCases) { weekday in
                Button {
                    toggle(weekday)
                } label: {
                    Text(weekday.displayName)
                        .font(.body.weight(isSelected(weekday) ? .semibold : .regular))
                        .frame(width: 34, height: 30)
                        .background(isSelected(weekday) ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(weekday.displayName)
                .accessibilityAddTraits(isSelected(weekday) ? [.isSelected] : [])
            }
        }
    }

    private func isSelected(_ weekday: GoalWeekday) -> Bool {
        ((selection ?? 0) & weekday.rawValue) != 0
    }

    private func toggle(_ weekday: GoalWeekday) {
        var mask = selection ?? 0

        if isSelected(weekday) {
            mask &= ~weekday.rawValue
        } else {
            mask |= weekday.rawValue
        }

        selection = mask == 0 ? nil : mask
    }
}
#endif
