#if os(macOS)
import SwiftUI

struct StatisticsYearPicker: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Binding var selectedDate: Date

    private var selectedYear: Int { calendar.component(.year, from: selectedDate) }
    private var currentYear: Int { calendar.component(.year, from: .now) }
    private var years: [Int] {
        let lower = min(selectedYear, currentYear - 9)
        return Array((lower...currentYear).reversed())
    }

    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(years, id: \.self) { year in
                Button {
                    select(year)
                } label: {
                    HStack {
                        Text(label(for: year))
                            .font(.callout.weight(year == selectedYear ? .semibold : .regular))
                        Spacer()
                        if year == currentYear {
                            Text(String(localized: "今年"))
                                .font(.caption)
                                .foregroundStyle(year == selectedYear ? Color.white.opacity(0.82) : .secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .foregroundStyle(year == selectedYear ? Color.white : Color.primary)
                    .background(year == selectedYear ? Color.accentColor : Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(year == selectedYear ? .isSelected : [])
            }
        }
    }

    private func select(_ year: Int) {
        guard let date = date(for: year) else { return }
        selectedDate = calendar.startOfDay(for: date)
    }

    private func label(for year: Int) -> String {
        date(for: year)?.formatted(.dateTime.locale(locale).year()) ?? String(year)
    }

    private func date(for year: Int) -> Date? {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = 1
        components.day = 1
        return components.date
    }
}
#endif
