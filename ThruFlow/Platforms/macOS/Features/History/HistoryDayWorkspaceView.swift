//
//  HistoryDayWorkspaceView.swift
//  ThruFlow
//
//

import SwiftData
import SwiftUI

struct HistoryDayWorkspaceView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    @Binding var selectedDate: Date
    let items: [HistoryCalendarItem]
    @Binding var selectedItemID: String?
    @Binding var manualFlowDraft: HistoryFlowCreationDraft?
    @Binding var visibleKinds: Set<HistoryCalendarItemKind>
    let sidebarHeader: AnyView
    var showsInspector = true
    let onEdit: (HistoryCalendarItem) -> Void
    let onMove: (HistoryCalendarItem, Date) -> Bool
    let onDropOnDay: (String, Date) -> Bool

    private var dayInterval: DateInterval {
        dayBoundary.interval(for: selectedDate, calendar: calendar)
    }

    private var selectedItem: HistoryCalendarItem? {
        guard let selectedItemID else { return nil }
        return items.first { $0.id == selectedItemID }
    }

    var body: some View {
        GeometryReader { geometry in
            if !showsInspector {
                timelinePanel
            } else if geometry.size.width >= 900 {
                HStack(spacing: 0) {
                    timelinePanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    HistoryDayInspectorPane(
                        selectedDate: $selectedDate,
                        selectedItem: selectedItem,
                        manualFlowDraft: $manualFlowDraft,
                        sidebarHeader: sidebarHeader,
                        onEdit: onEdit,
                        onDropOnDay: onDropOnDay
                    )
                    .frame(width: min(390, max(310, geometry.size.width * 0.34)))
                }
            } else {
                timelinePanel
                    .sheet(
                        isPresented: Binding(
                            get: { manualFlowDraft != nil },
                            set: { if !$0 { manualFlowDraft = nil } }
                        )
                    ) {
                        if let draft = manualFlowDraft {
                            ManualFlowCreationView(
                                startedAt: draft.startedAt,
                                onTimeChange: updateManualFlowDraft
                            ) {
                                manualFlowDraft = nil
                            }
                            .id(draft.id)
                        }
                    }
            }
        }
        .onChange(of: selectedDate) { _, _ in
            selectedItemID = nil
            manualFlowDraft = nil
        }
    }

    private var timelinePanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDate.formatted(.dateTime.locale(locale).month().day()))
                        .font(.headline)
                    Text(selectedDate.formatted(.dateTime.locale(locale).weekday(.wide)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            HistoryVerticalTimelineView(
                items: items,
                selectedItemID: selectedItemID,
                gapInterval: dayInterval
            ) { item in
                manualFlowDraft = nil
                selectedItemID = item.id
                onEdit(item)
            }
        }
    }

    private func updateManualFlowDraft(startedAt: Date, endedAt: Date) {
        manualFlowDraft?.startedAt = startedAt
        manualFlowDraft?.endedAt = endedAt
    }
}

enum HistoryMiniCalendarIndicatorSource {
    case flowHistory
    case filteredFlowHistory(Set<AreaType>)
    case statistics([StatisticsCalendarIndicator])
    case tasks(TaskCalendarFilter)
}

struct StatisticsCalendarIndicator: Identifiable {
    let date: Date
    let colorHex: String

    var id: Date { date }
}

private struct HistoryCalendarFlowIndicators: View {
    @Environment(\.calendar) private var calendar

    let items: [HistoryCalendarItem]
    let date: Date
    var maximumVisibleCount = 4

    private var dayItems: [HistoryCalendarItem] {
        items.filter {
            $0.kind == .flow && calendar.isDate($0.startedAt, inSameDayAs: date)
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(dayItems.prefix(maximumVisibleCount))) { item in
                Circle()
                    .fill(Color(hex: item.colorHex))
                    .frame(width: 4, height: 4)
            }
        }
        .padding(.horizontal, 2)
        .frame(height: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "集中記録"))
    }
}

