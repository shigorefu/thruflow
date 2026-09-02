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
        .equatable()
    }
}

struct IOSFlowTimelineView: View {
    let snapshot: FlowDashboardSnapshot
    let now: Date
    let onOpenHistory: (IOSFlowTimelineSelection) -> Void

    @Environment(\.calendar) private var calendar
    @State private var selectedTimelineItem: IOSFlowTimelineSelection?
    @State private var selectedAnchorX: CGFloat = 0.5

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
                            guard let hit = timelineHit(
                                at: value.location.x,
                                range: range,
                                width: proxy.size.width
                            ) else { return }
                            selectedAnchorX = hit.anchorFraction
                            selectedTimelineItem = hit.selection
                        }
                )
                .popover(
                    isPresented: timelinePopoverBinding,
                    attachmentAnchor: .point(UnitPoint(x: selectedAnchorX, y: 0.5)),
                    arrowEdge: .bottom
                ) {
                    timelinePopover
                        .presentationCompactAdaptation(.popover)
                }
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

    private var timelinePopoverBinding: Binding<Bool> {
        Binding(
            get: { selectedTimelineItem != nil },
            set: { isPresented in
                if !isPresented {
                    selectedTimelineItem = nil
                }
            }
        )
    }

    @ViewBuilder
    private var timelinePopover: some View {
        switch selectedTimelineItem {
        case .segment(let segment):
            IOSFlowTimelineSegmentPopover(
                segment: segment,
                onOpenHistory: segment.isActive ? nil : {
                    openHistory(afterDismissing: .segment(segment))
                }
            )
        case .flowBreak(let flowBreak):
            IOSFlowTimelineBreakPopover(flowBreak: flowBreak) {
                openHistory(afterDismissing: .flowBreak(flowBreak))
            }
        case nil:
            EmptyView()
        }
    }

    private func openHistory(afterDismissing selection: IOSFlowTimelineSelection) {
        selectedTimelineItem = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            onOpenHistory(selection)
        }
    }

    private func timelineHit(
        at x: CGFloat,
        range: FlowTimelineRange,
        width: CGFloat
    ) -> IOSFlowTimelineHitCandidate? {
        guard width > 0 else { return nil }

        let segmentCandidates = snapshot.segments.compactMap { segment -> IOSFlowTimelineHitCandidate? in
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
            .min { $0.distanceFromCenter < $1.distanceFromCenter }
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
            anchorFraction: min(max(center / width, 0.04), 0.96),
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
    let anchorFraction: CGFloat
    let distanceFromCenter: CGFloat
    let containsVisibleInterval: Bool
}

private struct IOSFlowTimelineSegmentPopover: View {
    @Environment(\.locale) private var locale

    let segment: FlowDashboardSegment
    let onOpenHistory: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(segment.symbol)
                    .font(.title2)
                    .frame(width: 42, height: 42)
                    .background(Color(hex: segment.colorHex).opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(segment.taskTitle)
                        .font(.headline)
                        .lineLimit(2)
                    Text(segment.areaName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if segment.isActive {
                    Text(String(localized: "実行中"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(hex: segment.colorHex))
                }
            }

            Divider()

            detail(
                String(localized: "時間"),
                value: IOSFlowTimelineFormat.interval(segment, locale: locale),
                systemImage: "clock"
            )
            detail(
                String(localized: "集中"),
                value: IOSFlowTimelineFormat.duration(segment.focusSeconds),
                systemImage: "timer"
            )
            detail(
                String(localized: "集中モード"),
                value: segment.session.mode.displayName,
                systemImage: "waveform.path"
            )

            if let onOpenHistory {
                Button(action: onOpenHistory) {
                    Label(String(localized: "Flow履歴を開く"), systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: segment.colorHex))
            }
        }
        .padding(16)
        .frame(width: 290)
    }

    private func detail(_ title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout.weight(.medium))
                .monospacedDigit()
        }
    }
}

private struct IOSFlowTimelineBreakPopover: View {
    @Environment(\.locale) private var locale

    let flowBreak: FlowDashboardBreak
    let onOpenHistory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 42, height: 42)
                    .background(Color.gray.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(flowBreak.isLongBreak ? String(localized: "長休憩") : String(localized: "休憩"))
                    .font(.headline)
            }

            Divider()

            detail(
                String(localized: "時間"),
                value: IOSFlowTimelineFormat.interval(
                    from: flowBreak.startedAt,
                    to: flowBreak.endedAt,
                    locale: locale
                ),
                systemImage: "clock"
            )
            detail(
                String(localized: "休憩時間"),
                value: IOSFlowTimelineFormat.duration(flowBreak.durationSeconds),
                systemImage: "cup.and.saucer"
            )

            Button(action: onOpenHistory) {
                Label(String(localized: "詳細"), systemImage: "arrow.up.forward.app")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .frame(width: 290)
    }

    private func detail(_ title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout.weight(.medium))
                .monospacedDigit()
        }
    }
}

private enum IOSFlowTimelineFormat {
    static func interval(_ segment: FlowDashboardSegment, locale: Locale) -> String {
        interval(from: segment.startedAt, to: segment.endedAt, locale: locale)
    }

    static func interval(from start: Date, to end: Date, locale: Locale) -> String {
        "\(time(start, locale: locale))–\(time(end, locale: locale))"
    }

    static func time(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return formatter.string(from: date)
    }

    static func duration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return remainingSeconds == 0
            ? String(localized: "\(minutes)分")
            : String(localized: "\(minutes)分\(remainingSeconds)秒")
    }
}
