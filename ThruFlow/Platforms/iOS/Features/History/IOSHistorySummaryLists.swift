#if os(iOS)
import SwiftUI

struct IOSHistoryTaskSummaryList: View {
    let snapshot: DayHistorySnapshot
    let searchText: String
    let visibleTypes: Set<AreaType>

    private var visibleTasks: [DayHistoryTaskSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return snapshot.taskSummaries.filter { task in
            guard visibleTypes.contains(task.areaType) else { return false }
            guard !query.isEmpty else { return true }
            return [task.title, task.areaName, task.areaSymbol]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if visibleTasks.isEmpty {
                    ContentUnavailableView(
                        String(localized: "記録なし"),
                        systemImage: "clock.arrow.circlepath",
                        description: Text(String(localized: "この期間には集中記録もタスクもありません。"))
                    )
                    .padding(.top, 72)
                } else {
                    ForEach(visibleTasks) { task in
                        IOSHistorySummaryRow(
                            symbol: task.areaSymbol,
                            title: task.title,
                            subtitle: task.areaName,
                            colorHex: task.areaColorHex,
                            focusSeconds: task.focusSeconds,
                            flowCount: task.flowCount
                        )
                    }
                }
            }
            .padding(16)
        }
    }
}

struct IOSHistoryAreaSummaryList: View {
    let snapshot: DayHistorySnapshot
    let searchText: String
    let visibleTypes: Set<AreaType>

    private var recordedAreas: [DayHistoryAreaSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return snapshot.areaSummaries.filter { area in
            guard area.focusSeconds > 0 else { return false }
            guard visibleTypes.contains(area.areaType) else { return false }
            guard !query.isEmpty else { return true }
            return [area.name, area.symbol]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if recordedAreas.isEmpty {
                    ContentUnavailableView(
                        String(localized: "記録なし"),
                        systemImage: "clock.arrow.circlepath",
                        description: Text(String(localized: "この期間には集中記録もタスクもありません。"))
                    )
                    .padding(.top, 72)
                } else {
                    ForEach(recordedAreas) { area in
                        IOSHistorySummaryRow(
                            symbol: area.symbol,
                            title: area.name,
                            subtitle: nil,
                            colorHex: area.colorHex,
                            focusSeconds: area.focusSeconds,
                            flowCount: area.flowCount
                        )
                    }
                }
            }
            .padding(16)
        }
    }
}

struct IOSHistoryAggregateFilterMenu: View {
    @Binding var visibleTypes: Set<AreaType>
    let neutralLabel: String

    var body: some View {
        Menu {
            filterToggle(neutralLabel, type: .neutral)
            filterToggle(String(localized: "習慣一覧"), type: .habit)
            filterToggle(String(localized: "ナイス"), type: .nice)
        } label: {
            Image(
                systemName: visibleTypes.count == AreaType.allCases.count
                    ? "line.3.horizontal.decrease"
                    : "line.3.horizontal.decrease.circle.fill"
            )
            .frame(width: 30, height: 30)
        }
        .accessibilityLabel(String(localized: "表示内容"))
    }

    private func filterToggle(_ title: String, type: AreaType) -> some View {
        Toggle(
            title,
            isOn: Binding(
                get: { visibleTypes.contains(type) },
                set: { isVisible in
                    if isVisible {
                        visibleTypes.insert(type)
                    } else {
                        visibleTypes.remove(type)
                    }
                }
            )
        )
    }
}

private struct IOSHistorySummaryRow: View {
    let symbol: String
    let title: String
    let subtitle: String?
    let colorHex: String
    let focusSeconds: Int
    let flowCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(symbol)
                .font(.title3)
                .frame(width: 38, height: 38)
                .background(Color(hex: colorHex).opacity(0.16), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                if let subtitle, subtitle != title {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(focusDurationText)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text(String(localized: "集中\(flowCount)回"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }

    private var focusDurationText: String {
        let minutes = focusSeconds / 60
        if minutes < 60 {
            return String(localized: "\(minutes)分")
        }
        return String(localized: "\(minutes / 60)時間\(minutes % 60)分")
    }
}
#endif
