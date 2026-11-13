#if os(macOS)
import SwiftUI

struct StatisticsCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let minimumHeight: CGFloat?
    let headerAccessory: AnyView?
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        minimumHeight: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.minimumHeight = minimumHeight
        self.headerAccessory = nil
        self.content = content()
    }

    init<HeaderAccessory: View>(
        title: String,
        subtitle: String? = nil,
        minimumHeight: CGFloat? = nil,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.minimumHeight = minimumHeight
        self.headerAccessory = AnyView(headerAccessory())
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if let headerAccessory {
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
        .padding(16)
        .background(Color.secondary.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07))
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
