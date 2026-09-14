import SwiftUI

#if os(iOS) || os(macOS)
struct StatisticsDistributionDetailView: View {
    let item: StatisticsDistributionItem
    @Environment(\.locale) private var locale

    private var maximumSeconds: Int {
        max(1, item.details.map(\.focusSeconds).max() ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text([item.symbol, item.name].compactMap { $0 }.joined(separator: " "))
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            if item.details.count <= 4 {
                detailRows
            } else {
                ScrollView { detailRows }
                    .frame(height: 220)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var detailRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(item.details) { detail in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        if let date = detail.date {
                            Text(date, format: .dateTime.year().month().day())
                        } else {
                            Text(detail.name)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Text(Duration.seconds(detail.focusSeconds).formatted(
                            .units(allowed: [.minutes], width: .abbreviated).locale(locale)
                        ))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    }
                    .font(.callout)
                    ProgressView(value: Double(detail.focusSeconds), total: Double(maximumSeconds))
                        .tint(Color(hex: item.colorHex ?? "#8E8E93"))
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
#endif
