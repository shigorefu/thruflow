//
//  HistoryCalendarView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/14.
//

import SwiftData
import SwiftUI

struct HistoryCalendarView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Binding var selectedDate: Date
    @Binding var range: HistoryCalendarRange

    let sessions: [FlowSession]
    let breaks: [FlowBreak]
    @Binding var visibleKinds: Set<HistoryCalendarItemKind>
    let sidebarTitle: String
    let sidebarHeader: AnyView
    let sidebarSummary: AnyView?
    let onAddRecord: (Date) -> Void

    @State private var inspectedItem: HistoryCalendarItem?
    @State private var editedBreak: FlowBreak?
    @State private var inspectedSeries: HistoryCalendarSeriesBlock?
    @State private var inspectedDay: HistoryDayTimelineSelection?
    @State private var selectedDayItemID: String?
    @State private var manualFlowDraft: HistoryFlowCreationDraft?

    private let builder = HistoryCalendarBuilder()
    private let historyEditor = FlowHistoryEditor()

    private var snapshot: HistoryCalendarSnapshot {
        let interval = range.interval(
            containing: selectedDate,
            calendar: calendar,
            dayBoundary: dayBoundary
        )
        return builder.build(
            interval: interval,
            sessions: sessions,
            breaks: breaks
        )
    }

    private var filteredItems: [HistoryCalendarItem] {
        snapshot.items.filter { visibleKinds.contains($0.kind) }
    }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 900 {
                HStack(spacing: 0) {
                    widePrimaryContent
                        .id(range)
                        .transition(.opacity.combined(with: .scale(scale: 0.995)))
                        .animation(.easeInOut(duration: 0.22), value: range)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    wideSidebarContent
                        .frame(
                            width: MacCalendarSidebarLayout.width(
                                for: sidebarTitle,
                                in: geometry.size.width,
                                preferredFraction: 0.30
                            )
                        )
                }
            } else {
                compactContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(item: $inspectedItem) { item in
            if let session = item.session {
                FlowHistoryInspectorView(
                    session: session,
                    segment: item.flowSegment
                )
            }
        }
        .sheet(item: $editedBreak) { flowBreak in
            HistoryBreakEditorView(flowBreak: flowBreak)
                .environmentObject(activeFlowStore)
        }
        .sheet(item: $inspectedSeries) { block in
            HistorySeriesTimelineView(block: block)
                .environmentObject(activeFlowStore)
        }
        .sheet(item: $inspectedDay) { selection in
            HistoryDayTimelineSheet(
                date: selection.date,
                items: selection.items
            )
            .environmentObject(activeFlowStore)
        }
        .sheet(
            isPresented: Binding(
                get: { range == .week && manualFlowDraft != nil },
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

    @ViewBuilder
    private var widePrimaryContent: some View {
        switch range {
        case .day:
            HistoryDayWorkspaceView(
                selectedDate: $selectedDate,
                items: filteredItems,
                selectedItemID: $selectedDayItemID,
                manualFlowDraft: $manualFlowDraft,
                visibleKinds: $visibleKinds,
                sidebarHeader: sidebarHeader,
                showsInspector: false,
                onEdit: openEditor,
                onMove: moveHistoryItem,
                onDropOnDay: moveHistoryPayload
            )
        case .week:
            HistoryTimeGrid(
                selectedDate: selectedDate,
                range: range,
                items: filteredItems,
                hourRange: 0..<24,
                hourHeight: 64,
                selectedItemID: nil,
                manualFlowDraft: $manualFlowDraft,
                onSelectSeries: openSeries,
                onSelect: openEditor,
                onMove: moveHistoryItem,
                onAddRecord: onAddRecord
            )
        case .month:
            HistoryMonthGrid(
                selectedDate: $selectedDate,
                items: filteredItems,
                onSelect: openEditor,
                onShowDay: openDayTimeline,
                onMove: moveHistoryItem
            )
        }
    }

    @ViewBuilder
    private var wideSidebarContent: some View {
        switch range {
        case .day:
            historyPeriodSidebar(summary: sidebarSummary) {
                HistoryMiniCalendar(
                    selectedDate: $selectedDate,
                    onDropPayload: moveHistoryPayload
                )
            }
        case .week:
            historyPeriodSidebar {
                HistoryMiniCalendar(
                    selectedDate: $selectedDate,
                    selectionMode: .week,
                    onDropPayload: moveHistoryPayload
                )
            }
        case .month:
            historyPeriodSidebar {
                HistoryYearMonthPicker(selectedDate: $selectedDate)
            }
        }
    }

    @ViewBuilder
    private var compactContent: some View {
        switch range {
        case .day:
            HistoryDayWorkspaceView(
                selectedDate: $selectedDate,
                items: filteredItems,
                selectedItemID: $selectedDayItemID,
                manualFlowDraft: $manualFlowDraft,
                visibleKinds: $visibleKinds,
                sidebarHeader: sidebarHeader,
                onEdit: openEditor,
                onMove: moveHistoryItem,
                onDropOnDay: moveHistoryPayload
            )
        case .week:
            HistoryCalendarPeriodWorkspace(sidebarHeader: sidebarHeader) {
                HistoryTimeGrid(
                    selectedDate: selectedDate,
                    range: range,
                    items: filteredItems,
                    hourRange: 0..<24,
                    hourHeight: 64,
                    selectedItemID: nil,
                    manualFlowDraft: $manualFlowDraft,
                    onSelectSeries: openSeries,
                    onSelect: openEditor,
                    onMove: moveHistoryItem,
                    onAddRecord: onAddRecord
                )
            } inspector: {
                HistoryMiniCalendar(
                    selectedDate: $selectedDate,
                    selectionMode: .week,
                    onDropPayload: moveHistoryPayload
                )
            }
        case .month:
            HistoryCalendarPeriodWorkspace(sidebarHeader: sidebarHeader) {
                HistoryMonthGrid(
                    selectedDate: $selectedDate,
                    items: filteredItems,
                    onSelect: openEditor,
                    onShowDay: openDayTimeline,
                    onMove: moveHistoryItem
                )
            } inspector: {
                HistoryYearMonthPicker(selectedDate: $selectedDate)
            }
        }
    }

    private func historyPeriodSidebar<Content: View>(
        summary: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            sidebarHeader

            Divider()

            content()
                .padding(16)

            if let summary {
                Divider()
                summary
                    .padding(16)
            }

            Spacer(minLength: 0)
        }
        .background(Color.secondary.opacity(0.035))
    }

    private func openEditor(_ item: HistoryCalendarItem) {
        manualFlowDraft = nil
        switch item.kind {
        case .flow:
            guard let session = item.session,
                  activeFlowStore.activeSession?.id != session.id else { return }
            inspectedItem = item
        case .rest:
            editedBreak = item.flowBreak
        }
    }

    private func openSeries(_ block: HistoryCalendarSeriesBlock) {
        manualFlowDraft = nil
        inspectedSeries = block
    }

    private func openDayTimeline(_ date: Date) {
        manualFlowDraft = nil
        let day = calendar.startOfDay(for: date)
        selectedDate = day
        inspectedDay = HistoryDayTimelineSelection(
            date: day,
            items: filteredItems.filter {
                calendar.isDate($0.startedAt, inSameDayAs: day)
            }
        )
    }

    private func updateManualFlowDraft(startedAt: Date, endedAt: Date) {
        manualFlowDraft?.startedAt = startedAt
        manualFlowDraft?.endedAt = endedAt
    }

    private func moveHistoryPayload(_ payload: String, to day: Date) -> Bool {
        guard let item = historyItem(for: payload) else { return false }
        let components = calendar.dateComponents([.hour, .minute, .second], from: item.startedAt)
        guard let target = calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: components.second ?? 0,
            of: day
        ) else { return false }
        return moveHistoryItem(item, target)
    }

    private func moveHistoryItem(_ item: HistoryCalendarItem, _ targetDate: Date) -> Bool {
        guard item.kind == .flow,
              let session = item.session,
              activeFlowStore.activeSession?.id != session.id else { return false }

        historyEditor.move(
            session: session,
            itemStartedAt: item.startedAt,
            to: targetDate,
            modelContext: modelContext
        )
        do {
            try modelContext.save()
            selectedDate = calendar.startOfDay(for: targetDate)
            selectedDayItemID = item.id
            return true
        } catch {
            modelContext.rollback()
            return false
        }
    }

    private func historyItem(for payload: String) -> HistoryCalendarItem? {
        guard payload.hasPrefix("history-flow:") else { return nil }
        return filteredItems.first { "history-flow:\($0.id)" == payload }
    }
}

