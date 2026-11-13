#if os(macOS)
import Charts
import SwiftUI

enum StatisticsDistributionDimension: String, CaseIterable, Identifiable {
    case task
    case area
    case project

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .task:
            String(localized: "タスク別")
        case .area:
            String(localized: "方向別")
        case .project:
            String(localized: "プロジェクト別")
        }
    }
}

struct StatisticsDistributionCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var dimension: StatisticsDistributionDimension
    let items: [StatisticsDistributionItem]
    let totalFocusSeconds: Int
    let availableWidth: CGFloat
    let compact: Bool

    @State private var selectedItemID: String?

    private var isHorizontal: Bool { compact || availableWidth >= 410 }
    private var chartSize: CGFloat {
        if compact { return min(126, max(106, availableWidth * 0.28)) }
        return min(availableWidth >= 510 ? 182 : 146, max(100, availableWidth - 36))
    }

    private var selectedItem: StatisticsDistributionItem? {
        guard let selectedItemID else { return nil }
        return items.first { $0.id == selectedItemID }
    }

    var body: some View {
        StatisticsAnalysisCard(
            title: String(localized: "集中時間の内訳"),
            systemImage: "chart.pie",
            compact: compact
        ) {
            dimensionPicker
                .pickerStyle(.menu)
        } content: {
            if items.isEmpty {
                StatisticsEmptyState(label: String(localized: "この期間の集中記録はありません"))
                    .frame(maxWidth: .infinity, minHeight: compact ? 108 : 170)
            } else {
                let spacing: CGFloat = compact ? 12 : 16
                let layout = isHorizontal
                    ? AnyLayout(HStackLayout(alignment: .center, spacing: spacing))
                    : AnyLayout(VStackLayout(alignment: .center, spacing: spacing))
                layout {
                    donut
                    detailOrLegend
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: dimension) { _, _ in
            clearSelection()
        }
        .onChange(of: items.map(\.id)) { _, identifiers in
            if let selectedItemID, !identifiers.contains(selectedItemID) {
                clearSelection()
            }
        }
    }

    private var dimensionPicker: some View {
        Picker(String(localized: "内訳"), selection: $dimension) {
            ForEach(StatisticsDistributionDimension.allCases) { dimension in
                Text(dimension.displayName).tag(dimension)
            }
        }
        .labelsHidden()
        .controlSize(.small)
    }

    private var donut: some View {
        Chart(items) { item in
            SectorMark(
                angle: .value(String(localized: "集中時間"), item.focusSeconds),
                innerRadius: .ratio(0.60),
                outerRadius: .ratio(selectedItemID == nil || selectedItemID == item.id ? 1 : 0.96),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(Color(hex: item.colorHex ?? "#8E8E93"))
            .opacity(selectedItemID == nil || selectedItemID == item.id ? 1 : 0.16)
        }
        .chartLegend(.hidden)
        .chartOverlay { _ in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                selectItem(at: value.location, in: geometry.size)
                            }
                    )
            }
        }
        .frame(width: chartSize, height: chartSize)
        .overlay {
            VStack(spacing: 3) {
                Text(StatisticsFormatting.duration(selectedItem?.focusSeconds ?? totalFocusSeconds))
                    .font((compact ? Font.caption.bold() : .headline).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
                Text(selectedItem?.name ?? String(localized: "集中時間"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if selectedItem != nil {
                    Button(action: clearSelection) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(String(localized: "すべて"))
                    .accessibilityLabel(String(localized: "すべて"))
                }
            }
            .frame(maxWidth: chartSize * 0.52)
        }
    }

    private var detailOrLegend: some View {
        ZStack {
            if let selectedItem {
                StatisticsDistributionDetailView(item: selectedItem)
                    .id(selectedItem.id)
                    .transition(.opacity)
            } else {
                VStack(alignment: .leading, spacing: compact ? 0 : 3) {
                    ForEach(items) { item in
                        Button {
                            selectedItemID = item.id
                        } label: {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: item.colorHex ?? "#8E8E93"))
                                    .frame(width: 8, height: 8)
                                    .accessibilityHidden(true)
                                Text([item.symbol, item.name].compactMap { $0 }.joined(separator: " "))
                                    .lineLimit(1)
                                Spacer(minLength: 6)
                                Text(StatisticsFormatting.duration(item.focusSeconds))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .fixedSize()
                            }
                            .font(.caption)
                            .padding(.vertical, compact ? 3 : 5)
                            .padding(.horizontal, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: selectedItemID)
    }

    private func itemID(at angle: Double) -> String? {
        var upperBound = 0.0
        for item in items {
            upperBound += Double(max(0, item.focusSeconds))
            if angle <= upperBound {
                return item.id
            }
        }
        return items.last?.id
    }

    private func selectItem(at location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let deltaX = location.x - center.x
        let deltaY = location.y - center.y
        let outerRadius = min(size.width, size.height) / 2
        let distance = hypot(deltaX, deltaY)

        guard distance >= outerRadius * 0.42, distance <= outerRadius else { return }

        let radians = atan2(deltaX, -deltaY)
        let normalizedRadians = radians >= 0 ? radians : radians + (2 * .pi)
        let total = Double(items.reduce(0) { $0 + max(0, $1.focusSeconds) })
        guard total > 0 else { return }

        selectedItemID = itemID(at: normalizedRadians / (2 * .pi) * total)
    }

    private func clearSelection() {
        selectedItemID = nil
    }
}
#endif
