import SwiftData
import SwiftUI
import UIKit

struct IOSHistoryView: View {
    @Environment(\.calendar) private var calendar

    @Query(sort: \FlowSession.startedAt) private var sessions: [FlowSession]
    @Query(sort: \FlowBreak.startedAt) private var flowBreaks: [FlowBreak]

    @State private var selectedDate = Date.now
    @State private var range = HistoryCalendarRange.day
    @State private var selectedItem: HistoryCalendarItem?

    var body: some View {
        VStack(spacing: 0) {
            calendarToolbar
            Divider()

            Group {
                switch range {
                case .day:
                    IOSHistoryDayTimeline(
                        date: selectedDate,
                        items: snapshot.items,
                        selection: $selectedItem
                    )
                case .week:
                    IOSHistoryWeekTimeline(
                        interval: snapshot.interval,
                        items: snapshot.items,
                        selection: $selectedItem
                    )
                case .month:
                    IOSHistoryMonthGrid(
                        interval: snapshot.interval,
                        items: snapshot.items,
                        selectedDate: $selectedDate
                    ) {
                        range = .day
                    }
                }
            }
        }
        .navigationTitle(String(localized: "履歴"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedItem) { item in
            IOSHistoryItemDetail(item: item)
                .presentationDetents([.medium])
        }
    }

    private var snapshot: HistoryCalendarSnapshot {
        let interval = range.interval(containing: selectedDate, calendar: calendar)
        return HistoryCalendarBuilder(calendar: calendar).build(
            interval: interval,
            sessions: sessions,
            breaks: flowBreaks
        )
    }

    private var calendarToolbar: some View {
        VStack(spacing: 10) {
            Picker(String(localized: "期間"), selection: $range) {
                ForEach(HistoryCalendarRange.allCases) { value in
                    Text(value.displayName).tag(value)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Button {
                    selectedDate = range.moving(selectedDate, by: -1, calendar: calendar)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel(String(localized: "前へ"))

                VStack(spacing: 1) {
                    Text(periodTitle)
                        .font(.headline)
                    if range == .day {
                        Text(selectedDate, format: .dateTime.weekday(.wide))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                Button(String(localized: "今日")) {
                    selectedDate = .now
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    selectedDate = range.moving(selectedDate, by: 1, calendar: calendar)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel(String(localized: "次へ"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var periodTitle: String {
        switch range {
        case .day:
            return selectedDate.formatted(.dateTime.year().month(.wide).day())
        case .week:
            let interval = range.interval(containing: selectedDate, calendar: calendar)
            let lastDate = interval.end.addingTimeInterval(-1)
            return "\(interval.start.formatted(.dateTime.month(.abbreviated).day())) – \(lastDate.formatted(.dateTime.month(.abbreviated).day()))"
        case .month:
            return selectedDate.formatted(.dateTime.year().month(.wide))
        }
    }
}

private struct IOSHistoryDayTimeline: View {
    let date: Date
    let items: [HistoryCalendarItem]
    @Binding var selection: HistoryCalendarItem?

    @Environment(\.calendar) private var calendar

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                IOSHistoryTimelineGrid(
                    days: [calendar.startOfDay(for: date)],
                    items: items,
                    columnWidth: nil,
                    availableWidth: geometry.size.width,
                    selection: $selection
                )
                .background {
                    IOSHistoryInitialScrollPosition(
                        identity: calendar.startOfDay(for: date),
                        offset: CGFloat(max(0, relevantHour - 1)) * 64
                    )
                }
            }
        }
    }

    private var relevantHour: Int {
        let firstHour = items.map { calendar.component(.hour, from: $0.startedAt) }.min()
        return calendar.isDateInToday(date)
            ? calendar.component(.hour, from: .now)
            : firstHour ?? 9
    }
}

private struct IOSHistoryInitialScrollPosition: UIViewRepresentable {
    let identity: Date
    let offset: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        UIView(frame: .zero)
    }

    func updateUIView(_ view: UIView, context: Context) {
        guard context.coordinator.appliedIdentity != identity else { return }
        context.coordinator.appliedIdentity = identity

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let scrollView = enclosingScrollView(for: view) else { return }
            let maximumOffset = max(
                -scrollView.adjustedContentInset.top,
                scrollView.contentSize.height - scrollView.bounds.height
                    + scrollView.adjustedContentInset.bottom
            )
            scrollView.setContentOffset(
                CGPoint(x: scrollView.contentOffset.x, y: min(offset, maximumOffset)),
                animated: false
            )
        }
    }

    private func enclosingScrollView(for view: UIView) -> UIScrollView? {
        var current = view.superview
        while let candidate = current {
            if let scrollView = candidate as? UIScrollView { return scrollView }
            current = candidate.superview
        }
        return nil
    }

    final class Coordinator {
        var appliedIdentity: Date?
    }
}

private struct IOSHistoryWeekTimeline: View {
    let interval: DateInterval
    let items: [HistoryCalendarItem]
    @Binding var selection: HistoryCalendarItem?

    @Environment(\.calendar) private var calendar

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            IOSHistoryTimelineGrid(
                days: weekDays,
                items: items,
                columnWidth: 132,
                availableWidth: nil,
                selection: $selection
            )
        }
    }

    private var weekDays: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }
}

private struct IOSHistoryTimelineGrid: View {
    private static let hourHeight: CGFloat = 64
    private static let headerHeight: CGFloat = 48
    private static let timeGutter: CGFloat = 44

    let days: [Date]
    let items: [HistoryCalendarItem]
    let columnWidth: CGFloat?
    let availableWidth: CGFloat?
    @Binding var selection: HistoryCalendarItem?

    @Environment(\.calendar) private var calendar

    var body: some View {
        let usableWidth = max((availableWidth ?? 0) - Self.timeGutter, 1)
        let resolvedColumnWidth = columnWidth ?? usableWidth / CGFloat(max(days.count, 1))
        let contentWidth = Self.timeGutter + resolvedColumnWidth * CGFloat(days.count)

            ZStack(alignment: .topLeading) {
                timelineBackground(columnWidth: resolvedColumnWidth)
                timelineItems(columnWidth: resolvedColumnWidth)
                currentTimeLine(columnWidth: resolvedColumnWidth)
        }
        .frame(width: contentWidth, height: Self.headerHeight + Self.hourHeight * 24)
        .frame(
            minWidth: Self.timeGutter + (columnWidth ?? 0) * CGFloat(days.count),
            minHeight: Self.headerHeight + Self.hourHeight * 24
        )
    }

    private func timelineBackground(columnWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                VStack(spacing: 1) {
                    Text(day, format: .dateTime.weekday(.abbreviated).day())
                        .font(.caption.weight(calendar.isDateInToday(day) ? .bold : .medium))
                        .foregroundStyle(calendar.isDateInToday(day) ? Color.accentColor : Color.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: columnWidth, height: Self.headerHeight)
                .background(calendar.isDateInToday(day) ? Color.accentColor.opacity(0.08) : Color.clear)
                .offset(x: Self.timeGutter + CGFloat(index) * columnWidth)
            }

            ForEach(0..<24, id: \.self) { hour in
                HStack(spacing: 4) {
                    Text(hour, format: .number)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .frame(width: Self.timeGutter - 6, alignment: .trailing)
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 1)
                }
                .offset(y: Self.headerHeight + CGFloat(hour) * Self.hourHeight)
            }

            ForEach(0...days.count, id: \.self) { index in
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 1, height: Self.hourHeight * 24)
                    .offset(
                        x: Self.timeGutter + CGFloat(index) * columnWidth,
                        y: Self.headerHeight
                    )
            }
        }
    }

