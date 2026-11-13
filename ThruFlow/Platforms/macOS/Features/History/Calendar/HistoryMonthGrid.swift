#if os(macOS)
import SwiftData
import SwiftUI

struct HistoryMonthGrid: View {
    @Environment(\.calendar) private var calendar

    @Binding var selectedDate: Date
    let items: [HistoryCalendarItem]
    let onSelect: (HistoryCalendarItem) -> Void
    let onShowDay: (Date) -> Void
    let onMove: (HistoryCalendarItem, Date) -> Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var days: [Date] {
        guard let month = calendar.dateInterval(of: .month, for: selectedDate),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: month.start) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: firstWeek.start) }
    }

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = max(700, geometry.size.width)
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    LazyVGrid(columns: columns, spacing: 0) {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                    }

                    GeometryReader { monthGeometry in
                        let cellHeight = max(76, monthGeometry.size.height / 6)
                        ScrollView(.vertical) {
                            LazyVGrid(columns: columns, spacing: 0) {
                                ForEach(days, id: \.self) { day in
                                    monthCell(day, height: cellHeight)
                                }
                            }
                        }
                    }
                }
                .frame(width: contentWidth, height: geometry.size.height)
            }
            .scrollIndicators(.automatic)
        }
    }

    private func monthCell(_ day: Date, height: CGFloat) -> some View {
        let dayItems = items.filter {
            calendar.isDate($0.startedAt, inSameDayAs: day)
        }
        return VStack(alignment: .leading, spacing: 3) {
            Button {
                selectedDate = calendar.startOfDay(for: day)
            } label: {
                Text("\(calendar.component(.day, from: day))")
                    .font(.callout.weight(calendar.isDateInToday(day) ? .bold : .regular))
                    .foregroundStyle(calendar.isDateInToday(day) ? Color.white : dayTextColor(day))
                    .frame(width: 25, height: 25)
                    .background(calendar.isDateInToday(day) ? Color.accentColor : Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            ForEach(dayItems.prefix(3)) { item in
                let button = Button { onSelect(item) } label: {
                    HStack(spacing: 3) {
                        Circle().fill(item.kind == .rest ? Color.secondary : Color(hex: item.colorHex)).frame(width: 5, height: 5)
                        Text(item.title).lineLimit(1)
                    }
                    .font(.caption2)
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                if item.kind == .flow {
                    button.draggable("history-flow:\(item.id)")
                } else {
                    button
                }
            }

            if dayItems.count > 3 {
                Button {
                    onShowDay(day)
                } label: {
                    HStack(spacing: 5) {
                        Text(String(localized: "詳細"))

                        Text("\(dayItems.count)")
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .background(calendar.isDate(day, inSameDayAs: selectedDate) ? Color.accentColor.opacity(0.05) : .clear)
        .overlay { Rectangle().stroke(Color.secondary.opacity(0.13), lineWidth: 0.5) }
        .dropDestination(for: String.self) { payloads, _ in
            guard let payload = payloads.first,
                  payload.hasPrefix("history-flow:"),
                  let item = items.first(where: { "history-flow:\($0.id)" == payload }) else {
                return false
            }
            let components = calendar.dateComponents([.hour, .minute, .second], from: item.startedAt)
            guard let target = calendar.date(
                bySettingHour: components.hour ?? 0,
                minute: components.minute ?? 0,
                second: components.second ?? 0,
                of: day
            ) else { return false }
            return onMove(item, target)
        }
    }

    private var weekdaySymbols: [String] {
        CalendarWeekdaySymbols.orderedAbbreviated(calendar: calendar)
    }

    private func dayTextColor(_ day: Date) -> Color {
        calendar.isDate(day, equalTo: selectedDate, toGranularity: .month) ? .primary : .secondary
    }
}
#endif