private struct HistoryDayTimelineSelection: Identifiable {
    let date: Date
    let items: [HistoryCalendarItem]

    var id: Date { date }
}

private struct HistoryCalendarPeriodWorkspace<Content: View, Inspector: View>: View {
    let sidebarHeader: AnyView
    @ViewBuilder let content: Content
    @ViewBuilder let inspector: Inspector

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 900 {
                HStack(spacing: 0) {
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    VStack(spacing: 0) {
                        sidebarHeader

                        Divider()

                        inspector
                            .padding(16)
                        Spacer(minLength: 0)
                    }
                    .frame(width: min(390, max(310, geometry.size.width * 0.30)))
                    .background(Color.secondary.opacity(0.035))
                }
            } else {
                VStack(spacing: 0) {
                    sidebarHeader
                    Divider()
                    content
                }
            }
        }
    }
}

struct HistoryVisibilityMenu: View {
    @Binding var visibleKinds: Set<HistoryCalendarItemKind>

    var body: some View {
        Menu {
            filterToggle(String(localized: "Flow"), symbol: "waveform.path", kinds: [.flow])
            filterToggle(String(localized: "休憩"), symbol: "cup.and.saucer", kinds: [.rest])
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel(String(localized: "表示内容"))
    }

    private func filterToggle(_ title: String, symbol: String, kinds: Set<HistoryCalendarItemKind>) -> some View {
        Toggle(isOn: Binding(
            get: { kinds.isSubset(of: visibleKinds) },
            set: { isVisible in
                if isVisible { visibleKinds.formUnion(kinds) } else { visibleKinds.subtract(kinds) }
            }
        )) {
            Label(title, systemImage: symbol)
        }
        .toggleStyle(.checkbox)
    }

}

struct HistoryTimeGrid: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    let selectedDate: Date
    let range: HistoryCalendarRange
    let items: [HistoryCalendarItem]
    let hourRange: Range<Int>
    let hourHeight: CGFloat
    let selectedItemID: String?
    @Binding var manualFlowDraft: HistoryFlowCreationDraft?
    let onSelectSeries: (HistoryCalendarSeriesBlock) -> Void
    let onSelect: (HistoryCalendarItem) -> Void
    let onMove: (HistoryCalendarItem, Date) -> Bool
    let onAddRecord: (Date) -> Void

