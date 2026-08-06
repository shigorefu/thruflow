import SwiftUI

struct IOSFlowStreamView: View {
    let snapshot: FlowDashboardSnapshot
    let isActive: Bool
    let mode: FlowMode
    let breakStyle: FlowStreamBreakStyle
    let breakInteraction: FlowBreakInteraction?
    let isRenderingEnabled: Bool

    var body: some View {
        FlowStreamSurface(
            blocks: snapshot.blocks,
            flowCount: snapshot.flowCount,
            palette: snapshot.palette,
            paletteWeights: snapshot.paletteWeights,
            dailySeed: snapshot.dailyVisualSeed,
            isActive: isActive,
            mode: mode,
            breakStyle: breakStyle,
            breakInteraction: breakInteraction,
            isRenderingEnabled: isRenderingEnabled
        )
    }
}

struct IOSFlowTimelineView: View {
    let snapshot: FlowDashboardSnapshot
    let now: Date
    let onSelect: (IOSFlowTimelineSelection) -> Void

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
                        .frame(height: 14)

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

                    ForEach(snapshot.sessionGroups) { group in
                        timelineSessionGroup(
                            group,
                            range: range,
                            width: proxy.size.width,
                            height: 14
                        )
                    }
                }
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height,
                    alignment: .leading
                )
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            guard let selection = selection(
                                at: value.location.x,
                                range: range,
                                width: proxy.size.width
                            ) else { return }
                            onSelect(selection)
                        }
                )
            }
            .frame(height: 44)

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

    private func timelineSessionGroup(
        _ group: FlowDashboardSessionGroup,
        range: FlowTimelineRange,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        let startX = width * range.fraction(for: group.startedAt)
        let endX = width * range.fraction(for: group.endedAt)
        let groupWidth = max(endX - startX, 4)
        let groupDuration = max(1, group.endedAt.timeIntervalSince(group.startedAt))

        return ZStack(alignment: .leading) {
            ForEach(group.segments) { segment in
                let segmentStart = max(0, segment.startedAt.timeIntervalSince(group.startedAt))
                let segmentDuration = max(1, segment.endedAt.timeIntervalSince(segment.startedAt))

                Rectangle()
                    .fill(Color(hex: segment.colorHex))
                    .frame(
                        width: max(1, groupWidth * segmentDuration / groupDuration),
                        height: height
                    )
                    .offset(x: groupWidth * segmentStart / groupDuration)
            }
        }
        .frame(width: groupWidth, height: height, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: height / 2))
        .shadow(
            color: Color(hex: group.segments.first?.colorHex ?? "#8E8E93")
                .opacity(group.isActive ? 0.55 : 0.40),
            radius: group.isActive ? 5 : 4
        )
        .offset(x: startX)
    }

    private func selection(
        at x: CGFloat,
        range: FlowTimelineRange,
        width: CGFloat
    ) -> IOSFlowTimelineSelection? {
        guard width > 0 else { return nil }

        let segmentCandidates = snapshot.segments.compactMap { segment -> IOSFlowTimelineHitCandidate? in
            guard segment.session.status == .completed else { return nil }
            return hitCandidate(
                selection: .segment(segment),
                start: segment.startedAt,
                end: segment.endedAt,
                x: x,
                range: range,
                width: width
            )
        }
        let breakCandidates = snapshot.breaks.compactMap { flowBreak -> IOSFlowTimelineHitCandidate? in
            guard !flowBreak.isActive else { return nil }
            return hitCandidate(
                selection: .flowBreak(flowBreak),
                start: flowBreak.startedAt,
                end: flowBreak.endedAt,
                x: x,
                range: range,
                width: width
            )
        }
        let candidates = segmentCandidates + breakCandidates
        let directHits = candidates.filter(\.containsVisibleInterval)
        return (directHits.isEmpty ? candidates : directHits)
            .min { $0.distanceFromCenter < $1.distanceFromCenter }?
            .selection
    }

    private func hitCandidate(
        selection: IOSFlowTimelineSelection,
        start: Date,
        end: Date,
        x: CGFloat,
        range: FlowTimelineRange,
        width: CGFloat
    ) -> IOSFlowTimelineHitCandidate? {
        let startX = width * range.fraction(for: start)
        let endX = width * range.fraction(for: end)
        let lowerBound = min(startX, endX)
        let upperBound = max(startX, endX)
        let center = lowerBound + ((upperBound - lowerBound) / 2)
        let distance = abs(x - center)
        let containsVisibleInterval = x >= lowerBound && x <= upperBound

        guard containsVisibleInterval || distance <= 22 else { return nil }
        return IOSFlowTimelineHitCandidate(
            selection: selection,
            distanceFromCenter: distance,
            containsVisibleInterval: containsVisibleInterval
        )
    }
}

enum IOSFlowTimelineSelection {
    case segment(FlowDashboardSegment)
    case flowBreak(FlowDashboardBreak)
}

private struct IOSFlowTimelineHitCandidate {
    let selection: IOSFlowTimelineSelection
    let distanceFromCenter: CGFloat
    let containsVisibleInterval: Bool
}
