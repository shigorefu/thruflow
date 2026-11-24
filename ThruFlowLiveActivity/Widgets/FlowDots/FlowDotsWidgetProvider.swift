import Foundation
import SwiftUI
import WidgetKit

struct FlowDotsWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: DotsWidgetSnapshot
}

struct FlowDotsWidgetProvider: TimelineProvider {
    private let snapshots = ProductWidgetSnapshotStore()

    func placeholder(in context: Context) -> FlowDotsWidgetEntry {
        FlowDotsWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (FlowDotsWidgetEntry) -> Void
    ) {
        completion(
            FlowDotsWidgetEntry(
                date: .now,
                snapshot: context.isPreview ? .placeholder : snapshots.loadDots() ?? .empty
            )
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<FlowDotsWidgetEntry>) -> Void
    ) {
        let now = Date.now
        let entry = FlowDotsWidgetEntry(
            date: now,
            snapshot: snapshots.loadDots() ?? .empty
        )
        let nextDay = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: now)
        ) ?? now.addingTimeInterval(86_400)
        completion(Timeline(entries: [entry], policy: .after(nextDay)))
    }
}

private extension DotsWidgetSnapshot {
    static let empty = DotsWidgetSnapshot(generatedAt: .now, days: [])

    static var placeholder: DotsWidgetSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let colors = ["#007AFF", "#34C759", "#AF52DE"]
        let days = (0..<180).compactMap { offset -> DotsWidgetDaySnapshot? in
            guard let date = calendar.date(byAdding: .day, value: offset - 179, to: today) else {
                return nil
            }
            let active = offset % 5 != 0 && offset % 7 != 0
            return DotsWidgetDaySnapshot(
                date: date,
                focusedSeconds: active ? ((offset % 4) + 1) * 12 * 60 : 0,
                mixedColorHex: active ? colors[offset % colors.count] : nil
            )
        }
        return DotsWidgetSnapshot(generatedAt: .now, days: days)
    }
}