struct HistoryMiniCalendar: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    @Binding var selectedDate: Date
    var selectionMode: HistoryMiniCalendarSelectionMode = .day
    var indicatorSource: HistoryMiniCalendarIndicatorSource = .flowHistory
    var taskSnapshot: TaskCalendarSnapshot?
    var onDropPayload: ((String, Date) -> Bool)?
    var maximumDate: Date?

    @Query(sort: \Todo.sortIndex, order: .forward) private var todos: [Todo]
    @Query(sort: \FlowSession.startedAt, order: .forward) private var sessions: [FlowSession]

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: selectionMode == .week ? 0 : 2), count: 7)
    }

    private var monthDays: [Date] {
        guard let month = calendar.dateInterval(of: .month, for: selectedDate),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: month.start) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: firstWeek.start) }
    }

    private var historyItems: [HistoryCalendarItem] {
        guard showsFlowHistoryIndicators,
              let firstDay = monthDays.first,
              let lastDay = monthDays.last,
              let intervalEnd = calendar.date(byAdding: .day, value: 1, to: lastDay) else {
            return []
        }
        return HistoryCalendarBuilder(calendar: calendar).build(
            interval: DateInterval(start: firstDay, end: intervalEnd),
            sessions: sessions,
            breaks: []
        ).items
    }

    private var showsFlowHistoryIndicators: Bool {
        switch indicatorSource {
        case .flowHistory, .filteredFlowHistory:
            true
        case .statistics, .tasks:
            false
        }
    }

    var body: some View {
        let flowItems = historyItems

        VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ForEach(monthDays, id: \.self) { date in
                    Button {
                        selectedDate = calendar.startOfDay(for: date)
                    } label: {
                        calendarDayLabel(for: date, flowItems: flowItems)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSelect(date))
                    .accessibilityLabel(accessibilityDate(date))
                    .dropDestination(for: String.self) { payloads, _ in
                        guard let payload = payloads.first else { return false }
                        return onDropPayload?(payload, date) ?? false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func calendarDayLabel(
        for date: Date,
        flowItems: [HistoryCalendarItem]
    ) -> some View {
        if selectionMode == .week {
            dayContents(for: date, flowItems: flowItems)
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(dayBackground(date))
                .clipShape(dayShape(date))
                .contentShape(Rectangle())
        } else {
            ZStack {
                Color.clear

                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.caption)
                        .frame(width: 24, height: 20)
                        .foregroundStyle(dayForeground(date))
                        .background(dayBackground(date))
                        .clipShape(Capsule())

                    calendarIndicators(for: date, flowItems: flowItems)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 30)
            .contentShape(Rectangle())
        }
    }

    private func dayContents(
        for date: Date,
        flowItems: [HistoryCalendarItem]
    ) -> some View {
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.caption)
                .frame(height: 20)
                .foregroundStyle(dayForeground(date))

            calendarIndicators(for: date, flowItems: flowItems)
        }
    }

    @ViewBuilder
    private func calendarIndicators(for date: Date, flowItems: [HistoryCalendarItem]) -> some View {
        switch indicatorSource {
        case .flowHistory:
            HistoryCalendarFlowIndicators(items: flowItems, date: date, maximumVisibleCount: 3)
        case .filteredFlowHistory(let visibleTypes):
            HistoryCalendarFlowIndicators(
                items: HistoryCalendarIndicatorFilter().items(
                    from: flowItems,
                    visibleAreaTypes: visibleTypes
                ),
                date: date,
                maximumVisibleCount: 3
            )
        case .statistics(let indicators):
            HStack(spacing: 3) {
                ForEach(indicators.filter { calendar.isDate($0.date, inSameDayAs: date) }.prefix(3)) { indicator in
                    Circle()
                        .fill(Color(hex: indicator.colorHex))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        case .tasks(let filter):
            CalendarTaskIndicators(
                todos: (taskSnapshot?.todos(on: date) ?? todos).filter(filter.includes),
                date: date,
                maximumVisibleCount: 3
            )
        }
    }

    private var weekdaySymbols: [String] {
        CalendarWeekdaySymbols.orderedAbbreviated(calendar: calendar)
    }

    private func dayForeground(_ date: Date) -> Color {
        guard calendar.isDate(date, equalTo: selectedDate, toGranularity: .month) else { return .secondary }
        if selectionMode == .week, isInSelectedWeek(date) { return .primary }
        return calendar.isDate(date, inSameDayAs: selectedDate) ? .white : .primary
    }

    @ViewBuilder
    private func dayBackground(_ date: Date) -> some View {
        if selectionMode == .week, isInSelectedWeek(date) {
            Color.accentColor.opacity(0.22)
        } else if calendar.isDate(date, inSameDayAs: selectedDate) {
            Color.accentColor
        } else if calendar.isDateInToday(date) {
            Color.accentColor.opacity(0.16)
        } else {
            Color.clear
        }
    }

    private func accessibilityDate(_ date: Date) -> String {
        date.formatted(.dateTime.locale(locale).year().month().day().weekday())
    }

    private func canSelect(_ date: Date) -> Bool {
        guard let maximumDate else { return true }
        return calendar.startOfDay(for: date) <= calendar.startOfDay(for: maximumDate)
    }

    private func isInSelectedWeek(_ date: Date) -> Bool {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return false }
        let offset = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: interval.start),
            to: calendar.startOfDay(for: date)
        ).day
        return offset.map { (0..<7).contains($0) } ?? false
    }

    private func dayShape(_ date: Date) -> UnevenRoundedRectangle {
        guard selectionMode == .week, isInSelectedWeek(date),
              let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return UnevenRoundedRectangle(cornerRadii: .init(topLeading: 12, bottomLeading: 12, bottomTrailing: 12, topTrailing: 12))
        }

        let isStart = calendar.isDate(date, inSameDayAs: interval.start)
        let lastDate = calendar.date(byAdding: .day, value: 6, to: interval.start) ?? interval.start
        let isEnd = calendar.isDate(date, inSameDayAs: lastDate)
        return UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: isStart ? 6 : 0,
                bottomLeading: isStart ? 6 : 0,
                bottomTrailing: isEnd ? 6 : 0,
                topTrailing: isEnd ? 6 : 0
            )
        )
    }
}

