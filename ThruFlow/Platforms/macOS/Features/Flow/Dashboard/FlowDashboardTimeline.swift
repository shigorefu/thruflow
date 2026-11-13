#if os(macOS)
import SwiftData
import SwiftUI

struct FlowDashboardTimeline: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore
    @EnvironmentObject private var settings: AppSettings

    let snapshot: FlowDashboardSnapshot
    let now: Date
    @Binding var hoveredTimelineItem: TimelineItem?
    @Binding var selectedTimelineItem: TimelineItem?
    let onInspectSegment: (FlowDashboardSegment) -> Void

    private let historyEditor = FlowHistoryEditor()
    private let breakEditor = FlowBreakEditor()

    var body: some View {
        let activeTimerEndAt = settings.showsTimelinePlannedEnd
            ? activeFlowStore.activeTimerTimelineEndAt(now: now)
            : nil
        let range = FlowTimelineRange(
            date: now,
            segments: snapshot.segments,
            breaks: snapshot.breaks,
            activeTimerEndAt: activeTimerEndAt
        )
        let activeSeriesID = snapshot.breaks.first(where: \.isActive)?.seriesID
            ?? snapshot.sessionGroups.first(where: \.isActive)?.segments.first?.seriesID

        return VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "今日のタイムライン"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            GeometryReader { proxy in
                let selectedSegment = snapshot.segments.first { selectedTimelineItem == .segment($0.id) }
                let selectedBreak = snapshot.breaks.first { selectedTimelineItem == .flowBreak($0.id) }
                let anchorPoint = timelineAnchorPoint(
                    from: selectedSegment?.startedAt ?? selectedBreak?.startedAt,
                    to: selectedSegment?.endedAt ?? selectedBreak?.endedAt,
                    range: range,
                    totalWidth: proxy.size.width
                )

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(timelineTrackColor)
                        .frame(height: 18)
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.primary.opacity(0.06))
                        }

                    ForEach(snapshot.seriesSpans) { span in
                        let displayedEndAt = span.id == activeSeriesID
                            ? (activeTimerEndAt ?? span.endedAt)
                            : span.endedAt
                        let width = intervalWidth(
                            from: span.startedAt,
                            to: displayedEndAt,
                            range: range,
                            totalWidth: proxy.size.width,
                            minimumWidth: 12
                        )

                        Capsule()
                            .fill(Color.secondary.opacity(0.42))
                            .frame(width: width, height: 18)
                            .position(
                                x: intervalCenter(
                                    from: span.startedAt,
                                    to: displayedEndAt,
                                    range: range,
                                    totalWidth: proxy.size.width
                                ),
                                y: proxy.size.height / 2
                            )
                            .allowsHitTesting(false)
                    }

                    ForEach(snapshot.sessionGroups) { group in
                        let displayedEndAt = group.isActive
                            ? (activeTimerEndAt ?? group.endedAt)
                            : group.endedAt
                        let width = intervalWidth(
                            from: group.startedAt,
                            to: displayedEndAt,
                            range: range,
                            totalWidth: proxy.size.width,
                            minimumWidth: 5
                        )
                        let height: CGFloat = 18

                        ZStack(alignment: .leading) {
                            ForEach(group.segments) { segment in
                                let segmentStart = max(0, segment.startedAt.timeIntervalSince(group.startedAt))
                                let segmentDuration = max(1, segment.endedAt.timeIntervalSince(segment.startedAt))
                                let groupDuration = max(
                                    1,
                                    displayedEndAt.timeIntervalSince(group.startedAt)
                                )

                                Rectangle()
                                    .fill(Color(hex: segment.colorHex))
                                    .frame(
                                        width: max(1, width * segmentDuration / groupDuration),
                                        height: height
                                    )
                                    .offset(x: width * segmentStart / groupDuration)
                            }
                        }
                        .frame(width: width, height: height, alignment: .leading)
                        .background {
                            if group.isActive && activeTimerEndAt != nil {
                                Color(hex: group.segments.first?.colorHex ?? "#8E8E93")
                                    .opacity(0.2)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: height / 2))
                        .shadow(
                            color: Color(hex: group.segments.first?.colorHex ?? "#8E8E93")
                                .opacity(group.isActive ? 0.55 : 0.40),
                            radius: group.isActive ? 5 : 4
                        )
                        .position(
                            x: intervalCenter(
                                from: group.startedAt,
                                to: displayedEndAt,
                                range: range,
                                totalWidth: proxy.size.width
                            ),
                            y: proxy.size.height / 2
                        )
                        .allowsHitTesting(false)
                    }

                    ForEach(snapshot.breaks) { flowBreak in
                        let width = intervalWidth(
                            from: flowBreak.startedAt,
                            to: flowBreak.endedAt,
                            range: range,
                            totalWidth: proxy.size.width,
                            minimumWidth: 5
                        )

                        Button {
                            guard !flowBreak.isActive else { return }
                            selectedTimelineItem = .flowBreak(flowBreak.id)
                        } label: {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    hoveredTimelineItem == .flowBreak(flowBreak.id)
                                        ? Color.white.opacity(0.13)
                                        : Color.white.opacity(0.001)
                                )
                                .frame(width: max(width, 10), height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .position(
                            x: intervalCenter(
                                from: flowBreak.startedAt,
                                to: flowBreak.endedAt,
                                range: range,
                                totalWidth: proxy.size.width
                            ),
                            y: proxy.size.height / 2
                        )
                        .zIndex(hoveredTimelineItem == .flowBreak(flowBreak.id) ? 2 : 1)
                        .help(breakHelpText(flowBreak))
                        .accessibilityLabel(breakHelpText(flowBreak))
                    }

                    ForEach(snapshot.segments) { segment in
                        let width = segmentWidth(segment, range: range, totalWidth: proxy.size.width)
                        let centerX = intervalCenter(
                            from: segment.startedAt,
                            to: segment.endedAt,
                            range: range,
                            totalWidth: proxy.size.width
                        )

                        Button {
                            selectedTimelineItem = .segment(segment.id)
                        } label: {
                            Color.clear
                            .frame(width: max(width, 14), height: 20)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .position(x: centerX, y: proxy.size.height / 2)
                        .zIndex(hoveredTimelineItem == .segment(segment.id) ? 2 : 1)
                        .accessibilityLabel(
                            String(localized: "\(segment.taskTitle), \(focusText(segment.focusSeconds))")
                        )
                    }

                    if let hoveredSegment = snapshot.segments.first(where: {
                        hoveredTimelineItem == .segment($0.id)
                    }), selectedTimelineItem == nil {
                        TimelineSegmentHoverCard(segment: hoveredSegment)
                            .position(
                                x: timelineCardX(
                                    from: hoveredSegment.startedAt,
                                    to: hoveredSegment.endedAt,
                                    range: range,
                                    totalWidth: proxy.size.width
                                ),
                                y: -24
                            )
                            .allowsHitTesting(false)
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
                            .zIndex(3)
                    }

                    if let hoveredBreak = snapshot.breaks.first(where: {
                        hoveredTimelineItem == .flowBreak($0.id)
                    }), selectedTimelineItem == nil {
                        TimelineBreakHoverCard(flowBreak: hoveredBreak)
                            .position(
                                x: timelineCardX(
                                    from: hoveredBreak.startedAt,
                                    to: hoveredBreak.endedAt,
                                    range: range,
                                    totalWidth: proxy.size.width
                                ),
                                y: -24
                            )
                            .allowsHitTesting(false)
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
                            .zIndex(3)
                    }

                }
                .frame(maxHeight: .infinity)
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        hoveredTimelineItem = timelineItem(
                            at: location.x,
                            snapshot: snapshot,
                            range: range,
                            totalWidth: proxy.size.width
                        )
                    case .ended:
                        hoveredTimelineItem = nil
                    }
                }
                .popover(
                    isPresented: timelinePopoverBinding,
                    attachmentAnchor: .point(anchorPoint),
                    arrowEdge: .bottom
                ) {
                    if let selectedSegment {
                        TimelineSegmentPopover(
                            segment: selectedSegment,
                            onDelete: selectedSegment.isActive ? nil : {
                                deleteTimelineSegment(selectedSegment)
                            },
                            onOpenHistory: selectedSegment.isActive ? nil : {
                                selectedTimelineItem = nil
                                onInspectSegment(selectedSegment)
                            }
                        )
                    } else if let selectedBreak {
                        TimelineBreakPopover(
                            flowBreak: selectedBreak,
                            onSave: { minutes in
                                let result = try breakEditor.updateDuration(
                                    of: selectedBreak.storedBreak,
                                    minutes: minutes,
                                    modelContext: modelContext,
                                    protectedSessionID: activeFlowStore.activeSession?.id
                                )
                                selectedTimelineItem = nil
                                return result
                            }
                        )
                    }
                }
            }
            .frame(height: 24)

            HStack {
                let dates = range.labelDates()
                ForEach(Array(dates.enumerated()), id: \.offset) { index, date in
                    Text(timelineLabel(date))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if index != dates.indices.last { Spacer() }
                }
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.38),
            value: timelineAnimationDates(range: range, activeTimerEndAt: activeTimerEndAt)
        )
    }

    private func timelineAnimationDates(
        range: FlowTimelineRange,
        activeTimerEndAt: Date?
    ) -> [Date] {
        [range.start, range.end] + (activeTimerEndAt.map { [$0] } ?? [])
    }

    private var timelineTrackColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.46 : 0.12)
    }

    private func segmentWidth(
        _ segment: FlowDashboardSegment,
        range: FlowTimelineRange,
        totalWidth: CGFloat
    ) -> CGFloat {
        intervalWidth(
            from: segment.startedAt,
            to: segment.endedAt,
            range: range,
            totalWidth: totalWidth,
            minimumWidth: 6
        )
    }

    private func intervalWidth(
        from start: Date,
        to end: Date,
        range: FlowTimelineRange,
        totalWidth: CGFloat,
        minimumWidth: CGFloat
    ) -> CGFloat {
        max(minimumWidth, totalWidth * (range.fraction(for: end) - range.fraction(for: start)))
    }

    private func intervalCenter(
        from start: Date,
        to end: Date,
        range: FlowTimelineRange,
        totalWidth: CGFloat
    ) -> CGFloat {
        let visibleStart = totalWidth * range.fraction(for: start)
        let visibleEnd = totalWidth * range.fraction(for: end)
        return visibleStart + ((visibleEnd - visibleStart) / 2)
    }

    private func breakHelpText(_ flowBreak: FlowDashboardBreak) -> String {
        let name = flowBreak.isLongBreak ? String(localized: "長休憩") : String(localized: "休憩")
        let duration = TimelineSegmentFormat.duration(flowBreak.durationSeconds)
        return String(localized: "☕️ \(name)（\(duration)）")
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

    private func timelineCardX(
        from start: Date,
        to end: Date,
        range: FlowTimelineRange,
        totalWidth: CGFloat
    ) -> CGFloat {
        let center = intervalCenter(from: start, to: end, range: range, totalWidth: totalWidth)
        return min(max(center, 95), max(95, totalWidth - 95))
    }

    private func timelineAnchorPoint(
        from start: Date?,
        to end: Date?,
        range: FlowTimelineRange,
        totalWidth: CGFloat
    ) -> UnitPoint {
        guard let start, let end, totalWidth > 0 else { return .center }
        let center = intervalCenter(from: start, to: end, range: range, totalWidth: totalWidth)
        return UnitPoint(x: min(max(center / totalWidth, 0), 1), y: 0.5)
    }

    private func timelineItem(
        at x: CGFloat,
        snapshot: FlowDashboardSnapshot,
        range: FlowTimelineRange,
        totalWidth: CGFloat
    ) -> TimelineItem? {
        let segmentCandidates = snapshot.segments.compactMap { segment -> (TimelineItem, CGFloat)? in
                let segmentVisualWidth = segmentWidth(segment, range: range, totalWidth: totalWidth)
                let width = max(segmentVisualWidth, 14)
                let center = intervalCenter(
                    from: segment.startedAt,
                    to: segment.endedAt,
                    range: range,
                    totalWidth: totalWidth
                )
                let distance = abs(x - center)
                guard distance <= width / 2 else { return nil }
                return (.segment(segment.id), distance)
            }
        let breakCandidates = snapshot.breaks.compactMap { flowBreak -> (TimelineItem, CGFloat)? in
            let visualWidth = intervalWidth(
                from: flowBreak.startedAt,
                to: flowBreak.endedAt,
                range: range,
                totalWidth: totalWidth,
                minimumWidth: 10
            )
            let width = max(visualWidth, 14)
            let center = intervalCenter(
                from: flowBreak.startedAt,
                to: flowBreak.endedAt,
                range: range,
                totalWidth: totalWidth
            )
            let distance = abs(x - center)
            guard distance <= width / 2 else { return nil }
            return (.flowBreak(flowBreak.id), distance)
        }

        return (segmentCandidates + breakCandidates)
            .min { $0.1 < $1.1 }?
            .0
    }

    private func timelineLabel(_ date: Date) -> String {
        return date.formatted(.dateTime.locale(locale).hour().minute())
    }

    private func deleteTimelineSegment(_ segment: FlowDashboardSegment) {
        selectedTimelineItem = nil

        do {
            if let storedSegment = segment.storedSegment {
                try historyEditor.delete(
                    segment: storedSegment,
                    from: segment.session,
                    modelContext: modelContext
                )
            } else {
                try historyEditor.delete(session: segment.session, modelContext: modelContext)
            }
        } catch {
            modelContext.rollback()
            PersistenceIssueCenter.shared.report(error, operation: .historyUpdate)
            return
        }

        _ = modelContext.saveReporting(.flowUpdate)
    }
}

enum TimelineItem: Equatable {
    case segment(UUID)
    case flowBreak(UUID)
}
#endif
