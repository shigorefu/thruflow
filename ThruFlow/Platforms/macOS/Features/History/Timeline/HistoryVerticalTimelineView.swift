#if os(macOS)
import AppKit
import SwiftUI

struct HistoryVerticalTimelineView: View {
    let items: [HistoryCalendarItem]
    let selectedItemID: String?
    let gapInterval: DateInterval?
    let onSelect: (HistoryCalendarItem) -> Void

    private var entries: [HistoryVerticalTimelineEntry] {
        HistoryVerticalTimelineEntry.build(items: items, gapInterval: gapInterval)
    }

    private let chainPolicy = HistoryTimelineChainPolicy()

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView(
                String(localized: "この日に記録なし"),
                systemImage: "clock.badge.questionmark"
            )
            .padding(.vertical, 56)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        switch entry {
                        case .item(let item):
                            HistoryTimelineItemRow(
                                item: item,
                                isFirst: !connectsPrevious(item, at: index),
                                isLast: !connectsNext(item, at: index),
                                isSelected: item.id == selectedItemID,
                                onSelect: onSelect
                            )
                        case .gap(let gap):
                            HistoryTimelineGapRow(gap: gap)
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    private func connectsPrevious(_ item: HistoryCalendarItem, at index: Int) -> Bool {
        guard index > entries.startIndex,
              case .item(let previous) = entries[index - 1] else {
            return false
        }
        return chainPolicy.connects(previous, to: item)
    }

    private func connectsNext(_ item: HistoryCalendarItem, at index: Int) -> Bool {
        let nextIndex = index + 1
        guard nextIndex < entries.endIndex,
              case .item(let next) = entries[nextIndex] else {
            return false
        }
        return chainPolicy.connects(item, to: next)
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
        HStack(alignment: .center, spacing: 12) {
            Text(item.startedAt.formatted(.dateTime.locale(locale).hour().minute()))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .trailing)

            timelineRail

            Button {
                onSelect(item)
            } label: {
                HStack(spacing: 12) {
                    Text(item.displaySymbol)
                        .font(.title3)
                        .frame(width: 30, height: 30)
                        .background(itemColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.displayTitle)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                        Text(timingText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        if !item.displaySubtitle.isEmpty {
                            Text(item.displaySubtitle)
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
        .fixedSize(horizontal: false, vertical: true)
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
        Duration.seconds(Double(item.durationSeconds)).formatted(
            .units(allowed: [.hours, .minutes], width: .abbreviated, maximumUnitCount: 2)
        )
    }

    private var timingText: String {
        let start = item.startedAt.formatted(date: .omitted, time: .shortened)
        let end = item.endedAt.formatted(date: .omitted, time: .shortened)
        return String(localized: "\(start)〜\(end)（\(durationText)）")
    }
}

private struct HistoryTimelineGapRow: View {
    @Environment(\.locale) private var locale

    let gap: HistoryTimelineGap

    var body: some View {
        HStack(spacing: 12) {
            Text(timeRange)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 54, alignment: .trailing)

            Circle()
                .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
                .frame(width: 8, height: 8)
            .frame(width: 12)
            .frame(height: 82)

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
            .padding(.vertical, 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(timeRange)：記録なし"))
    }

    private var timeRange: String {
        let start = gap.startedAt.formatted(.dateTime.locale(locale).hour().minute())
        let end = gap.endedAt.formatted(.dateTime.locale(locale).hour().minute())
        return "\(start)–\(end)"
    }
}
#endif
