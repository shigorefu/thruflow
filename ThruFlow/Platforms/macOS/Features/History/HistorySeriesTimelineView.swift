//
//  HistorySeriesTimelineView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/29.
//

import SwiftUI

struct HistoryWeekSeriesBlockView: View {
    let block: HistoryCalendarSeriesBlock
    let action: () -> Void

    private var flowItems: [HistoryCalendarItem] {
        block.items.filter { $0.kind == .flow }
    }

    private var title: String {
        flowItems.first?.title ?? String(localized: "Flowシリーズ")
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
                        HStack(spacing: 4) {
                            Text(flowItems.first?.symbol ?? "☕️")
                            Text(title)
                                .lineLimit(1)
                            if flowItems.count > 1 {
                                Text(verbatim: "· \(flowItems.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
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
        .help(helpText)
        .accessibilityLabel(helpText)
    }

    private func segment(_ item: HistoryCalendarItem, height: CGFloat) -> some View {
        let duration = max(1, block.endedAt.timeIntervalSince(block.startedAt))
        let startRatio = item.startedAt.timeIntervalSince(block.startedAt) / duration
        let itemRatio = item.endedAt.timeIntervalSince(item.startedAt) / duration
        let y = max(0, CGFloat(startRatio) * height)
        let segmentHeight = max(2, CGFloat(itemRatio) * height)

        return Rectangle()
            .fill(item.kind == .rest ? Color.secondary.opacity(0.55) : Color(hex: item.colorHex))
            .frame(height: segmentHeight)
            .offset(y: y)
    }

    private var helpText: String {
        let time = "\(block.startedAt.formatted(date: .omitted, time: .shortened))–\(block.endedAt.formatted(date: .omitted, time: .shortened))"
        return "\(title)\n\(time)\n\(flowItems.count) Flow"
    }
}

struct HistorySeriesTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    let block: HistoryCalendarSeriesBlock
    let onSelect: (HistoryCalendarItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HistoryVerticalTimelineView(
                items: block.items,
                selectedItemID: nil,
                gapInterval: nil,
                onSelect: onSelect
            )
        }
        .frame(minWidth: 440, idealWidth: 500, minHeight: 480, idealHeight: 620)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "Flowシリーズ"))
                    .font(.title3.weight(.semibold))
                Text(seriesIntervalText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(localized: "閉じる"))
        }
        .padding(20)
    }

    private var seriesIntervalText: String {
        let date = block.startedAt.formatted(.dateTime.locale(locale).month().day().weekday(.abbreviated))
        let time = "\(block.startedAt.formatted(date: .omitted, time: .shortened))–\(block.endedAt.formatted(date: .omitted, time: .shortened))"
        return "\(date) · \(time)"
    }
}

struct HistoryVerticalTimelineView: View {
    let items: [HistoryCalendarItem]
    let selectedItemID: String?
    let gapInterval: DateInterval?
    let onSelect: (HistoryCalendarItem) -> Void

    private var entries: [HistoryVerticalTimelineEntry] {
        HistoryVerticalTimelineEntry.build(items: items, gapInterval: gapInterval)
    }

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView(
                String(localized: "この日に記録なし"),
                systemImage: "clock.badge.questionmark"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        switch entry {
                        case .item(let item):
                            HistoryTimelineItemRow(
                                item: item,
                                isFirst: index == entries.startIndex,
                                isLast: index == entries.index(before: entries.endIndex),
                                isSelected: item.id == selectedItemID,
                                onSelect: onSelect
                            )
                        case .gap(let gap):
                            HistoryTimelineGapRow(
                                gap: gap,
                                isFirst: index == entries.startIndex,
                                isLast: index == entries.index(before: entries.endIndex)
                            )
                        }
                    }
                }
                .padding(20)
            }
        }
    }
}

private struct HistoryTimelineItemRow: View {
    @Environment(\.locale) private var locale

    let item: HistoryCalendarItem
    let isFirst: Bool
    let isLast: Bool
    let isSelected: Bool
    let onSelect: (HistoryCalendarItem) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(item.startedAt.formatted(.dateTime.locale(locale).hour().minute()))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .trailing)
                .padding(.top, 14)

            timelineRail

            Button {
                onSelect(item)
            } label: {
                HStack(spacing: 12) {
                    Text(item.symbol)
                        .font(.title3)
                        .frame(width: 30, height: 30)
                        .background(itemColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                        Text(verbatim: "\(item.startedAt.formatted(date: .omitted, time: .shortened))–\(item.endedAt.formatted(date: .omitted, time: .shortened)) · \(durationText)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        if !item.subtitle.isEmpty {
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(itemColor.opacity(item.kind == .rest ? 0.08 : 0.13))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected ? Color.accentColor : itemColor.opacity(0.28),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 5)
        }
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
        .frame(minHeight: 78)
    }

    private var itemColor: Color {
        item.kind == .rest ? .secondary : Color(hex: item.colorHex)
    }

    private var durationText: String {
        Duration.seconds(Double(item.durationSeconds)).formatted(
            .units(allowed: [.hours, .minutes], width: .abbreviated, maximumUnitCount: 2)
        )
    }
}

private struct HistoryTimelineGapRow: View {
    @Environment(\.locale) private var locale

    let gap: HistoryTimelineGap
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(timeRange)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 54, alignment: .trailing)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : Color.secondary.opacity(0.18))
                    .frame(width: 2)

                Circle()
                    .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
                    .frame(width: 8, height: 8)

                Rectangle()
                    .fill(isLast ? Color.clear : Color.secondary.opacity(0.18))
                    .frame(width: 2)
            }
            .frame(width: 12)
            .frame(height: 52)

            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.16))
                    .frame(height: 1)

                Text(String(localized: "記録なし"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize()

                Rectangle()
                    .fill(Color.secondary.opacity(0.16))
                    .frame(height: 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(timeRange), \(String(localized: "記録なし"))"))
    }

    private var timeRange: String {
        let start = gap.startedAt.formatted(.dateTime.locale(locale).hour().minute())
        let end = gap.endedAt.formatted(.dateTime.locale(locale).hour().minute())
        return "\(start)–\(end)"
    }
}

private enum HistoryVerticalTimelineEntry: Identifiable {
    case item(HistoryCalendarItem)
    case gap(HistoryTimelineGap)

    var id: String {
        switch self {
        case .item(let item):
            "item-\(item.id)"
        case .gap(let gap):
            "gap-\(gap.startedAt.timeIntervalSinceReferenceDate)-\(gap.endedAt.timeIntervalSinceReferenceDate)"
        }
    }

    var startedAt: Date {
        switch self {
        case .item(let item):
            item.startedAt
        case .gap(let gap):
            gap.startedAt
        }
    }

    static func build(
        items: [HistoryCalendarItem],
        gapInterval: DateInterval?
    ) -> [HistoryVerticalTimelineEntry] {
        var result = items.map(HistoryVerticalTimelineEntry.item)

        if let gapInterval {
            result.append(contentsOf: HistoryTimelineGapBuilder()
                .internalGaps(in: gapInterval, items: items)
                .map(HistoryVerticalTimelineEntry.gap))
        }

        return result.sorted {
            if $0.startedAt == $1.startedAt { return $0.id < $1.id }
            return $0.startedAt < $1.startedAt
        }
    }
}
