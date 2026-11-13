#if os(iOS)
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
        HStack(alignment: .center, spacing: 8) {
            Text(item.startedAt.formatted(.dateTime.locale(locale).hour().minute()))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)

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
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
    }

    private var timelineRail: some View {
        // The rail follows the card's height without contributing its own height.
        Color.clear
            .frame(width: 12)
            .overlay {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(isFirst ? Color.clear : Color.secondary.opacity(0.25))
                        .frame(width: 2)

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
            }
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
#endif
