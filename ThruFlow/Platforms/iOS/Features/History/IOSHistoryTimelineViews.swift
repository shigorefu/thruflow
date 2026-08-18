#if os(iOS)
//
//  IOSHistoryTimelineViews.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/29.
//

import SwiftUI

struct IOSHistoryChronologicalTimeline: View {
    let items: [HistoryCalendarItem]
    let gapInterval: DateInterval?
    var isEmbedded = false
    let onSelect: (HistoryCalendarItem) -> Void

    private var entries: [HistoryVerticalTimelineEntry] {
        HistoryVerticalTimelineEntry.build(
            items: items,
            gapInterval: gapInterval
        )
    }

    private let chainPolicy = HistoryTimelineChainPolicy()

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView(
                String(localized: "この日に記録なし"),
                systemImage: "clock.badge.questionmark"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 56)
        } else if isEmbedded {
            timelineRows
        } else {
            ScrollView {
                timelineRows
            }
        }
    }

    private var timelineRows: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                switch entry {
                case .item(let item):
                    IOSHistoryTimelineItemRow(
                        item: item,
                        isFirst: !connectsPrevious(item, at: index),
                        isLast: !connectsNext(item, at: index),
                        onSelect: onSelect
                    )
                case .gap(let gap):
                    IOSHistoryTimelineGapRow(gap: gap)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
    }

    private func connectsPrevious(
        _ item: HistoryCalendarItem,
        at index: Int
    ) -> Bool {
        guard index > entries.startIndex,
              case .item(let previous) = entries[index - 1] else {
            return false
        }
        return chainPolicy.connects(previous, to: item)
    }

    private func connectsNext(
        _ item: HistoryCalendarItem,
        at index: Int
    ) -> Bool {
        let nextIndex = index + 1
        guard nextIndex < entries.endIndex,
              case .item(let next) = entries[nextIndex] else {
            return false
        }
        return chainPolicy.connects(item, to: next)
    }
}

private struct IOSHistoryTimelineItemRow: View {
    @Environment(\.locale) private var locale

    let item: HistoryCalendarItem
    let isFirst: Bool
    let isLast: Bool
    let onSelect: (HistoryCalendarItem) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(item.startedAt.formatted(.dateTime.locale(locale).hour().minute()))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
                .padding(.top, 14)

            timelineRail

            Button {
                onSelect(item)
            } label: {
                HStack(spacing: 10) {
                    Text(item.displaySymbol)
                        .font(.title3)
                        .frame(width: 34, height: 34)
                        .background(
                            itemColor.opacity(0.16),
                            in: RoundedRectangle(cornerRadius: 8)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.displayTitle)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(timingText)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)

                        if !item.displaySubtitle.isEmpty {
                            Text(item.displaySubtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    itemColor.opacity(item.kind == .rest ? 0.08 : 0.13),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(itemColor.opacity(0.28), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 5)
        }
        .contentShape(Rectangle())
    }

    private var timelineRail: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isFirst ? Color.clear : Color.secondary.opacity(0.25))
                .frame(width: 2, height: 15)

            Circle()
                .fill(itemColor)
                .frame(width: 10, height: 10)
                .overlay {
                    Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1)
                }

            Rectangle()
                .fill(isLast ? Color.clear : Color.secondary.opacity(0.25))
                .frame(width: 2)
        }
        .frame(width: 12)
        .frame(minHeight: 82)
    }

    private var itemColor: Color {
        item.kind == .rest ? .secondary : Color(hex: item.displayColorHex)
    }

    private var durationText: String {
        let totalSeconds = max(item.durationSeconds, 0)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var timingText: String {
        let start = item.startedAt.formatted(date: .omitted, time: .shortened)
        let end = item.endedAt.formatted(date: .omitted, time: .shortened)
        return String(localized: "\(start)〜\(end)（\(durationText)）")
    }
}

private struct IOSHistoryTimelineGapRow: View {
    @Environment(\.locale) private var locale

    let gap: HistoryTimelineGap

    var body: some View {
        HStack(spacing: 8) {
            Text(timeRange)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 42, alignment: .trailing)

            Circle()
                .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
                .frame(width: 8, height: 8)
                .frame(width: 12, height: 74)

            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 1)

                Text(String(localized: "記録なし"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 1)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var timeRange: String {
        let start = gap.startedAt.formatted(
            .dateTime.locale(locale).hour().minute()
        )
        let end = gap.endedAt.formatted(
            .dateTime.locale(locale).hour().minute()
        )
        return "\(start)–\(end)"
    }
}

struct IOSHistorySeriesWeekTimeline: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar

    let interval: DateInterval
    let items: [HistoryCalendarItem]
    let onSelectSeries: (HistoryCalendarSeriesBlock) -> Void
    let onAddRecord: (Date) -> Void