    private func timelineItems(columnWidth: CGFloat) -> some View {
        ForEach(Array(days.enumerated()), id: \.offset) { dayIndex, day in
            let dayItems = itemsForDay(day)
            let placements = placementMap(for: dayItems)

            ForEach(dayItems) { item in
                let placement = placements[item.id]
                let laneCount = CGFloat(max(placement?.laneCount ?? 1, 1))
                let lane = CGFloat(placement?.lane ?? 0)
                let width = max((columnWidth - 6) / laneCount, 24)

                Button {
                    selection = item
                } label: {
                    IOSHistoryEventBlock(item: item)
                }
                .buttonStyle(.plain)
                .frame(width: width, height: itemHeight(item), alignment: .topLeading)
                .offset(
                    x: Self.timeGutter + CGFloat(dayIndex) * columnWidth + 3 + lane * width,
                    y: itemY(item)
                )
            }
        }
    }

    @ViewBuilder
    private func currentTimeLine(columnWidth: CGFloat) -> some View {
        if let dayIndex = days.firstIndex(where: calendar.isDateInToday) {
            let components = calendar.dateComponents([.hour, .minute, .second], from: .now)
            let minute = Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
                + Double(components.second ?? 0) / 60
            HStack(spacing: 0) {
                Circle().fill(Color.red).frame(width: 7, height: 7)
                Rectangle().fill(Color.red).frame(height: 1)
            }
            .frame(width: columnWidth + 4)
            .offset(
                x: Self.timeGutter + CGFloat(dayIndex) * columnWidth - 3,
                y: Self.headerHeight + Self.hourHeight * CGFloat(minute / 60) - 3
            )
        }
    }

    private func itemsForDay(_ day: Date) -> [HistoryCalendarItem] {
        let interval = HistoryCalendarRange.day.interval(containing: day, calendar: calendar)
        return items.filter { $0.startedAt < interval.end && $0.endedAt > interval.start }
    }

