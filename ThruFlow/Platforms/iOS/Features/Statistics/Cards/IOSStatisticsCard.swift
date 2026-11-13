#if os(iOS)
import SwiftUI

struct IOSStatisticsCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let headerAccessory: AnyView?
    let content: Content
    let compact: Bool

    init(
        title: String? = nil,
        subtitle: String? = nil,
        compact: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.compact = compact
        headerAccessory = nil
        self.content = content()
    }

    init<HeaderAccessory: View>(
        title: String,
        subtitle: String? = nil,
        compact: Bool = false,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.compact = compact
        self.headerAccessory = AnyView(headerAccessory())
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 14) {
            if title != nil || headerAccessory != nil {
                HStack(spacing: 8) {
                    if let title {
                        Text(title)
                            .font(.headline)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if let headerAccessory {
                        headerAccessory
                    }
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(compact ? 10 : 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        }
    }
}

struct IOSStatisticsEmptyState: View {
    var body: some View {
        ContentUnavailableView(
            String(localized: "この期間のデータはありません"),
            systemImage: "chart.xyaxis.line",
            description: Text(String(localized: "期間やフィルターを変更してください"))
        )
        .controlSize(.small)
    }
}

struct IOSStatisticsModePicker: View {
    @Binding var selection: StatisticsMode

    var body: some View {
        Picker(String(localized: "統計表示"), selection: $selection) {
            Text(StatisticsMode.flow.displayName).tag(StatisticsMode.flow)
            Text(StatisticsMode.achievement.displayName).tag(StatisticsMode.achievement)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 118)
    }
}

enum IOSStatisticsFormatting {
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
