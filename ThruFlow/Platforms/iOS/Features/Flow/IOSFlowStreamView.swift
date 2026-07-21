import SwiftUI

struct IOSFlowStreamView: View {
    let snapshot: FlowDashboardSnapshot
    let isActive: Bool
    let mode: FlowMode

    var body: some View {
        FlowStreamSurface(
            blocks: snapshot.blocks,
            flowCount: snapshot.flowCount,
            palette: snapshot.palette,
            isActive: isActive,
            mode: mode,
            isRenderingEnabled: true
        )
    }
}

struct IOSFlowTimelineView: View {
    let snapshot: FlowDashboardSnapshot
    let now: Date

    @Environment(\.calendar) private var calendar

    var body: some View {
        let range = FlowTimelineRange(
            date: now,
            segments: snapshot.segments,
            breaks: snapshot.breaks,
            calendar: calendar
        )

        VStack(alignment: .leading, spacing: 7) {
            Text(String(localized: "今日のタイムライン"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))

                    ForEach(snapshot.seriesSpans) { span in
                        timelineCapsule(
                            start: span.startedAt,
                            end: span.endedAt,
                            range: range,
                            width: proxy.size.width,
                            color: Color.secondary.opacity(0.42),
                            height: 14
                        )
                    }

                    ForEach(snapshot.segments) { segment in
                        timelineCapsule(
                            start: segment.startedAt,
                            end: segment.endedAt,
                            range: range,
                            width: proxy.size.width,
                            color: Color(hex: segment.colorHex),
                            height: 14
                        )
                    }
                }
            }
            .frame(height: 14)

            HStack {
                ForEach(range.labelDates(calendar: calendar), id: \.self) { date in
                    Text(date, format: .dateTime.hour(.twoDigits(amPM: .omitted)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if date != range.labelDates(calendar: calendar).last {
                        Spacer()
                    }
                }
            }
        }
    }

    private func timelineCapsule(
        start: Date,
        end: Date,
        range: FlowTimelineRange,
        width: CGFloat,
        color: Color,
        height: CGFloat
    ) -> some View {
        let startX = width * range.fraction(for: start)
        let endX = width * range.fraction(for: end)
        return Capsule()
            .fill(color)
            .frame(width: max(endX - startX, 4), height: height)
            .offset(x: startX)
    }
}
