#if os(iOS)
import SwiftUI

struct IOSHistoryDayStrip: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    @Binding var selectedDate: Date
    let sessions: [FlowSession]
    let visibleAreaTypes: Set<AreaType>?
    let onWindowChange: (DateInterval) -> Void

    var body: some View {
        let activityIndex = IOSHistoryActivityColorIndex(
            sessions: sessions,
            visibleAreaTypes: visibleAreaTypes,
            calendar: calendar
        )

        IOSScrollablePeriodStrip(
            selectedDate: $selectedDate,
            unit: .day,
            visibleItemCount: 7,
            spacing: 5,
            height: 55,
            onWindowChange: onWindowChange
        ) { date, isSelected in
            Button {
                selectedDate = calendar.startOfDay(for: date)
            } label: {
                VStack(spacing: 4) {
                    Text(date.formatted(.dateTime.locale(locale).weekday(.narrow)))
                        .font(.caption2.weight(.semibold))
                    Text(verbatim: String(calendar.component(.day, from: date)))
                        .font(.body.monospacedDigit().weight(.semibold))
                    IOSHistoryActivityDots(
                        colors: activityIndex.byDay[calendar.startOfDay(for: date)] ?? []
                    )
                }
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 55)
                .background(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

}

struct IOSHistoryWeekStrip: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    @Binding var selectedDate: Date
    let sessions: [FlowSession]
    let visibleAreaTypes: Set<AreaType>?
    let onWindowChange: (DateInterval) -> Void

    var body: some View {
        let activityIndex = IOSHistoryActivityColorIndex(
            sessions: sessions,
            visibleAreaTypes: visibleAreaTypes,
            calendar: calendar
        )

        IOSScrollablePeriodStrip(
            selectedDate: $selectedDate,
            unit: .week,
            visibleItemCount: 3,
            spacing: 6,
            height: 58,
            onWindowChange: onWindowChange
        ) { anchor, isSelected in
            let interval = HistoryCalendarRange.week.interval(
                containing: anchor,
                calendar: calendar,
                dayBoundary: dayBoundary
            )

            Button {
                selectedDate = calendar.startOfDay(for: anchor)
            } label: {
                VStack(spacing: 3) {
                    Text(interval.start.formatted(.dateTime.locale(locale).month(.abbreviated)))
                        .font(.caption.weight(.semibold))
                    Text(dayRangeText(interval))
                        .font(.body.monospacedDigit().weight(.semibold))
                    IOSHistoryActivityDots(
                        colors: activityIndex.byWeek[weekStart(for: anchor)] ?? []
                    )
                }
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    private func dayRangeText(_ interval: DateInterval) -> String {
        let end = interval.end.addingTimeInterval(-1)
        return "\(calendar.component(.day, from: interval.start))–\(calendar.component(.day, from: end))"
    }

    private func weekStart(for date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }
}

@MainActor
private struct IOSHistoryActivityColorIndex {
    private(set) var byDay: [Date: [String]] = [:]
    private(set) var byWeek: [Date: [String]] = [:]
    private var seenByDay: [Date: Set<String>] = [:]
    private var seenByWeek: [Date: Set<String>] = [:]

    init(
        sessions: [FlowSession],
        visibleAreaTypes: Set<AreaType>?,
        calendar: Calendar
    ) {
        for session in sessions
        where session.status != .interrupted && session.resolvedActualFocusDurationSeconds > 0 {
            if session.resolvedSegments.isEmpty {
                let areaType = session.area?.type ?? .neutral
                guard visibleAreaTypes?.contains(areaType) != false else { continue }
                append(
                    colorHex: session.area?.colorHex ?? "#8E8E93",
                    at: session.startedAt,
                    calendar: calendar
                )
                continue
            }

            for segment in session.resolvedSegments where segment.resolvedFocusSeconds > 0 {
                let areaType = segment.area?.type ?? session.area?.type ?? .neutral
                guard visibleAreaTypes?.contains(areaType) != false else { continue }
                append(
                    colorHex: segment.area?.colorHex ?? "#8E8E93",
                    at: segment.startedAt,
                    calendar: calendar
                )
            }
        }
    }

    private mutating func append(
        colorHex: String,
        at date: Date,
        calendar: Calendar
    ) {
        let normalizedColor = colorHex.lowercased()
        let day = calendar.startOfDay(for: date)
        let week = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? day

        if seenByDay[day, default: []].insert(normalizedColor).inserted,
           byDay[day, default: []].count < 4 {
            byDay[day, default: []].append(colorHex)
        }
        if seenByWeek[week, default: []].insert(normalizedColor).inserted,
           byWeek[week, default: []].count < 4 {
            byWeek[week, default: []].append(colorHex)
        }
    }
}

private struct IOSHistoryActivityDots: View {
    let colors: [String]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(colors, id: \.self) { colorHex in
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 4, height: 4)
            }
        }
        .frame(height: 4)
    }
}
#endif
