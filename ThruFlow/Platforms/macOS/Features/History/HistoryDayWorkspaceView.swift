//
//  HistoryDayWorkspaceView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/14.
//

import SwiftUI

struct HistoryDayWorkspaceView: View {
    @Binding var selectedDate: Date
    @Binding var scale: HistoryDayTimelineScale
    let items: [HistoryCalendarItem]
    @Binding var selectedItemID: String?
    @Binding var manualFlowDraft: HistoryFlowCreationDraft?
    @Binding var visibleKinds: Set<HistoryCalendarItemKind>
    let onEdit: (HistoryCalendarItem) -> Void
    let onMove: (HistoryCalendarItem, Date) -> Bool
    let onDropOnDay: (String, Date) -> Bool

    @State private var compactInspectorItem: HistoryCalendarItem?

    private let calendar = Calendar.current
    private let windowBuilder = HistoryDayTimelineWindowBuilder()

    private var hourRange: Range<Int> {
        windowBuilder.hourRange(
            for: selectedDate,
            items: items,
            scale: scale,
            calendar: calendar
        )
    }

    private var selectedItem: HistoryCalendarItem? {
        guard let selectedItemID else { return nil }
        return items.first { $0.id == selectedItemID }
    }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 900 {
                HStack(spacing: 0) {
                    timelinePanel(isCompact: false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    HistoryDayInspectorPane(
                        selectedDate: $selectedDate,
                        selectedItem: selectedItem,
                        manualFlowDraft: $manualFlowDraft,
                        onEdit: onEdit,
                        onDropOnDay: onDropOnDay
                    )
                    .frame(width: min(390, max(310, geometry.size.width * 0.34)))
                }
            } else {
                timelinePanel(isCompact: true)
                    .sheet(item: $compactInspectorItem) { item in
                        HistoryDayInspectorPane(
                            selectedDate: $selectedDate,
                            selectedItem: item,
                            manualFlowDraft: $manualFlowDraft,
                            onEdit: onEdit,
                            onDropOnDay: onDropOnDay
                        )
                        .frame(minWidth: 340, idealWidth: 380, minHeight: 560)
                    }
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
            compactInspectorItem = nil
            manualFlowDraft = nil
        }
    }

    private func timelinePanel(isCompact: Bool) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDate.formatted(.dateTime.locale(Locale.autoupdatingCurrent).month().day()))
                        .font(.headline)
                    Text(selectedDate.formatted(.dateTime.locale(Locale.autoupdatingCurrent).weekday(.wide)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HistoryVisibilityMenu(visibleKinds: $visibleKinds)

                Picker(String(localized: "時間軸"), selection: $scale) {
                    ForEach(HistoryDayTimelineScale.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
                .accessibilityLabel(String(localized: "日の時間軸"))
            }
            .padding(.horizontal, 10)

            HistoryTimeGrid(
                selectedDate: selectedDate,
                range: .day,
                items: items,
                hourRange: hourRange,
                hourHeight: scale == .elastic ? 82 : 64,
                selectedItemID: selectedItemID,
                manualFlowDraft: $manualFlowDraft
            ) { item in
                manualFlowDraft = nil
                selectedItemID = item.id
                if isCompact {
                    compactInspectorItem = item
                }
            } onMove: { item, date in
                onMove(item, date)
            }
        }
    }

    private func updateManualFlowDraft(startedAt: Date, endedAt: Date) {
        manualFlowDraft?.startedAt = startedAt
        manualFlowDraft?.endedAt = endedAt
    }
}

struct HistoryMiniCalendar: View {
    @Binding var selectedDate: Date
    var selectionMode: HistoryMiniCalendarSelectionMode = .day
    var onDropPayload: ((String, Date) -> Bool)?

    private let calendar = Calendar.current
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: selectionMode == .week ? 0 : 2), count: 7)
    }

    private var monthDays: [Date] {
        guard let month = calendar.dateInterval(of: .month, for: selectedDate),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: month.start) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: firstWeek.start) }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(monthTitle)
                    .font(.headline)

                Spacer()

                Button {
                    selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.borderless)

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
                        Text("\(calendar.component(.day, from: date))")
                            .font(.caption)
                            .frame(width: selectionMode == .week ? nil : 24, height: 24)
                            .frame(maxWidth: selectionMode == .week ? .infinity : nil)
                            .foregroundStyle(dayForeground(date))
                            .background(dayBackground(date))
                            .clipShape(dayShape(date))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityDate(date))
                    .dropDestination(for: String.self) { payloads, _ in
                        guard let payload = payloads.first else { return false }
                        return onDropPayload?(payload, date) ?? false
                    }
                }
            }
        }
    }

    private var monthTitle: String {
        selectedDate.formatted(.dateTime.locale(Locale.autoupdatingCurrent).year().month(.wide))
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = max(0, calendar.firstWeekday - 1)
        return Array(symbols[offset...]) + Array(symbols[..<offset])
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
        date.formatted(.dateTime.locale(Locale.autoupdatingCurrent).year().month().day().weekday())
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
    @Binding var selectedDate: Date

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    moveYear(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(verbatim: String(localized: "\(selectedYear)年"))
                    .font(.headline)

                Spacer()

                Button {
                    moveYear(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.borderless)

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

    private func moveYear(by value: Int) {
        selectedDate = calendar.date(byAdding: .year, value: value, to: selectedDate) ?? selectedDate
    }

    private func select(month: Int) {
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
}

private struct HistoryDayInspectorPane: View {
    @Binding var selectedDate: Date
    let selectedItem: HistoryCalendarItem?
    @Binding var manualFlowDraft: HistoryFlowCreationDraft?
    let onEdit: (HistoryCalendarItem) -> Void
    let onDropOnDay: (String, Date) -> Bool

    var body: some View {
        VStack(spacing: 0) {
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
                            description: Text(String(localized: "Flowまたは休憩の詳細をここに表示します。"))
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
                propertyRow(String(localized: "Flow"), systemImage: "waveform.path") {
                    item.session?.mode.displayName ?? String(localized: "Flow")
                }
                propertyRow(String(localized: "方向"), systemImage: "point.3.connected.trianglepath.dotted") {
                    item.subtitle
                }
            case .rest:
                propertyRow(String(localized: "種類"), systemImage: "cup.and.saucer") {
                    item.flowBreak?.isLongBreak == true ? String(localized: "Long Break") : String(localized: "休憩")
                }
            }

            if let memo = item.todo?.notes, !memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
