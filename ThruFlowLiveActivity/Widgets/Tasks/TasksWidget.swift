import Foundation
import SwiftUI
import WidgetKit

struct TasksWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: ProductWidgetSnapshotStore.tasksWidgetKind,
            provider: TasksWidgetProvider()
        ) { entry in
            TasksWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.accentColor.opacity(0.06)
                }
                .widgetURL(URL(string: "thruflow://tasks"))
        }
        .configurationDisplayName(String(localized: "今日のタスク"))
        .description(String(localized: "今日のタスクと進捗をホーム画面で確認できます。"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
