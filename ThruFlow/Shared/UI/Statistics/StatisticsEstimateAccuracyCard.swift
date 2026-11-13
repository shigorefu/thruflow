#if os(macOS) || os(iOS)
import SwiftUI

struct StatisticsEstimateAccuracyCard: View {
    let value: StatisticsEstimateAccuracy
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            Label("時間見積もりの精度", systemImage: "scope")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if let rate = value.rate {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 20) {
                        bars.frame(minWidth: 220)
                        accuracy(rate)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        accuracy(rate)
                        bars
                    }
                }
            } else {
                Text("見積もりと実績を比較できるタスクはありません")
                    .foregroundStyle(.secondary)
            }

            Text("完了したタスクの見積もりと、記録された集中時間を比較します。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(compact ? 12 : 16)
        .frame(maxWidth: .infinity, maxHeight: compact ? .infinity : nil, alignment: .leading)
        .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.08))
                .allowsHitTesting(false)
        }
    }

    private var bars: some View {
        let maximum = max(1, value.plannedSeconds, value.actualSeconds)
        return Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 7) {
            bar("見積もり", seconds: value.plannedSeconds, maximum: maximum, tint: .indigo)
            bar("実績", seconds: value.actualSeconds, maximum: maximum, tint: .accentColor)
        }
    }

    private func accuracy(_ rate: Double) -> some View {
        Text(rate, format: .percent.precision(.fractionLength(0)))
            .font(compact ? .title2.bold() : .largeTitle.bold())
            .monospacedDigit()
            .foregroundStyle(Color.accentColor)
            .fixedSize()
            .accessibilityLabel(Text("時間見積もりの精度"))
            .accessibilityValue(Text(rate, format: .percent.precision(.fractionLength(0))))
    }

    private func bar(_ label: LocalizedStringKey, seconds: Double, maximum: Double, tint: Color) -> some View {
        GridRow {
            Text(label)
                .fixedSize()
            GeometryReader { geometry in
                Capsule()
                    .fill(Color.secondary.opacity(0.16))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(tint)
                            .frame(width: geometry.size.width * (seconds / maximum))
                    }
            }
            .frame(minWidth: 32, maxWidth: .infinity)
            .frame(height: 6)
            .accessibilityHidden(true)
            Text(formattedDuration(seconds))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .fixedSize()
                .gridColumnAlignment(.trailing)
        }
        .font(.caption)
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let minutes = Int(min(seconds / 60, Double(Int.max / 60)))
        let hours = minutes / 60
        let remainder = minutes % 60
        return hours == 0 ? String(localized: "\(remainder)分") : String(localized: "\(hours)時間\(remainder)分")
    }
}
#endif