enum HistoryMiniCalendarSelectionMode {
    case day
    case week
}

struct HistoryYearMonthPicker: View {
    @Environment(\.calendar) private var calendar

    @Binding var selectedDate: Date
    var maximumDate: Date?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(spacing: 14) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1...12, id: \.self) { month in
                    Button {
                        select(month: month)
                    } label: {
                        Text(String(localized: "\(month)月"))
                            .font(.callout.weight(month == selectedMonth ? .semibold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .foregroundStyle(month == selectedMonth ? Color.white : Color.primary)
                            .background(month == selectedMonth ? Color.accentColor : Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSelect(month: month))
                    .opacity(canSelect(month: month) ? 1 : 0.45)
                    .accessibilityLabel(Text(verbatim: String(localized: "\(selectedYear)年\(month)月")))
                    .accessibilityAddTraits(month == selectedMonth ? .isSelected : [])
                }
            }
        }
    }

    private var selectedYear: Int {
        calendar.component(.year, from: selectedDate)
    }

    private var selectedMonth: Int {
        calendar.component(.month, from: selectedDate)
    }

    private func select(month: Int) {
        guard canSelect(month: month) else { return }
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = selectedYear
        components.month = month
        components.day = 1
        if let date = components.date {
            selectedDate = calendar.startOfDay(for: date)
        }
    }

    private func canSelect(month: Int) -> Bool {
        guard let maximumDate else { return true }
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = selectedYear
        components.month = month
        components.day = 1
        guard let monthDate = components.date,
              let maximumMonth = calendar.dateInterval(of: .month, for: maximumDate)?.start else {
            return true
        }
        return monthDate <= maximumMonth
    }
}

struct HistoryDayInspectorPane: View {
    @Binding var selectedDate: Date
    let selectedItem: HistoryCalendarItem?
    @Binding var manualFlowDraft: HistoryFlowCreationDraft?
    let sidebarHeader: AnyView
    let onEdit: (HistoryCalendarItem) -> Void
    let onDropOnDay: (String, Date) -> Bool

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            Divider()

            HistoryMiniCalendar(selectedDate: $selectedDate, onDropPayload: onDropOnDay)
                .padding(16)

            Divider()

            if let draft = manualFlowDraft {
                ManualFlowCreationView(
                    startedAt: draft.startedAt,
                    onTimeChange: updateManualFlowDraft
                ) {
                    manualFlowDraft = nil
                }
                .id(draft.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    if let selectedItem {
                        properties(selectedItem)
                            .padding(18)
                    } else {
                        ContentUnavailableView(
                            String(localized: "記録を選択"),
                            systemImage: "cursorarrow.click",
                            description: Text(String(localized: "集中記録または休憩を選ぶと、ここに詳細が表示されます。"))
                        )
                        .padding(.horizontal, 20)
                        .padding(.vertical, 44)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.secondary.opacity(0.035))
    }

    private func updateManualFlowDraft(startedAt: Date, endedAt: Date) {
        manualFlowDraft?.startedAt = startedAt
        manualFlowDraft?.endedAt = endedAt
    }

    private func properties(_ item: HistoryCalendarItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text(item.symbol)
                    .font(.title2)
                    .frame(width: 42, height: 42)
                    .background(Color(hex: item.colorHex).opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Button {
                    onEdit(item)
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help(String(localized: "編集"))
                .accessibilityLabel(String(localized: "編集"))
            }

            Divider()

            propertyRow(String(localized: "時間"), systemImage: "clock") {
                "\(time(item.startedAt))–\(time(item.endedAt))"
            }
            propertyRow(String(localized: "長さ"), systemImage: "timer") {
                duration(item.durationSeconds)
            }

            switch item.kind {
            case .flow:
                propertyRow(String(localized: "集中モード"), systemImage: "waveform.path") {
                    item.session?.mode.displayName ?? String(localized: "集中記録")
                }
                propertyRow(String(localized: "分野"), systemImage: ProductSymbol.area) {
                    item.subtitle
                }
            case .rest:
                propertyRow(String(localized: "種類"), systemImage: "cup.and.saucer") {
                    item.flowBreak?.isLongBreak == true ? String(localized: "長休憩") : String(localized: "休憩")
                }
            }

            if let memo = item.session?.result ?? item.todo?.notes,
               !memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label(String(localized: "メモ"), systemImage: "note.text")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(memo)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 4)
            }

            Button {
                onEdit(item)
            } label: {
                Label(String(localized: "詳細を編集"), systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: item.colorHex))
            .padding(.top, 4)
        }
    }

    private func propertyRow(_ title: String, systemImage: String, value: () -> String) -> some View {
        HStack(spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value())
                .font(.callout.weight(.medium).monospacedDigit())
                .multilineTextAlignment(.trailing)
        }
    }

    private func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func duration(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        if minutes < 60 { return String(localized: "\(minutes)分") }
        return String(localized: "\(minutes / 60)時間\(minutes % 60)分")
    }
}