    @State private var dragState: HistoryCalendarDragState?

    private let timeAxisWidth: CGFloat = 72
    private let minimumDayWidth: CGFloat = 132
    private let minimumVisibleSegmentHeight: CGFloat = 2
    private let minimumVisibleDraftHeight: CGFloat = 12

    private var days: [Date] {
        let interval = range.interval(
            containing: selectedDate,
            calendar: calendar,
            dayBoundary: dayBoundary
        )
        let count = range == .day ? 1 : 7
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    var body: some View {
        GeometryReader { geometry in
            let available = max(0, geometry.size.width - timeAxisWidth)
            let dayWidth = range == .day
                ? max(minimumDayWidth, available)
                : max(minimumDayWidth, available / CGFloat(days.count))
            let contentWidth = timeAxisWidth + dayWidth * CGFloat(days.count)

            ScrollView(.horizontal) {
                hourScroll(dayWidth: dayWidth, contentWidth: contentWidth)
                    .frame(width: contentWidth)
            }
            .scrollIndicators(.automatic)
        }
    }

    private func dayHeader(dayWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: timeAxisWidth, height: 54)
            ForEach(days, id: \.self) { day in
                VStack(spacing: 3) {
                    Text(day.formatted(.dateTime.locale(locale).weekday(.abbreviated)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(calendar.component(.day, from: day))")
                        .font(.title3.weight(calendar.isDateInToday(day) ? .bold : .medium))
                        .foregroundStyle(calendar.isDateInToday(day) ? Color.accentColor : Color.primary)
                }
                .frame(width: dayWidth, height: 54)
                .background(calendar.isDate(day, inSameDayAs: selectedDate) ? Color.accentColor.opacity(0.045) : .clear)
                .overlay(alignment: .leading) { Divider() }
            }
        }
    }

    private func hourScroll(dayWidth: CGFloat, contentWidth: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ZStack(alignment: .topLeading) {
                            hourGrid(dayWidth: dayWidth, contentWidth: contentWidth)
                                .allowsHitTesting(false)
                            emptyTimeSelectionLayer(dayWidth: dayWidth)
                            timedItems(dayWidth: dayWidth)
                            manualFlowDraftBlock(dayWidth: dayWidth)
                            currentTimeLine(dayWidth: dayWidth)
                        }
                        .frame(width: contentWidth, height: hourHeight * CGFloat(hourRange.count))
                    } header: {
                        VStack(spacing: 0) {
                            dayHeader(dayWidth: dayWidth)
                            Divider()
                        }
                        .background(.bar)
                    }
                }
                .frame(width: contentWidth)
            }
            .scrollIndicators(.hidden, axes: .vertical)
            .onAppear { scrollToRelevantHour(proxy) }
            .onChange(of: selectedDate) { _, _ in scrollToRelevantHour(proxy) }
            .onChange(of: range) { _, _ in scrollToRelevantHour(proxy) }
        }
    }

    private func hourGrid(dayWidth: CGFloat, contentWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(Array(hourRange), id: \.self) { hour in
                    HStack(alignment: .top, spacing: 8) {
                        Text(hourLabel(hour))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: timeAxisWidth - 8, alignment: .trailing)
                            .offset(y: -7)
                        Rectangle()
                            .fill(Color.secondary.opacity(hour == 0 ? 0.22 : 0.13))
                            .frame(height: 1)
                    }
                    .frame(width: contentWidth, height: hourHeight, alignment: .topLeading)
                    .id("history-hour-\(hour)")
                }

                HStack(spacing: 8) {
                    Color.clear.frame(width: timeAxisWidth - 8)
                    Rectangle().fill(Color.secondary.opacity(0.13)).frame(height: 1)
                }
                .frame(width: contentWidth, alignment: .leading)
            }

            ForEach(0...days.count, id: \.self) { index in
                Rectangle()
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 1, height: hourHeight * CGFloat(hourRange.count))
                    .offset(x: timeAxisWidth + CGFloat(index) * dayWidth)
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        guard let date = calendar.date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: selectedDate
        ) else {
            return "\(hour)"
        }
        return date.formatted(.dateTime.locale(locale).hour())
    }

    @ViewBuilder
    private func timedItems(dayWidth: CGFloat) -> some View {
        ForEach(Array(days.enumerated()), id: \.offset) { dayIndex, day in
            let dayItems = timedItems(on: day)
            let seriesBlocks = HistoryCalendarSeriesProjector().project(dayItems)
            let placements = seriesPlacementMap(for: seriesBlocks, day: day)

            if range == .week {
                ForEach(seriesBlocks) { block in
                    weekSeriesBlock(
                        block,
                        placement: placements[block.id]
                            ?? HistoryOverlapPlacement(id: block.id, lane: 0, laneCount: 1),
                        day: day,
                        dayIndex: dayIndex,
                        dayWidth: dayWidth
                    )
                }
            } else {
                ForEach(seriesBlocks) { block in
                    seriesBackdrop(
                        block,
                        placement: placements[block.id]
                            ?? HistoryOverlapPlacement(id: block.id, lane: 0, laneCount: 1),
                        day: day,
                        dayIndex: dayIndex,
                        dayWidth: dayWidth
                    )
                }

                ForEach(dayItems) { item in
                    timedItem(
                        item,
                        placement: placements[item.seriesBlockID]
                            ?? HistoryOverlapPlacement(id: item.seriesBlockID, lane: 0, laneCount: 1),
                        day: day,
                        dayIndex: dayIndex,
                        dayWidth: dayWidth
                    )
                }
            }
        }
    }

    private func seriesBackdrop(
        _ block: HistoryCalendarSeriesBlock,
        placement: HistoryOverlapPlacement,
        day: Date,
        dayIndex: Int,
        dayWidth: CGFloat
    ) -> some View {
        let width = (dayWidth - 8) / CGFloat(placement.laneCount)
        let itemFrame = frame(from: block.startedAt, to: block.endedAt, on: day)
        return HistorySeriesBackdrop()
            .frame(width: max(32, width - 3), height: itemFrame.height)
            .offset(
                x: timeAxisWidth + CGFloat(dayIndex) * dayWidth + 4
                    + CGFloat(placement.lane) * width,
                y: itemFrame.y
            )
            .allowsHitTesting(false)
    }

    private func timedItem(
        _ item: HistoryCalendarItem,
        placement: HistoryOverlapPlacement,
        day: Date,
        dayIndex: Int,
        dayWidth: CGFloat
    ) -> some View {
        let width = (dayWidth - 8) / CGFloat(placement.laneCount)
        let itemFrame = frame(for: item, on: day)
        return HistoryTimedItemView(
            item: item,
            isCompact: item.durationSeconds < 15 * 60 || itemFrame.height < 24,
            isMicro: itemFrame.height < 12,
            isSelected: selectedItemID == item.id,
            previewStartedAt: dragState?.itemID == item.id ? dragState?.targetDate : nil
        ) {
            manualFlowDraft = nil
            onSelect(item)
        }
        .frame(width: max(32, width - 3), height: itemFrame.height, alignment: .topLeading)
        .clipped()
        .offset(
            x: timeAxisWidth + CGFloat(dayIndex) * dayWidth + 4 + CGFloat(placement.lane) * width
                + dragTranslation(for: item).width,
            y: itemFrame.y + dragTranslation(for: item).height
        )
        .zIndex(dragState?.itemID == item.id ? 10 : 0)
        .shadow(
            color: .black.opacity(dragState?.itemID == item.id ? 0.28 : 0),
            radius: dragState?.itemID == item.id ? 8 : 0,
            y: dragState?.itemID == item.id ? 4 : 0
        )
        .highPriorityGesture(
            calendarDragGesture(
                for: item,
                dayIndex: dayIndex,
                dayWidth: dayWidth,
                itemWidth: max(32, width - 3),
                frame: itemFrame
            ),
            including: canMove(item) ? .all : .none
        )
    }

    private func weekSeriesBlock(
        _ block: HistoryCalendarSeriesBlock,
        placement: HistoryOverlapPlacement,
        day: Date,
        dayIndex: Int,
        dayWidth: CGFloat
    ) -> some View {
        let width = (dayWidth - 8) / CGFloat(placement.laneCount)
        let itemFrame = frame(from: block.startedAt, to: block.endedAt, on: day)
        return HistoryWeekSeriesBlockView(block: block) {
            manualFlowDraft = nil
            onSelectSeries(block)
        }
        .frame(width: max(32, width - 3), height: max(18, itemFrame.height))
        .offset(
            x: timeAxisWidth + CGFloat(dayIndex) * dayWidth + 4
                + CGFloat(placement.lane) * width,
            y: itemFrame.y
        )
    }

    @ViewBuilder
    private func emptyTimeSelectionLayer(dayWidth: CGFloat) -> some View {
        let height = hourHeight * CGFloat(hourRange.count)
        ForEach(Array(days.enumerated()), id: \.offset) { dayIndex, day in
            Color.clear
                .contentShape(Rectangle())
                .frame(width: dayWidth, height: height)
                .offset(x: timeAxisWidth + CGFloat(dayIndex) * dayWidth)
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            let y = min(max(0, value.location.y), height)
                            manualFlowDraft = nil
                            onAddRecord(date(on: day, y: y))
                        }
                )
                .dropDestination(for: String.self) { payloads, location in
                    guard let payload = payloads.first,
                          payload.hasPrefix("history-flow:"),
                          let item = items.first(where: { "history-flow:\($0.id)" == payload }) else {
                        return false
                    }
                    let y = min(max(0, location.y), height)
                    return onMove(item, date(on: day, y: y))
                }
        }
    }

    @ViewBuilder
    private func manualFlowDraftBlock(dayWidth: CGFloat) -> some View {
        if let draft = manualFlowDraft,
           let dayIndex = days.firstIndex(where: { calendar.isDate($0, inSameDayAs: draft.startedAt) }) {
            let day = days[dayIndex]
            let interval = visibleInterval(on: day)
            let start = max(draft.startedAt, interval.start)
            let end = min(draft.endedAt, interval.end)

            if end > start {
                let y = CGFloat(start.timeIntervalSince(interval.start) / 3600) * hourHeight
                let height = max(minimumVisibleDraftHeight, CGFloat(end.timeIntervalSince(start) / 3600) * hourHeight)

                HistoryManualFlowDraftView(startedAt: draft.startedAt, endedAt: draft.endedAt)
                    .frame(width: dayWidth - 8, height: height, alignment: .topLeading)
                    .offset(x: timeAxisWidth + CGFloat(dayIndex) * dayWidth + 4, y: y)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func currentTimeLine(dayWidth: CGFloat) -> some View {
        let currentHour = calendar.component(.hour, from: .now)
        if let todayIndex = days.firstIndex(where: calendar.isDateInToday),
           hourRange.contains(currentHour) {
            let components = calendar.dateComponents([.hour, .minute, .second], from: .now)
            let hourSeconds = (components.hour ?? 0) * 3600
            let minuteSeconds = (components.minute ?? 0) * 60
            let seconds = CGFloat(hourSeconds + minuteSeconds + (components.second ?? 0))
            let y = (seconds / 3600 - CGFloat(hourRange.lowerBound)) * hourHeight
            HStack(spacing: 0) {
                Circle().fill(Color.red).frame(width: 7, height: 7)
                Rectangle().fill(Color.red).frame(height: 1)
            }
            .frame(width: dayWidth)
            .offset(x: timeAxisWidth + CGFloat(todayIndex) * dayWidth - 3, y: y - 3)
            .allowsHitTesting(false)
        }
    }

    private func timedItems(on day: Date) -> [HistoryCalendarItem] {
        let dayStart = calendar.startOfDay(for: day)
        let start = calendar.date(byAdding: .hour, value: hourRange.lowerBound, to: dayStart)!
        let end = calendar.date(byAdding: .hour, value: hourRange.upperBound, to: dayStart)!
        return items.filter { $0.startedAt < end && $0.endedAt > start }
    }

    private func seriesPlacementMap(
        for blocks: [HistoryCalendarSeriesBlock],
        day: Date
    ) -> [String: HistoryOverlapPlacement] {
        let interval = visibleInterval(on: day)
        let clippedBlocks = blocks.map { block in
            HistoryCalendarSeriesBlock(
                id: block.id,
                seriesID: block.seriesID,
                startedAt: max(block.startedAt, interval.start),
                endedAt: min(block.endedAt, interval.end),
                items: block.items
            )
        }
        return HistoryCalendarSeriesProjector().placements(for: clippedBlocks)
    }

    private func frame(for item: HistoryCalendarItem, on day: Date) -> (y: CGFloat, height: CGFloat) {
        frame(from: item.startedAt, to: item.endedAt, on: day)
    }

    private func frame(
        from startedAt: Date,
        to endedAt: Date,
        on day: Date
    ) -> (y: CGFloat, height: CGFloat) {
        let interval = visibleInterval(on: day)
        let start = max(startedAt, interval.start)
        let end = min(endedAt, interval.end)
        let startSeconds = max(0, start.timeIntervalSince(interval.start))
        let duration = max(0, end.timeIntervalSince(start))
        return (
            CGFloat(startSeconds / 3600) * hourHeight,
            max(minimumVisibleSegmentHeight, CGFloat(duration / 3600) * hourHeight)
        )
    }

    private func visibleInterval(on day: Date) -> DateInterval {
        let dayStart = calendar.startOfDay(for: day)
        return DateInterval(
            start: calendar.date(byAdding: .hour, value: hourRange.lowerBound, to: dayStart)!,
            end: calendar.date(byAdding: .hour, value: hourRange.upperBound, to: dayStart)!
        )
    }

    private func date(on day: Date, y: CGFloat) -> Date {
        let interval = visibleInterval(on: day)
        let rawSeconds = TimeInterval(y / hourHeight * 3600)
        let roundedSeconds = (rawSeconds / 300).rounded() * 300
        return min(interval.end.addingTimeInterval(-60), interval.start.addingTimeInterval(roundedSeconds))
    }

    private func calendarDragGesture(
        for item: HistoryCalendarItem,
        dayIndex: Int,
        dayWidth: CGFloat,
        itemWidth: CGFloat,
        frame: (y: CGFloat, height: CGFloat)
    ) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard canMove(item) else { return }
                manualFlowDraft = nil
                dragState = resolvedDragState(
                    for: item,
                    dayIndex: dayIndex,
                    dayWidth: dayWidth,
                    itemWidth: itemWidth,
                    frame: frame,
                    proposedTranslation: value.translation
                )
            }
            .onEnded { value in
                guard canMove(item) else { return }
                let resolved = resolvedDragState(
                    for: item,
                    dayIndex: dayIndex,
                    dayWidth: dayWidth,
                    itemWidth: itemWidth,
                    frame: frame,
                    proposedTranslation: value.translation
                )
                let didMove = onMove(item, resolved.targetDate)
                withAnimation(.snappy(duration: 0.18)) {
                    dragState = nil
                }
                if !didMove {
                    onSelect(item)
                }
            }
    }

    private func resolvedDragState(
        for item: HistoryCalendarItem,
        dayIndex: Int,
        dayWidth: CGFloat,
        itemWidth: CGFloat,
        frame: (y: CGFloat, height: CGFloat),
        proposedTranslation: CGSize
    ) -> HistoryCalendarDragState {
        let gridHeight = hourHeight * CGFloat(hourRange.count)
        let originalX = CGFloat(dayIndex) * dayWidth + 4
        let clampedX = min(
            dayWidth * CGFloat(days.count) - itemWidth,
            max(0, originalX + proposedTranslation.width)
        )
        let clampedY = min(
            max(0, gridHeight - frame.height),
            max(0, frame.y + proposedTranslation.height)
        )
        let targetDayIndex = min(
            days.count - 1,
            max(0, Int((clampedX + itemWidth / 2) / dayWidth))
        )
        let targetDate = date(on: days[targetDayIndex], y: clampedY)

        return HistoryCalendarDragState(
            itemID: item.id,
            translation: CGSize(width: clampedX - originalX, height: clampedY - frame.y),
            targetDate: targetDate
        )
    }

    private func dragTranslation(for item: HistoryCalendarItem) -> CGSize {
        dragState?.itemID == item.id ? dragState?.translation ?? .zero : .zero
    }

    private func canMove(_ item: HistoryCalendarItem) -> Bool {
        guard item.kind == .flow, let status = item.session?.status else { return false }
        return status == .completed || status == .interrupted
    }

    private func scrollToRelevantHour(_ proxy: ScrollViewProxy) {
        let timed = items.filter { item in
            days.contains { day in
                calendar.isDate(item.startedAt, inSameDayAs: day)
            }
        }
        let targetDate: Date
        if days.contains(where: calendar.isDateInToday) {
            targetDate = .now
        } else {
            targetDate = timed.map(\.startedAt).min() ?? selectedDate.addingTimeInterval(8 * 3600)
        }
        let hour = min(hourRange.upperBound - 1, max(hourRange.lowerBound, calendar.component(.hour, from: targetDate) - 1))
        DispatchQueue.main.async {
            proxy.scrollTo("history-hour-\(hour)", anchor: .top)
        }
    }
}

