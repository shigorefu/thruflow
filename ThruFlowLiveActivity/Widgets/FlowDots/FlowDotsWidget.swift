import Foundation
import SwiftUI
import WidgetKit

struct FlowDotsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: ProductWidgetSnapshotStore.dotsWidgetKind,
            provider: FlowDotsWidgetProvider()
        ) { entry in
            FlowDotsWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.primary.opacity(0.04)
                }
                .widgetURL(URL(string: "thruflow://statistics"))
        }
        .configurationDisplayName(String(localized: "Flow Dots"))
        .description(String(localized: "Flowの積み重ねを30日、60日、90日で確認できます。"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
