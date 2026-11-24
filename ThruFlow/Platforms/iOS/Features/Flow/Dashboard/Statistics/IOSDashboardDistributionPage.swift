#if os(iOS)
import SwiftUI

struct IOSDashboardDistributionPage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let snapshot: FlowDashboardSnapshot
    @Binding var distributionMode: IOSDashboardDistributionMode

    var body: some View {
        let rows = distributionRows(in: snapshot)
        VStack(spacing: 12) {
            Picker(String(localized: "集計単位"), selection: $distributionMode) {
                ForEach(IOSDashboardDistributionMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            distributionDonut(rows: rows, snapshot: snapshot)
                .productContentFade(on: distributionMode)

            VStack(alignment: .leading, spacing: 9) {
                ForEach(rows.prefix(4)) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(row.symbol) \(row.title)")
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(focusText(row.focusSeconds))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        DashboardDistributionBar(
                            fraction: snapshot.focusShare(for: row.focusSeconds),
                            color: Color(hex: row.colorHex)
                        )
                    }
                }
                if !rows.isEmpty {
                    DashboardDistributionScale(total: focusText(snapshot.totalFocusSeconds))
                }
            }
            .productContentFade(on: distributionMode)

            if rows.isEmpty {
                Text(String(localized: "Flowを記録すると時間配分が表示されます"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func distributionDonut(
        rows: [IOSDashboardDistributionRow],
        snapshot: FlowDashboardSnapshot
    ) -> some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 12)
            ForEach(distributionSlices(rows: rows, snapshot: snapshot)) { slice in
                Circle()
                    .trim(from: slice.start, to: slice.end)
                    .stroke(
                        Color(hex: slice.colorHex),
                        style: StrokeStyle(lineWidth: 12, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 1) {
                Text(focusText(snapshot.totalFocusSeconds))
                    .font(.callout.weight(.bold))
                    .minimumScaleFactor(0.7)
                    .monospacedDigit()
                Text(String(localized: "今日の集中"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 112, height: 112)
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .smooth(duration: 0.24), value: snapshot.totalFocusSeconds)
    }

    private func distributionRows(in snapshot: FlowDashboardSnapshot) -> [IOSDashboardDistributionRow] {
        switch distributionMode {
        case .task:
            snapshot.taskSummaries.map {
                IOSDashboardDistributionRow(
                    id: $0.id,
                    symbol: $0.symbol,
                    title: $0.title,
                    colorHex: $0.colorHex,
                    focusSeconds: $0.focusSeconds
                )
            }
        case .area:
            snapshot.areaSummaries.map {
                IOSDashboardDistributionRow(
                    id: $0.id.uuidString,
                    symbol: $0.symbol,
                    title: $0.name,
                    colorHex: $0.colorHex,
                    focusSeconds: $0.focusSeconds
                )
            }
        }
    }

    private func distributionSlices(
        rows: [IOSDashboardDistributionRow],
        snapshot: FlowDashboardSnapshot
    ) -> [IOSDashboardFlowSlice] {
        guard snapshot.totalFocusSeconds > 0 else { return [] }

        var cursor = 0.0
        return rows.map { row in
            let fraction = Double(row.focusSeconds) / Double(snapshot.totalFocusSeconds)
            let gap = rows.count > 1 ? min(0.004, fraction * 0.18) : 0
            let slice = IOSDashboardFlowSlice(
                id: row.id,
                start: cursor + (gap / 2),
                end: cursor + fraction - (gap / 2),
                colorHex: row.colorHex
            )
            cursor += fraction
            return slice
        }
    }

    private func focusText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes >= 60 {
            return "\(minutes / 60):\(String(format: "%02d", minutes % 60))"
        }
        return "\(minutes)\(String(localized: "分"))"
    }
}

enum IOSDashboardDistributionMode: String, CaseIterable, Identifiable {
    case task
    case area

    var id: String { rawValue }
    var title: String { self == .task ? String(localized: "タスク別") : String(localized: "方向別") }
}

private struct IOSDashboardDistributionRow: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let colorHex: String
    let focusSeconds: Int
}

private struct IOSDashboardFlowSlice: Identifiable {
    let id: String
    let start: Double
    let end: Double
    let colorHex: String
}
#endif