private struct HistoryCalendarDragState {
    let itemID: String
    let translation: CGSize
    let targetDate: Date
}

struct HistoryFlowCreationDraft: Identifiable {
    let id = UUID()
    var startedAt: Date
    var endedAt: Date
}

private struct HistoryManualFlowDraftView: View {
    let startedAt: Date
    let endedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(localized: "新しいFlow"))
                .font(.caption.weight(.semibold))
            Text("\(startedAt.formatted(date: .omitted, time: .shortened))–\(endedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.white.opacity(0.75), lineWidth: 1.5)
        }
        .accessibilityLabel(String(localized: "新しいFlow、\(startedAt.formatted(date: .omitted, time: .shortened))から\(endedAt.formatted(date: .omitted, time: .shortened))"))
    }
}

private struct HistoryTimedItemView: View {
    let item: HistoryCalendarItem
    let isCompact: Bool
    let isMicro: Bool
    let isSelected: Bool
    let previewStartedAt: Date?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isMicro {
                    Color.clear
                } else if isCompact {
                    HStack(spacing: 4) {
                        Text(item.symbol)
                        Text(item.title)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    .font(.caption2)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(item.symbol)
                            Text(item.title)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        }
                        Text(timeText)
                            .font(.caption2.monospacedDigit())
                            .lineLimit(1)
                        if item.durationSeconds >= 35 * 60 {
                            Text(item.subtitle)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                    .font(.caption)
                }
            }
            .foregroundStyle(item.kind == .rest ? Color.primary : Color.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, isCompact ? 4 : 5)
            .padding(.vertical, isMicro ? 0 : (isCompact ? 2 : 5))
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: isMicro ? 1 : 5))
            .overlay {
                RoundedRectangle(cornerRadius: isMicro ? 1 : 5)
                    .stroke(isSelected ? Color.accentColor : borderColor, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .help("\(item.title)\n\(timeText)\n\(item.subtitle)")
        .accessibilityLabel("\(item.title)、\(timeText)、\(item.subtitle)")
    }

    private var background: Color {
        if item.kind == .rest { return Color.secondary.opacity(0.15) }
        return Color(hex: item.colorHex).opacity(0.9)
    }

    private var borderColor: Color {
        item.kind == .rest ? Color.secondary.opacity(0.35) : Color(hex: item.colorHex)
    }

    private var timeText: String {
        let start = previewStartedAt ?? item.startedAt
        let end = start.addingTimeInterval(TimeInterval(item.durationSeconds))
        return "\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))"
    }
}

