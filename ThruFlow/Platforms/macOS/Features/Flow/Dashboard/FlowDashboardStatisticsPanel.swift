#if os(macOS)
import SwiftUI

struct FlowDashboardStatisticsPanel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let snapshot: FlowDashboardSnapshot
    let isLoaded: Bool
    let todoGroups: FlowDashboardTodoGroups?
    let trend: FlowDashboardTrend?
    @Binding var statisticsPage: DashboardStatisticsPage
    @Binding var distributionMode: DashboardDistributionMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(String(localized: "統計"), systemImage: "chart.bar.xaxis")
                    .font(.headline)
                Spacer()
                HStack(spacing: 5) {
                    ForEach(DashboardStatisticsPage.allCases) { page in
                        Circle()
                            .fill(page == statisticsPage ? Color.accentColor : Color.secondary.opacity(0.25))
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.trailing, 4)
                Button { moveStatisticsPage(-1) } label: {
                    Image(systemName: "chevron.left")
                }
                Button { moveStatisticsPage(1) } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.plain)
            .frame(minHeight: 22)

            Text(statisticsPage.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView {
                Group {
                    switch statisticsPage {
                    case .distribution:
                        if isLoaded {
                            statisticsDistributionPage(snapshot: snapshot)
                        } else {
                            FlowDashboardLoadingView()
                        }
                    case .trend:
                        if let trend {
                            statisticsTrendPage(trend)
                        } else {
                            FlowDashboardLoadingView()
                        }
                    case .achievement:
                        if todoGroups != nil {
                            statisticsAchievementPage
                        } else {
                            FlowDashboardLoadingView()
                        }
                    }
                }
                .id(statisticsPage)
                .transition(reduceMotion ? .identity : .opacity)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }

    private func statisticsDistributionPage(snapshot: FlowDashboardSnapshot) -> some View {
        let rows = distributionRows(snapshot: snapshot)
        return VStack(spacing: 12) {
            Picker(String(localized: "集計単位"), selection: $distributionMode) {
                ForEach(DashboardDistributionMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            statisticsDonut(snapshot: snapshot, rows: rows)
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

    private func statisticsDonut(snapshot: FlowDashboardSnapshot, rows: [DashboardDistributionRow]) -> some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 12)
            ForEach(distributionSlices(snapshot: snapshot, rows: rows)) { slice in
                Circle()
                    .trim(from: slice.start, to: slice.end)
                    .stroke(Color(hex: slice.colorHex), style: StrokeStyle(lineWidth: 12, lineCap: .butt))
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
        .frame(width: 108, height: 108)
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .smooth(duration: 0.24), value: snapshot.totalFocusSeconds)
    }

    private func statisticsTrendPage(_ trend: FlowDashboardTrend) -> some View {
        let comparison = trend.comparison

        return VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "7日"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            DashboardStatisticsBars(days: trend.days)
                .frame(height: 112)

            Divider()

            comparisonRow(String(localized: "集中時間"), value: signedMinutes(comparison.focusSecondsDelta), systemImage: "timer")
            comparisonRow(String(localized: "完了タスク"), value: signedCount(comparison.completedTaskDelta), systemImage: "checkmark.circle")
            comparisonRow(String(localized: "ブロック"), value: signedBlocks(comparison.blocksDelta), systemImage: "square.stack.3d.up")
            comparisonRow(
                String(localized: "伸びた方向"),
                value: growthText(comparison.growingArea),
                systemImage: "arrow.up.right"
            )
        }
    }

    private var statisticsAchievementPage: some View {
        let standard = todoGroups?.standard ?? []
        let habits = todoGroups?.habits ?? []
        let nice = todoGroups?.nice ?? []
        let required = standard + habits
        let completed = required.filter(\.isCompleted).count
        let ratio = required.isEmpty ? 0 : Double(completed) / Double(required.count)

        return VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: ratio)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(ratio, format: .percent.precision(.fractionLength(0)))
                    .font(.title3.bold())
                    .monospacedDigit()
            }
            .frame(width: 112, height: 112)

            achievementRow(String(localized: "タスク"), completed: standard.filter(\.isCompleted).count, total: standard.count)
            achievementRow(String(localized: "習慣一覧"), completed: habits.filter(\.isCompleted).count, total: habits.count)
            if !nice.isEmpty {
                achievementRow(String(localized: "ナイス"), completed: nice.filter(\.isCompleted).count, total: nice.count)
            }

            Text(String(localized: "今日の達成 \(completed) / \(required.count)"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private func moveStatisticsPage(_ offset: Int) {
        let pages = DashboardStatisticsPage.allCases
        guard let current = pages.firstIndex(of: statisticsPage) else { return }
        let next = (current + offset + pages.count) % pages.count
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.22)) {
            statisticsPage = pages[next]
        }
    }

    private func distributionRows(snapshot: FlowDashboardSnapshot) -> [DashboardDistributionRow] {
        switch distributionMode {
        case .task:
            snapshot.taskSummaries.map {
                DashboardDistributionRow(
                    id: $0.id,
                    symbol: $0.symbol,
                    title: $0.title,
                    colorHex: $0.colorHex,
                    focusSeconds: $0.focusSeconds
                )
            }
        case .area:
            snapshot.areaSummaries.map {
                DashboardDistributionRow(
                    id: $0.id.uuidString,
                    symbol: $0.symbol,
                    title: $0.name,
                    colorHex: $0.colorHex,
                    focusSeconds: $0.focusSeconds
                )
            }
        }
    }

    private func distributionSlices(snapshot: FlowDashboardSnapshot, rows: [DashboardDistributionRow]) -> [DashboardFlowTaskSlice] {
        guard snapshot.totalFocusSeconds > 0 else { return [] }

        var cursor = 0.0
        return rows.map { row in
            let fraction = Double(row.focusSeconds) / Double(snapshot.totalFocusSeconds)
            let gap = rows.count > 1 ? min(0.004, fraction * 0.18) : 0
            let slice = DashboardFlowTaskSlice(
                id: row.id,
                start: cursor + (gap / 2),
                end: cursor + fraction - (gap / 2),
                colorHex: row.colorHex
            )
            cursor += fraction
            return slice
        }
    }

    private func comparisonRow(_ title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.caption)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    private func achievementRow(_ title: String, completed: Int, total: Int) -> some View {
        HStack {
            Text(title)
                .font(.caption)
            Spacer()
            Text("\(completed) / \(total)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
    }

    private func signedMinutes(_ seconds: Int) -> String {
        signedValue(Int((Double(seconds) / 60).rounded()), suffix: String(localized: "分"))
    }

    private func signedCount(_ count: Int) -> String {
        signedValue(count, suffix: "")
    }

    private func signedBlocks(_ blocks: Double) -> String {
        let sign = blocks > 0 ? "+" : ""
        let value = abs(blocks) < 0.001 ? 0 : blocks
        let text = value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
        return "\(sign)\(text)"
    }

    private func signedValue(_ value: Int, suffix: String) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(value)\(suffix)"
    }

    private func growthText(_ growth: DashboardStatisticsAreaGrowth?) -> String {
        guard let growth else { return String(localized: "変化なし") }
        return String(localized: "\(growth.symbol) \(growth.name) +\(max(1, growth.focusSecondsDelta / 60))分")
    }
}

enum DashboardStatisticsPage: Int, CaseIterable, Identifiable {
    case distribution
    case trend
    case achievement

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .distribution: String(localized: "時間配分")
        case .trend: String(localized: "Flow推移")
        case .achievement: String(localized: "達成状況")
        }
    }
}

enum DashboardDistributionMode: String, CaseIterable, Identifiable {
    case task
    case area

    var id: String { rawValue }
    var title: String { self == .task ? String(localized: "タスク別") : String(localized: "方向別") }
}

private struct DashboardDistributionRow: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let colorHex: String
    let focusSeconds: Int
}

private struct DashboardFlowTaskSlice: Identifiable {
    let id: String
    let start: Double
    let end: Double
    let colorHex: String
}

struct FlowDashboardLoadingView: View {
    var body: some View {
        ProgressView()
            .controlSize(.small)
            .frame(maxWidth: .infinity, minHeight: 70)
    }
}
#endif
