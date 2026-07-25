import SwiftData
import SwiftUI
import UIKit

struct IOSHistoryView: View {
    @Environment(\.calendar) private var calendar

    @Query(sort: \FlowSession.startedAt) private var sessions: [FlowSession]
    @Query(sort: \FlowBreak.startedAt) private var flowBreaks: [FlowBreak]
    @Query(sort: \Todo.updatedAt, order: .reverse) private var todos: [Todo]

    @Binding private var selectedDate: Date
    @State private var range = HistoryCalendarRange.day
    @State private var selectedMode = DayHistoryMode.calendar
    @State private var visibleKinds = Set(HistoryCalendarItemKind.allCases)
    @State private var selectedItem: HistoryCalendarItem?
    @State private var isAddingTaskRecord = false
    @State private var searchText = ""

    init(selectedDate: Binding<Date>) {
        _selectedDate = selectedDate
    }

    var body: some View {
        VStack(spacing: 0) {
            calendarToolbar
            Divider()
            historyContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle(String(localized: "履歴"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(String(localized: "検索"))
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                modeMenu
            }
        }
        .sheet(item: $selectedItem) { item in
            IOSHistoryItemDetail(item: item)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $isAddingTaskRecord) {
            HistoryTaskRecordForm(
                startedAt: defaultTaskRecordStart,
                onDismiss: { isAddingTaskRecord = false }
            )
        }
    }

    private var calendarSnapshot: HistoryCalendarSnapshot {
        calendarSnapshot(for: selectedDate)
    }

    private func calendarSnapshot(for date: Date) -> HistoryCalendarSnapshot {
        let interval = range.interval(containing: date, calendar: calendar)
        return HistoryCalendarBuilder(calendar: calendar).build(
            interval: interval,
            sessions: sessions,
            breaks: flowBreaks
        )
    }

    private var historySnapshot: DayHistorySnapshot {
        historySnapshot(for: selectedDate)
    }

    private func historySnapshot(for date: Date) -> DayHistorySnapshot {
        DayHistoryBuilder(calendar: calendar).build(
            interval: range.interval(containing: date, calendar: calendar),
            sessions: sessions,
            todos: todos
        )
    }

    private var visibleCalendarItems: [HistoryCalendarItem] {
        visibleCalendarItems(for: selectedDate)
    }

    @ViewBuilder
    private var historyContent: some View {
        historyPageContent(for: selectedDate)
    }

    @ViewBuilder
    private func historyPageContent(for date: Date) -> some View {
        switch selectedMode {
        case .calendar:
            let snapshot = calendarSnapshot(for: date)
            switch range {
            case .day:
                IOSHistoryDayTimeline(
                    date: date,
                    items: visibleCalendarItems(for: date),
                    selection: $selectedItem
                )
            case .week:
                IOSHistoryWeekTimeline(
                    interval: snapshot.interval,
                    items: visibleCalendarItems(for: date),
                    selection: $selectedItem
                )
            case .month:
                EmptyView()
            }
        case .tasks:
            IOSHistoryTaskSummaryList(
                snapshot: historySnapshot(for: date),
                searchText: searchText,
                onAddRecord: { isAddingTaskRecord = true }
            )
        case .directions:
            IOSHistoryDirectionSummaryList(
                snapshot: historySnapshot(for: date),
                searchText: searchText
            )
        }
    }

    private func visibleCalendarItems(for date: Date) -> [HistoryCalendarItem] {
        calendarSnapshot(for: date).items
            .filter { visibleKinds.contains($0.kind) }
            .filter(matchesSearch)
    }

    private func matchesSearch(_ item: HistoryCalendarItem) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return [item.title, item.subtitle, item.symbol]
            .contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private var modeMenu: some View {
        Menu {
            ForEach(DayHistoryMode.allCases) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    if selectedMode == mode {
                        Label(mode.displayName, systemImage: "checkmark")
                    } else {
                        Text(mode.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedMode.displayName)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
        }
        .accessibilityLabel(String(localized: "履歴表示"))
    }

    private var calendarToolbar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if selectedMode == .calendar {
                    historyVisibilityMenu
                } else {
                    Color.clear
                        .frame(width: 30, height: 30)
                }

                Spacer(minLength: 0)

                Picker(String(localized: "期間"), selection: $range) {
                    ForEach(HistoryCalendarRange.allCases) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 190)

                Spacer(minLength: 0)

                Button(String(localized: "今日")) {
                    selectedDate = calendar.startOfDay(for: .now)
                }
                .buttonStyle(.borderedProminent)
            }

            switch range {
            case .day:
                IOSHistoryDayStrip(
                    selectedDate: $selectedDate,
                    sessions: sessions
                )
            case .week:
                IOSHistoryWeekStrip(
                    selectedDate: $selectedDate,
                    sessions: sessions
                )
            case .month:
                IOSHistoryMonthGrid(
                    interval: calendarSnapshot.interval,
                    items: visibleCalendarItems,
                    selectedDate: $selectedDate
                ) {
                    if selectedMode == .calendar {
                        range = .day
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var historyVisibilityMenu: some View {
        Menu {
            Toggle(String(localized: "Flow"), isOn: visibilityBinding(for: .flow))
            Toggle(String(localized: "休憩"), isOn: visibilityBinding(for: .rest))
        } label: {
            Image(
                systemName: visibleKinds.count == HistoryCalendarItemKind.allCases.count
                    ? "line.3.horizontal.decrease"
                    : "line.3.horizontal.decrease.circle.fill"
            )
            .frame(width: 30, height: 30)
        }
        .accessibilityLabel(String(localized: "フィルター"))
    }

    private func visibilityBinding(for kind: HistoryCalendarItemKind) -> Binding<Bool> {
        Binding(
            get: { visibleKinds.contains(kind) },
            set: { isVisible in
                if isVisible {
                    visibleKinds.insert(kind)
                } else {
                    visibleKinds.remove(kind)
                }
            }
        )
    }

    private var defaultTaskRecordStart: Date {
        if calendar.isDateInToday(selectedDate) {
            return Date.now.addingTimeInterval(-25 * 60)
        }
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate
    }
}

private struct IOSHistoryDayStrip: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    @Binding var selectedDate: Date
    let sessions: [FlowSession]

    var body: some View {
        IOSScrollablePeriodStrip(
            selectedDate: $selectedDate,
            unit: .day,
            visibleItemCount: 7,
            spacing: 5
        ) { date, isSelected in
            Button {
                selectedDate = calendar.startOfDay(for: date)
            } label: {
                VStack(spacing: 4) {
                    Text(date.formatted(.dateTime.locale(locale).weekday(.narrow)))
                        .font(.caption2.weight(.semibold))
                    Text(verbatim: String(calendar.component(.day, from: date)))
                        .font(.body.monospacedDigit().weight(.semibold))
                    IOSHistoryActivityDots(colors: activityColors(on: date))
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

    private func activityColors(on date: Date) -> [String] {
        let interval = HistoryCalendarRange.day.interval(containing: date, calendar: calendar)
        var seen = Set<String>()
        return HistoryCalendarBuilder(calendar: calendar)
            .build(interval: interval, sessions: sessions, breaks: [])
            .items
            .filter { $0.kind == .flow }
            .map(\.colorHex)
            .filter { seen.insert($0.lowercased()).inserted }
            .prefix(4)
            .map { $0 }
    }
}

private struct IOSHistoryWeekStrip: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    @Binding var selectedDate: Date
    let sessions: [FlowSession]

    var body: some View {
        IOSScrollablePeriodStrip(
            selectedDate: $selectedDate,
            unit: .week,
            visibleItemCount: 3,
            spacing: 6
        ) { anchor, isSelected in
            let interval = HistoryCalendarRange.week.interval(containing: anchor, calendar: calendar)

            Button {
                selectedDate = calendar.startOfDay(for: anchor)
            } label: {
                VStack(spacing: 3) {
                    Text(interval.start.formatted(.dateTime.locale(locale).month(.abbreviated)))
                        .font(.caption.weight(.semibold))
                    Text(dayRangeText(interval))
                        .font(.body.monospacedDigit().weight(.semibold))
                    IOSHistoryActivityDots(colors: activityColors(in: interval))
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

    private func activityColors(in interval: DateInterval) -> [String] {
        var seen = Set<String>()
        return HistoryCalendarBuilder(calendar: calendar)
            .build(interval: interval, sessions: sessions, breaks: [])
            .items
            .filter { $0.kind == .flow }
            .map(\.colorHex)
            .filter { seen.insert($0.lowercased()).inserted }
            .prefix(4)
            .map { $0 }
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

private struct IOSHistoryTaskSummaryList: View {
    let snapshot: DayHistorySnapshot
    let searchText: String
    let onAddRecord: () -> Void

    private var visibleTasks: [DayHistoryTaskSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return snapshot.taskSummaries }
        return snapshot.taskSummaries.filter { task in
            [task.title, task.directionName, task.directionSymbol]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                HStack {
                    Spacer()

                    Button(action: onAddRecord) {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel(String(localized: "記録を追加"))
                }

                if visibleTasks.isEmpty {
                    ContentUnavailableView(
                        String(localized: "記録なし"),
                        systemImage: "clock.arrow.circlepath",
                        description: Text(String(localized: "この期間のFlowとタスクはありません。"))
                    )
                    .padding(.top, 72)
                } else {
                    ForEach(visibleTasks) { task in
                        IOSHistorySummaryRow(
                            symbol: task.directionSymbol,
                            title: task.title,
                            subtitle: task.directionName,
                            colorHex: task.directionColorHex,
                            focusSeconds: task.focusSeconds,
                            flowCount: task.flowCount
                        )
                    }
                }
            }
            .padding(16)
        }
    }
}

private struct IOSHistoryDirectionSummaryList: View {
    let snapshot: DayHistorySnapshot
    let searchText: String

    private var recordedDirections: [DayHistoryDirectionSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return snapshot.directionSummaries.filter { direction in
            guard direction.focusSeconds > 0 else { return false }
            guard !query.isEmpty else { return true }
            return [direction.name, direction.symbol]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if recordedDirections.isEmpty {
                    ContentUnavailableView(
                        String(localized: "記録なし"),
                        systemImage: "clock.arrow.circlepath",
                        description: Text(String(localized: "この期間のFlowとタスクはありません。"))
                    )
                    .padding(.top, 72)
                } else {
                    ForEach(recordedDirections) { direction in
                        IOSHistorySummaryRow(
                            symbol: direction.symbol,
                            title: direction.name,
                            subtitle: nil,
                            colorHex: direction.colorHex,
                            focusSeconds: direction.focusSeconds,
                            flowCount: direction.flowCount
                        )
                    }
                }
            }
            .padding(16)
        }
    }
}

private struct IOSHistorySummaryRow: View {
    let symbol: String
    let title: String
    let subtitle: String?
    let colorHex: String
    let focusSeconds: Int
    let flowCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(symbol)
                .font(.title3)
                .frame(width: 38, height: 38)
                .background(Color(hex: colorHex).opacity(0.16), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                if let subtitle, subtitle != title {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(focusDurationText)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text("\(flowCount) Flow")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }

    private var focusDurationText: String {
        let minutes = focusSeconds / 60
        if minutes < 60 {
            return String(localized: "\(minutes)分")
        }
        return String(localized: "\(minutes / 60)時間\(minutes % 60)分")
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
        VStack(spacing: 8) {
            HStack {
                Text(selectedDate, format: .dateTime.year().month(.wide))
                    .font(.headline)

                Spacer(minLength: 0)

                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel(String(localized: "前へ"))

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel(String(localized: "次へ"))
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(monthDates, id: \.self) { date in
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    Button {
                        selectedDate = date
                        openDay()
                    } label: {
                        VStack(spacing: 5) {
                            Text(verbatim: String(calendar.component(.day, from: date)))
                                .font(.subheadline.weight(isSelected || calendar.isDateInToday(date) ? .bold : .regular))
                                .foregroundStyle(isSelected ? Color.white : Color.primary)
                                .frame(width: 30, height: 30)
                                .background(
                                    isSelected ? Color.accentColor : Color.clear,
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
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func moveMonth(by value: Int) {
        selectedDate = calendar.date(byAdding: .month, value: value, to: selectedDate) ?? selectedDate
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