    private let hourHeight: CGFloat = 64
    private let headerHeight: CGFloat = 48
    private let timeGutter: CGFloat = 42
    private let minimumColumnWidth: CGFloat = 132
    private let projector = HistoryCalendarSeriesProjector()

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = resolvedColumnWidth(for: geometry.size.width)

            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    timelineBackground(columnWidth: columnWidth)
                    emptyTimeSelectionLayer(columnWidth: columnWidth)
                    seriesBlocks(columnWidth: columnWidth)
                    currentTimeLine(columnWidth: columnWidth)
                }
                .frame(
                    width: timeGutter + columnWidth * CGFloat(days.count),
                    height: headerHeight + hourHeight * CGFloat(hourRange.count)
                )
            }
            .defaultScrollAnchor(.topLeading)
        }
    }

    private var days: [Date] {
        (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: interval.start)
        }
    }

    private var hourRange: Range<Int> {
        let hours = days.flatMap { day -> [Int] in
            let dayInterval = HistoryCalendarRange.day.interval(
                containing: day,
                calendar: calendar,
                dayBoundary: dayBoundary
            )
            return itemsForDay(day).flatMap { item -> [Int] in
                let start = max(0, Int(item.startedAt.timeIntervalSince(dayInterval.start) / 3_600))
                let end = min(
                    24,
                    Int(ceil(item.endedAt.timeIntervalSince(dayInterval.start) / 3_600))
                )
                return [start, end]
            }
        }

        guard let minimum = hours.min(), let maximum = hours.max() else {
            return 9..<17
        }

        var lower = max(0, minimum - 1)
        var upper = min(24, maximum + 1)
        if upper - lower < 4 {
            upper = min(24, lower + 4)
            lower = max(0, upper - 4)
        }
        return lower..<max(lower + 1, upper)
    }

    private func resolvedColumnWidth(for availableWidth: CGFloat) -> CGFloat {
        let dayCount = CGFloat(max(days.count, 1))
        let availableDaysWidth = max(availableWidth - timeGutter, 0)
        return max(minimumColumnWidth, availableDaysWidth / dayCount)
    }

    private func timelineBackground(columnWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                Text(day, format: .dateTime.weekday(.abbreviated).day())
                    .font(.caption.weight(calendar.isDateInToday(day) ? .bold : .medium))
                    .foregroundStyle(
                        calendar.isDateInToday(day)
                            ? Color.accentColor
                            : Color.secondary
                    )
                    .frame(width: columnWidth, height: headerHeight)
                    .background(
                        calendar.isDateInToday(day)
                            ? Color.accentColor.opacity(0.07)
                            : Color.clear
                    )
                    .offset(x: timeGutter + CGFloat(index) * columnWidth)
            }

            ForEach(Array(hourRange), id: \.self) { hour in
                HStack(spacing: 4) {
                    Text(hour, format: .number)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .frame(width: timeGutter - 6, alignment: .trailing)
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 1)
                }
                .offset(
                    y: headerHeight
                        + CGFloat(hour - hourRange.lowerBound) * hourHeight
                )
            }

            ForEach(0...days.count, id: \.self) { index in
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 1, height: hourHeight * CGFloat(hourRange.count))
                    .offset(
                        x: timeGutter + CGFloat(index) * columnWidth,
                        y: headerHeight
                    )
            }
        }
    }

    private func seriesBlocks(columnWidth: CGFloat) -> some View {
        ForEach(Array(days.enumerated()), id: \.offset) { dayIndex, day in
            let blocks = projector.project(itemsForDay(day))
            let placements = projector.placements(for: blocks)

            ForEach(blocks) { block in
                let placement = placements[block.id]
                let laneCount = CGFloat(max(placement?.laneCount ?? 1, 1))
                let lane = CGFloat(placement?.lane ?? 0)
                let width = max((columnWidth - 6) / laneCount, 28)

                IOSHistoryWeekSeriesBlock(block: block) {
                    onSelectSeries(block)
                }
                .frame(
                    width: width,
                    height: blockHeight(block)
                )
                .offset(
                    x: timeGutter
                        + CGFloat(dayIndex) * columnWidth
                        + 3
                        + lane * width,
                    y: blockY(block, on: day)
                )
            }
        }
    }

    private func emptyTimeSelectionLayer(columnWidth: CGFloat) -> some View {
        let height = hourHeight * CGFloat(hourRange.count)

        return ForEach(Array(days.enumerated()), id: \.offset) { dayIndex, day in
            Color.clear
                .contentShape(Rectangle())
                .frame(width: columnWidth, height: height)
                .offset(
                    x: timeGutter + CGFloat(dayIndex) * columnWidth,
                    y: headerHeight
                )
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            let y = min(max(0, value.location.y), height)
                            onAddRecord(date(on: day, y: y))
                        }
                )
        }
    }

    @ViewBuilder
    private func currentTimeLine(columnWidth: CGFloat) -> some View {
        if let dayIndex = days.firstIndex(where: calendar.isDateInToday) {
            let day = days[dayIndex]
            let dayInterval = HistoryCalendarRange.day.interval(
                containing: day,
                calendar: calendar,
                dayBoundary: dayBoundary
            )
            let elapsed = Date.now.timeIntervalSince(dayInterval.start) / 3_600
            if elapsed >= Double(hourRange.lowerBound),
               elapsed <= Double(hourRange.upperBound) {
                HStack(spacing: 0) {
                    Circle().fill(Color.red).frame(width: 7, height: 7)
                    Rectangle().fill(Color.red).frame(height: 1)
                }
                .frame(width: columnWidth + 4)
                .offset(
                    x: timeGutter + CGFloat(dayIndex) * columnWidth - 3,
                    y: headerHeight
                        + CGFloat(elapsed - Double(hourRange.lowerBound)) * hourHeight
                        - 3
                )
            }
        }
    }

    private func itemsForDay(_ day: Date) -> [HistoryCalendarItem] {
        let dayInterval = HistoryCalendarRange.day.interval(
            containing: day,
            calendar: calendar,
            dayBoundary: dayBoundary
        )
        return items.filter {
            $0.startedAt < dayInterval.end && $0.endedAt > dayInterval.start
        }
    }

    private func blockY(
        _ block: HistoryCalendarSeriesBlock,
        on day: Date
    ) -> CGFloat {
        let dayInterval = HistoryCalendarRange.day.interval(
            containing: day,
            calendar: calendar,
            dayBoundary: dayBoundary
        )
        let elapsed = block.startedAt.timeIntervalSince(dayInterval.start) / 3_600
        return headerHeight
            + CGFloat(elapsed - Double(hourRange.lowerBound)) * hourHeight
            + 1
    }

    private func blockHeight(_ block: HistoryCalendarSeriesBlock) -> CGFloat {
        max(
            26,
            CGFloat(block.endedAt.timeIntervalSince(block.startedAt) / 3_600)
                * hourHeight
        )
    }

    private func date(on day: Date, y: CGFloat) -> Date {
        let dayInterval = HistoryCalendarRange.day.interval(
            containing: day,
            calendar: calendar,
            dayBoundary: dayBoundary
        )
        let hours = Double(hourRange.lowerBound) + Double(y / hourHeight)
        let snappedMinutes = (Int((hours * 60).rounded()) / 5) * 5
        return calendar.date(
            byAdding: .minute,
            value: snappedMinutes,
            to: dayInterval.start
        ) ?? dayInterval.start
    }
}

