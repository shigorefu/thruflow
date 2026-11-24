import Foundation
import SwiftUI
import WidgetKit

struct FlowTimerWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: FlowTimerWidgetSnapshot?
}

struct FlowTimerWidgetProvider: TimelineProvider {
    private let snapshots = FlowTimerWidgetSnapshotStore()

    func placeholder(in context: Context) -> FlowTimerWidgetEntry {
        FlowTimerWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (FlowTimerWidgetEntry) -> Void
    ) {
        completion(
            FlowTimerWidgetEntry(
                date: .now,
                snapshot: context.isPreview ? .placeholder : snapshots.load()
            )
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<FlowTimerWidgetEntry>) -> Void
    ) {
        let entry = FlowTimerWidgetEntry(date: .now, snapshot: snapshots.load())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

private extension FlowTimerWidgetSnapshot {
    static let placeholder = FlowTimerWidgetSnapshot(
        sessionID: UUID(),
        taskEmoji: "📚",
        taskTitle: String(localized: "読書"),
        areaName: String(localized: "読書"),
        areaColorHex: "#007AFF",
        modeName: "Focus",
        status: .focus,
        timerKind: .focus,
        timerStartedAt: .now,
        plannedEndAt: .now.addingTimeInterval(25 * 60),
        remainingSeconds: 25 * 60,
        progress: 0,
        updatedAt: .now
    )
}
