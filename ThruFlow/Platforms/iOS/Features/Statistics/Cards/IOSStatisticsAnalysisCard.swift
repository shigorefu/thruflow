#if os(iOS)
import SwiftUI

struct IOSStatisticsAnalysisCard<Accessory: View, Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let systemImage: String
    var compact = false
    @ViewBuilder let accessory: () -> Accessory
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 16) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    heading.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    accessory().fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 10) {
                    heading
                    accessory()
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 8 : 16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.primary.opacity(0.08))
                .allowsHitTesting(false)
        }
    }

    private var heading: some View {
        HStack(spacing: compact ? 7 : 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: compact ? 22 : 32, height: compact ? 22 : 32)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: compact ? 0 : 3) {
                Text(title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
#endif