private struct IOSHistoryWeekSeriesBlock: View {
    let block: HistoryCalendarSeriesBlock
    let action: () -> Void

    private var flowItems: [HistoryCalendarItem] {
        block.items.filter { $0.kind == .flow }
    }

    var body: some View {
        Button(action: action) {
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    Color.secondary.opacity(0.12)

                    ForEach(block.items) { item in
                        segment(item, height: geometry.size.height)
                    }

                    if geometry.size.height >= 24 {
                        HStack(spacing: 3) {
                            Text(flowItems.first?.displaySymbol ?? "☕️")
                            Text(flowItems.first?.displayTitle ?? String(localized: "一連の集中記録"))
                                .lineLimit(1)
                            if flowItems.count > 1 {
                                Text(String(localized: "（全\(flowItems.count)回）"))
                                    .foregroundStyle(.white.opacity(0.78))
                            }
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func segment(
        _ item: HistoryCalendarItem,
        height: CGFloat
    ) -> some View {
        let duration = max(1, block.endedAt.timeIntervalSince(block.startedAt))
        let startRatio = item.startedAt.timeIntervalSince(block.startedAt) / duration
        let itemRatio = item.endedAt.timeIntervalSince(item.startedAt) / duration

        return Rectangle()
            .fill(
                item.kind == .rest
                    ? Color.secondary.opacity(0.55)
                    : Color(hex: item.displayColorHex)
            )
            .frame(height: max(2, CGFloat(itemRatio) * height))
            .offset(y: max(0, CGFloat(startRatio) * height))
    }
}

struct IOSHistorySeriesTimelineSheet: View {
    @Environment(\.dismiss) private var dismiss

    let block: HistoryCalendarSeriesBlock
    @State private var selectedItem: HistoryCalendarItem?

    var body: some View {
        NavigationStack {
            IOSHistoryChronologicalTimeline(
                items: block.items,
                gapInterval: nil,
                onSelect: { selectedItem = $0 }
            )
            .iosCenteredNavigationTitle(String(localized: "一連の集中記録"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "閉じる")) {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedItem) { item in
            IOSHistoryItemDetail(item: item)
                .presentationDetents(item.kind == .flow ? [.large] : [.medium])
        }
    }
}

#endif
