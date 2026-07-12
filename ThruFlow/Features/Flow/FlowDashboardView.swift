//
//  FlowDashboardView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/12.
//

import SwiftData
import SwiftUI

struct FlowDashboardView: View {
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore
    @Query(sort: \FlowSession.startedAt, order: .forward) private var sessions: [FlowSession]

    @State private var inspectedSession: FlowSession?

    private let builder = FlowDashboardBuilder()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let snapshot = snapshot(now: timeline.date)

            VStack(spacing: 0) {
                FlowMiniPlayerView(style: .dashboard)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        dashboardHeader(snapshot: snapshot)
                        streamSurface(snapshot: snapshot)
                        timelineSurface(snapshot: snapshot)
                    }
                    .frame(maxWidth: 1180)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 22)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Flow")
        .sheet(item: $inspectedSession) { session in
            FlowHistoryInspectorView(session: session)
        }
    }

    private func snapshot(now: Date) -> FlowDashboardSnapshot {
        builder.build(
            date: now,
            sessions: sessions,
            activeSessionID: activeFlowStore.activeSession?.id,
            activeFocusSeconds: activeFlowStore.actualFocusSeconds(now: now)
        )
    }

    private func dashboardHeader(snapshot: FlowDashboardSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("今日のFlow")
                    .font(.title2.weight(.semibold))
                Text(dateText(snapshot.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            metric(value: focusText(snapshot.totalFocusSeconds), label: "集中時間")
            metric(value: blockText(snapshot.blocks), label: "ブロック")
            metric(value: "\(snapshot.flowCount)", label: "Flow")
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func streamSurface(snapshot: FlowDashboardSnapshot) -> some View {
        ZStack(alignment: .bottomLeading) {
            FlowStreamView(
                intensity: snapshot.intensity,
                flowCount: snapshot.flowCount,
                palette: snapshot.palette,
                isActive: activeFlowStore.phase == .focusing
            )

            if snapshot.totalFocusSeconds == 0 {
                Text("最初のFlowを始めると、ここに今日の流れが育ちます")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(18)
            }
        }
        .frame(minHeight: 250, idealHeight: 310, maxHeight: 360)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }

    private func timelineSurface(snapshot: FlowDashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日のタイムライン")
                    .font(.headline)
                Spacer()
                Text("Flowを選択すると詳細を編集できます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.07))
                        .frame(height: 18)

                    ForEach(snapshot.segments) { segment in
                        Button {
                            guard !segment.isActive else { return }
                            inspectedSession = segment.session
                        } label: {
                            Capsule()
                                .fill(Color(hex: segment.colorHex))
                                .frame(
                                    width: segmentWidth(segment, totalWidth: proxy.size.width),
                                    height: segment.isActive ? 20 : 14
                                )
                        }
                        .buttonStyle(.plain)
                        .offset(x: proxy.size.width * segment.startFraction)
                        .help("\(segment.symbol) \(segment.taskTitle) · \(focusText(segment.focusSeconds))")
                        .accessibilityLabel("\(segment.taskTitle)、\(focusText(segment.focusSeconds))")
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 22)

            HStack {
                ForEach(["0:00", "6:00", "12:00", "18:00", "24:00"], id: \.self) { label in
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if label != "24:00" { Spacer() }
                }
            }
        }
    }

    private func segmentWidth(_ segment: FlowDashboardSegment, totalWidth: CGFloat) -> CGFloat {
        max(6, totalWidth * (segment.endFraction - segment.startFraction))
    }

    private func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "ja_JP")).month(.wide).day().weekday(.wide))
    }

    private func focusText(_ seconds: Int) -> String {
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        return hours > 0 ? "\(hours)時間\(minutes)分" : "\(minutes)分"
    }

    private func blockText(_ blocks: Double) -> String {
        let rounded = (blocks * 10).rounded() / 10
        return rounded == rounded.rounded() ? "\(Int(rounded))" : String(format: "%.1f", rounded)
    }
}

#Preview {
    FlowDashboardView()
        .environmentObject(ActiveFlowStore())
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self], inMemory: true)
}
