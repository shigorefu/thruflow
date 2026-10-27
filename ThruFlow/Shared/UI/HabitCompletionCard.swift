import SwiftUI

#if os(iOS) || os(macOS)
struct HabitCompletionCard: View {
    let summary: HabitCompletionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "習慣の達成率"))
                .font(.headline)
            if let rate = summary.rate {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(rate, format: .percent.precision(.fractionLength(0)))
                        .font(.largeTitle.bold())
                        .monospacedDigit()
                    Text(String(localized: "予定 \(summary.occurrenceCount) 件"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                ForEach(summary.areas) { area in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(area.symbol).accessibilityHidden(true)
                            Text(area.name)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            Text(area.rate, format: .percent.precision(.fractionLength(0)))
                                .monospacedDigit()
                                .fixedSize()
                        }
                        .font(.callout)
                        ProgressView(value: area.rate)
                            .tint(Color(hex: area.colorHex))
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)
                }
            } else {
                Text(String(localized: "対象の習慣はありません"))
                    .foregroundStyle(.secondary)
            }
            Text(String(localized: "記録された習慣の予定を対象に、途中までの進捗も含めて集計します。"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
    }
}
#endif
