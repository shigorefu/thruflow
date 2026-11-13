#if os(iOS)
import Charts
import SwiftUI

struct IOSStatisticsDistributionCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var dimension: IOSStatisticsDistributionDimension
    let items: [StatisticsDistributionItem]
    let totalFocusSeconds: Int
    var compact = false

    @State private var selectedItemID: String?

    private var chartSize: CGFloat { compact ? 106 : 182 }

    private var selectedItem: StatisticsDistributionItem? {
        guard let selectedItemID else { return nil }
        return items.first { $0.id == selectedItemID }
    }

    var body: some View {
        IOSStatisticsAnalysisCard(
            title: String(localized: "集中時間の内訳"),
            systemImage: "chart.pie",
            compact: compact,
            accessory: {
                Picker(String(localized: "内訳"), selection: $dimension) {
                    ForEach(IOSStatisticsDistributionDimension.allCases) { dimension in
                        Text(dimension.displayName).tag(dimension)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        ) {
            if items.isEmpty {
                IOSStatisticsEmptyState()
                    .frame(maxWidth: .infinity, minHeight: compact ? 105 : 190)
            } else {
                let layout = compact
                    ? AnyLayout(HStackLayout(alignment: .center, spacing: 10))
                    : AnyLayout(VStackLayout(spacing: 16))
                layout {
                    donut
                    details
                }
            }
        }
        .onChange(of: dimension) { _, _ in
            selectedItemID = nil
        }
        .onChange(of: items.map(\.id)) { _, identifiers in
            if let selectedItemID, !identifiers.contains(selectedItemID) {
                self.selectedItemID = nil
            }
        }
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
            .foregroundStyle(color(for: item))
            .opacity(selectedItemID == nil || selectedItemID == item.id ? 1 : 0.16)
        }
        .chartLegend(.hidden)
        .chartOverlay { _ in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture().onEnded { value in
                            selectItem(at: value.location, in: geometry.size)
                        }
                    )
            }
        }
        .frame(width: chartSize, height: chartSize)
        .overlay {
            VStack(spacing: 3) {
                Text(IOSStatisticsFormatting.duration(selectedItem?.focusSeconds ?? totalFocusSeconds))
                    .font((compact ? Font.caption : Font.title3).weight(.semibold).monospacedDigit())
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                Text(selectedItem?.name ?? String(localized: "集中時間"))
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if selectedItem != nil {
                    Button {
                        selectedItemID = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .frame(minWidth: 36, minHeight: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(String(localized: "すべて"))
                }
            }
            .frame(maxWidth: chartSize * 0.55)
        }
        .frame(maxWidth: compact ? chartSize + 12 : .infinity)
        .padding(.vertical, compact ? 3 : 12)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 14))
    }

    private var details: some View {
        ZStack {
            if let selectedItem {
                StatisticsDistributionDetailView(item: selectedItem)
                    .id(selectedItem.id)
                    .transition(.opacity)
            } else {
                VStack(alignment: .leading, spacing: compact ? 0 : 8) {
                    ForEach(items) { item in
                        legendRow(item)
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: selectedItemID)
    }

    private func legendRow(_ item: StatisticsDistributionItem) -> some View {
        Button {
            selectedItemID = item.id
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: compact ? "square.fill" : "circle.fill")
                    .font(.system(size: compact ? 7 : 8))
                    .foregroundStyle(color(for: item))
                    .accessibilityHidden(true)
                Text([item.symbol, item.name].compactMap { $0 }.joined(separator: " "))
                    .lineLimit(compact ? 1 : nil)
                    .fixedSize(horizontal: false, vertical: !compact)
                Spacer(minLength: 4)
                Text(IOSStatisticsFormatting.duration(item.focusSeconds))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(compact ? .caption : .callout)
            .padding(.horizontal, 10)
            .frame(minHeight: compact ? 20 : 44)
            .background(compact ? Color.clear : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func color(for item: StatisticsDistributionItem) -> Color {
        Color(hex: item.colorHex ?? "#8E8E93")
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
        let value = normalizedRadians / (2 * .pi) * total

        var upperBound = 0.0
        for item in items {
            upperBound += Double(max(0, item.focusSeconds))
            if value <= upperBound {
                selectedItemID = item.id
                return
            }
        }
        selectedItemID = items.last?.id
    }
}

enum IOSStatisticsDistributionDimension: String, CaseIterable, Identifiable {
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
#endif
