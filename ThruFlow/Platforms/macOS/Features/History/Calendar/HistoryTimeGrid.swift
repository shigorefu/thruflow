#if os(macOS)
import SwiftData
import SwiftUI

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
            .clipped()
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
                        .background(.bar, ignoresSafeAreaEdges: [])
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
        if ScreenshotMode.isEnabled(), let earliest = timed.map(\.startedAt).min() {
            targetDate = earliest
        } else if days.contains(where: calendar.isDateInToday) {
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
            Text(String(localized: "新しい集中記録"))
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
        .accessibilityLabel(String(localized: "新しい集中記録、\(startedAt.formatted(date: .omitted, time: .shortened))から\(endedAt.formatted(date: .omitted, time: .shortened))まで"))
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
        .accessibilityLabel(accessibilityText)
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

    private var accessibilityText: String {
        let titleAndTime = String(localized: "\(item.title), \(timeText)")
        return String(localized: "\(titleAndTime), \(item.subtitle)")
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
#endif
