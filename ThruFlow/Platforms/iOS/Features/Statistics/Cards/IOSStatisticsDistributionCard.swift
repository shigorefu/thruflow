#if os(iOS)
import Charts
import SwiftUI

struct IOSStatisticsDistributionCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var dimension: IOSStatisticsDistributionDimension
    let items: [StatisticsDistributionItem]
    let totalFocusSeconds: Int

    @State private var selectedItemID: String?

    private var selectedItem: StatisticsDistributionItem? {
        guard let selectedItemID else { return nil }
        return items.first { $0.id == selectedItemID }
    }

    var body: some View {
        IOSStatisticsCard(
            title: String(localized: "集中時間の内訳"),
            headerAccessory: {
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
                    .frame(maxWidth: .infinity, minHeight: 190)
            } else {
                VStack(spacing: 18) {
                    Chart(items) { item in
                        SectorMark(
                            angle: .value(String(localized: "集中時間"), item.focusSeconds),
                            innerRadius: .ratio(0.60),
                            outerRadius: .ratio(
                                selectedItemID == nil || selectedItemID == item.id ? 1 : 0.96
                            ),
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
                    .frame(width: 190, height: 190)
                    .overlay {
                        VStack(spacing: 3) {
                            Text(IOSStatisticsFormatting.duration(
                                selectedItem?.focusSeconds ?? totalFocusSeconds
                            ))
                            .font(.headline.monospacedDigit())
                            Text(selectedItem?.name ?? String(localized: "集中時間"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            if selectedItem != nil {
                                Button {
                                    selectedItemID = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(String(localized: "すべて"))
                            }
                        }
                        .frame(maxWidth: 98)
                    }

                    ZStack {
                        if let selectedItem {
                            StatisticsDistributionDetailView(item: selectedItem)
                            .id(selectedItem.id)
                            .transition(.opacity)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(items) { item in
                                    Button {
                                        selectedItemID = item.id
                                    } label: {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(Color(hex: item.colorHex ?? "#8E8E93"))
                                                .frame(width: 9, height: 9)
                                            Text([item.symbol, item.name].compactMap { $0 }.joined(separator: " "))
                                                .lineLimit(1)
                                            Spacer(minLength: 8)
                                            Text(IOSStatisticsFormatting.duration(item.focusSeconds))
                                                .monospacedDigit()
                                                .foregroundStyle(.secondary)
                                        }
                                        .font(.callout)
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
