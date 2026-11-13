#if os(macOS)
import SwiftUI

struct StatisticsCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let minimumHeight: CGFloat?
    let compact: Bool
    let headerAccessory: AnyView?
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        minimumHeight: CGFloat? = nil,
        compact: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.minimumHeight = minimumHeight
        self.compact = compact
        self.headerAccessory = nil
        self.content = content()
    }

    init<HeaderAccessory: View>(
        title: String,
        subtitle: String? = nil,
        minimumHeight: CGFloat? = nil,
        compact: Bool = false,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.minimumHeight = minimumHeight
        self.compact = compact
        self.headerAccessory = AnyView(headerAccessory())
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 10) {
                    heading.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    if let headerAccessory {
                        headerAccessory.fixedSize(horizontal: true, vertical: false)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    heading
                    headerAccessory
                }
            }
            content
        }
        .frame(
            maxWidth: .infinity,
            minHeight: minimumHeight,
            alignment: .topLeading
        )
        .padding(compact ? 10 : 16)
        .background(Color.secondary.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07))
        }
    }

    private var heading: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct StatisticsAnalysisCard<Accessory: View, Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let systemImage: String
    var compact = false
    @ViewBuilder let accessory: Accessory
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 16) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: compact ? 8 : 12) {
                    heading.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    accessory.fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 10) {
                    heading
                    accessory
                }
            }
            content
        }
        .padding(compact ? 10 : 18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.09))
                .allowsHitTesting(false)
        }
    }

    private var heading: some View {
        HStack(alignment: .center, spacing: compact ? 8 : 12) {
            Image(systemName: systemImage)
                .font(.system(size: compact ? 12 : 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: compact ? 24 : 32, height: compact ? 24 : 32)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)

            let headingLayout = compact
                ? AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: 3))
            headingLayout {
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

struct StatisticsEmptyState: View {
    let label: String

    var body: some View {
        ContentUnavailableView(
            label,
            systemImage: "chart.xyaxis.line",
            description: Text(String(localized: "期間やフィルターを変更してください"))
        )
        .controlSize(.small)
    }
}

enum StatisticsFormatting {
    static func duration(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours == 0 {
            return String(localized: "\(remainingMinutes)分")
        }
        return String(localized: "\(hours)時間\(remainingMinutes)分")
    }
}
#endif
