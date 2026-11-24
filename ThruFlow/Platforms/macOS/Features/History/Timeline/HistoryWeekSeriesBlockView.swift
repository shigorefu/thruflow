#if os(macOS)
import AppKit
import SwiftUI

struct HistoryWeekSeriesBlockView: View {
    let block: HistoryCalendarSeriesBlock
    let action: () -> Void

    private var flowItems: [HistoryCalendarItem] {
        block.items.filter { $0.kind == .flow }
    }

    private var title: String {
        flowItems.first?.displayTitle ?? String(localized: "一連の集中記録")
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
                            Text(flowItems.first?.displaySymbol ?? "☕️")
                            Text(title)
                                .lineLimit(1)
                            if flowItems.count > 1 {
                                Text(String(localized: "（全\(flowItems.count)回）"))
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
            .fill(item.kind == .rest ? Color.secondary.opacity(0.55) : Color(hex: item.displayColorHex))
            .frame(height: segmentHeight)
            .offset(y: y)
    }

    private var helpText: String {
        let time = "\(block.startedAt.formatted(date: .omitted, time: .shortened))–\(block.endedAt.formatted(date: .omitted, time: .shortened))"
        return String(localized: "\(title)\n\(time)\n集中\(flowItems.count)回")
    }
}
#endif