    private func placementMap(for dayItems: [HistoryCalendarItem]) -> [String: HistoryOverlapPlacement] {
        let placements = HistoryOverlapLayout().place(dayItems.map {
            HistoryOverlapInput(id: $0.id, start: $0.startedAt, end: $0.endedAt)
        }, minimumDuration: 15 * 60)
        return Dictionary(uniqueKeysWithValues: placements.map { ($0.id, $0) })
    }

    private func itemY(_ item: HistoryCalendarItem) -> CGFloat {
        let components = calendar.dateComponents([.hour, .minute, .second], from: item.startedAt)
        let minute = Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
            + Double(components.second ?? 0) / 60
        return Self.headerHeight + Self.hourHeight * CGFloat(minute / 60) + 1
    }

    private func itemHeight(_ item: HistoryCalendarItem) -> CGFloat {
        max(Self.hourHeight * CGFloat(Double(item.durationSeconds) / 3_600), item.kind == .rest ? 16 : 24)
    }
}

private struct IOSHistoryEventBlock: View {
    let item: HistoryCalendarItem

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(item.symbol) \(item.title)")
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            if item.durationSeconds >= 15 * 60 {
                Text(timeRange)
                    .font(.caption2.monospacedDigit())
                    .lineLimit(1)
            }
        }
        .foregroundStyle(item.kind == .rest ? Color.primary : Color.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }

    private var backgroundColor: Color {
        item.kind == .rest ? Color.secondary.opacity(0.23) : Color(hex: item.colorHex).opacity(0.92)
    }

    private var timeRange: String {
        "\(item.startedAt.formatted(date: .omitted, time: .shortened))–\(item.endedAt.formatted(date: .omitted, time: .shortened))"
    }
}

private struct IOSHistoryMonthGrid: View {
    let interval: DateInterval
    let items: [HistoryCalendarItem]
    @Binding var selectedDate: Date
    let openDay: () -> Void

    @Environment(\.calendar) private var calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(monthDates, id: \.self) { date in
                        Button {
                            selectedDate = date
                            openDay()
                        } label: {
                            VStack(spacing: 5) {
                                Text(date, format: .dateTime.day())
                                    .font(.subheadline.weight(calendar.isDateInToday(date) ? .bold : .regular))
                                    .foregroundStyle(calendar.isDateInToday(date) ? Color.white : Color.primary)
                                    .frame(width: 30, height: 30)
                                    .background(
                                        calendar.isDateInToday(date) ? Color.accentColor : Color.clear,
                                        in: Circle()
                                    )

                                HStack(spacing: 2) {
                                    ForEach(colors(on: date).prefix(3), id: \.self) { colorHex in
                                        Circle()
                                            .fill(Color(hex: colorHex))
                                            .frame(width: 5, height: 5)
                                    }
                                }
                                .frame(height: 5)
                            }
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
        }
    }

    private var monthDates: [Date] {
        guard let month = calendar.dateInterval(of: .month, for: interval.start),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: month.start) else { return [] }
        let lastDay = month.end.addingTimeInterval(-1)
        let lastWeekEnd = calendar.dateInterval(of: .weekOfYear, for: lastDay)?.end ?? month.end
        let count = max(0, calendar.dateComponents([.day], from: firstWeek.start, to: lastWeekEnd).day ?? 0)
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: firstWeek.start) }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = max(0, calendar.firstWeekday - 1)
        return Array(symbols[offset...] + symbols[..<offset])
    }

    private func colors(on date: Date) -> [String] {
        var seen = Set<String>()
        return items.compactMap { item in
            guard calendar.isDate(item.startedAt, inSameDayAs: date), item.kind == .flow else { return nil }
            return seen.insert(item.colorHex).inserted ? item.colorHex : nil
        }
    }
}

private struct IOSHistoryItemDetail: View {
    @Environment(\.dismiss) private var dismiss

    let item: HistoryCalendarItem

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(item.title, systemImage: item.kind == .rest ? "cup.and.saucer.fill" : "waveform.path")
                    LabeledContent(String(localized: "方向"), value: item.subtitle)
                    LabeledContent(String(localized: "時間"), value: timeRange)
                    LabeledContent(String(localized: "長さ"), value: durationText)
                }
            }
            .navigationTitle(item.kind == .rest ? String(localized: "休憩") : String(localized: "Flow"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "閉じる")) { dismiss() }
                }
            }
        }
    }

    private var timeRange: String {
        "\(item.startedAt.formatted(date: .omitted, time: .shortened))–\(item.endedAt.formatted(date: .omitted, time: .shortened))"
    }

    private var durationText: String {
        let minutes = item.durationSeconds / 60
        return minutes >= 60
            ? "\(minutes / 60)\(String(localized: "時間")) \(minutes % 60)\(String(localized: "分"))"
            : "\(minutes)\(String(localized: "分"))"
    }
}