private struct HistorySeriesBackdrop: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.secondary.opacity(0.09))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
            }
    }
}

private struct HistoryMonthGrid: View {
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

struct HistoryBreakEditorView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    let flowBreak: FlowBreak
    let onClose: (() -> Void)?
    @State private var minutes: Int
    @State private var endTime: Date
    @State private var errorMessage: String?

    private let editor = FlowBreakEditor()

    init(flowBreak: FlowBreak, onClose: (() -> Void)? = nil) {
        self.flowBreak = flowBreak
        self.onClose = onClose
        let resolvedEnd = flowBreak.resolvedEndAt(referenceDate: .now)
        let duration = resolvedEnd.timeIntervalSince(flowBreak.startedAt)
        _minutes = State(initialValue: max(1, Int(ceil(duration / 60))))
        _endTime = State(initialValue: resolvedEnd)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                if onClose != nil {
                    Button { close() } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(String(localized: "戻る"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Label(flowBreak.isLongBreak ? String(localized: "Long Break") : String(localized: "休憩"), systemImage: "cup.and.saucer")
                        .font(.title3.weight(.semibold))
                }
                Spacer()

                if onClose == nil {
                    Button { close() } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(String(localized: "閉じる"))
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "開始"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(flowBreak.startedAt.formatted(date: .omitted, time: .shortened))
                        .monospacedDigit()
                }

                Image(systemName: "arrow.right")
                    .foregroundStyle(.tertiary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "終了"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker(
                        String(localized: "終了"),
                        selection: endTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }

                Spacer(minLength: 8)
            }

            HStack {
                Text(String(localized: "長さ"))
                Spacer()
                TextField(String(localized: "分"), value: $minutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 76)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: minutes) { _, newValue in
                        guard (FlowBreakEditor.minimumDurationMinutes...FlowBreakEditor.maximumDurationMinutes)
                            .contains(newValue) else { return }
                        endTime = flowBreak.startedAt.addingTimeInterval(TimeInterval(newValue * 60))
                    }
                Text(String(localized: "分"))
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button(String(localized: "キャンセル")) { close() }
                Spacer()
                Button(String(localized: "保存")) { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(minutes < FlowBreakEditor.minimumDurationMinutes || minutes > FlowBreakEditor.maximumDurationMinutes)
            }
        }
        .padding(18)
        .frame(width: 360, height: 280)
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: { endTime },
            set: { selectedEnd in
                let normalizedEnd = editor.normalizedEndTime(
                    for: flowBreak,
                    selectedTime: selectedEnd,
                    calendar: calendar
                )
                endTime = normalizedEnd
                minutes = editor.durationMinutes(
                    from: flowBreak.startedAt,
                    to: normalizedEnd
                )
            }
        )
    }

    private func save() {
        do {
            _ = try editor.updateDuration(
                of: flowBreak,
                minutes: minutes,
                modelContext: modelContext,
                protectedSessionID: activeFlowStore.activeSession?.id
            )
            close()
        } catch FlowBreakEditorError.activeFlowWouldMove {
            errorMessage = String(localized: "実行中のFlowは移動できません。")
        } catch {
            errorMessage = String(localized: "休憩を保存できませんでした。")
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}
