import Foundation
import SwiftUI
import WidgetKit

struct FlowTimerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: FlowTimerWidgetSnapshotStore.widgetKind,
            provider: FlowTimerWidgetProvider()
        ) { entry in
            FlowTimerWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(productHex: entry.snapshot?.areaColorHex ?? "#007AFF")
                        .opacity(entry.snapshot == nil ? 0.04 : 0.10)
                }
                .widgetURL(URL(string: "thruflow://flow"))
        }
        .configurationDisplayName(String(localized: "Flowタイマー"))
        .description(String(localized: "実行中のFlowをホーム画面で確認できます。"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
