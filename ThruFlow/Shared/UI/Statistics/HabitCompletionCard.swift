import SwiftUI

#if os(iOS) || os(macOS)
struct HabitCompletionCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let summary: HabitCompletionSummary
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 16) {
            Label {
                Text(String(localized: "習慣の達成率"))
            } icon: {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
            }
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: compact ? 8 : 16) {
                if let rate = summary.rate {
                    VStack(alignment: .leading, spacing: compact ? 8 : 16) {
                        HStack(alignment: .firstTextBaseline, spacing: compact ? 7 : 12) {
                            Text(rate, format: .percent.precision(.fractionLength(0)))
                                .font(compact ? .title2.bold() : .largeTitle.bold())
                                .monospacedDigit()
                                .foregroundStyle(.green)
                            Text(String(localized: "予定 \(summary.occurrenceCount) 件"))
                                .font(compact ? .caption : .callout)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(summary.areas) { area in
                            VStack(alignment: .leading, spacing: compact ? 3 : 6) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(area.symbol).accessibilityHidden(true)
                                    Text(area.name)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 8)
                                    Text(area.rate, format: .percent.precision(.fractionLength(0)))
                                        .monospacedDigit()
                                        .fixedSize()
                                }
                                .font(compact ? .caption : .callout)
                                ProgressView(value: area.rate)
                                    .tint(Color(hex: area.colorHex))
                                    .accessibilityHidden(true)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .transition(.opacity)
                } else {
                    Text(String(localized: "対象の習慣はありません"))
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: summary.rate != nil)
            Text(String(localized: "記録された習慣の予定を対象に、途中までの進捗も含めて集計します。"))
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
}
#endif
