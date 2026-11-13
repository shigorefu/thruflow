import Foundation
import SwiftUI
import WidgetKit

struct TasksWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: TasksWidgetSnapshot?
}

struct TasksWidgetProvider: TimelineProvider {
    private let snapshots = ProductWidgetSnapshotStore()

    func placeholder(in context: Context) -> TasksWidgetEntry {
        TasksWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (TasksWidgetEntry) -> Void
    ) {
        completion(
            TasksWidgetEntry(
                date: .now,
                snapshot: context.isPreview ? .placeholder : currentSnapshot()
            )
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<TasksWidgetEntry>) -> Void
    ) {
        let now = Date.now
        let entry = TasksWidgetEntry(date: now, snapshot: currentSnapshot(at: now))
        let nextDay = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: now)
        ) ?? now.addingTimeInterval(86_400)
        completion(Timeline(entries: [entry], policy: .after(nextDay)))
    }

    private func currentSnapshot(at date: Date = .now) -> TasksWidgetSnapshot? {
        guard let snapshot = snapshots.loadTasks(),
              Calendar.current.isDate(snapshot.date, inSameDayAs: date) else {
            return nil
        }
        return snapshot
    }
}

private extension TasksWidgetSnapshot {
    static let placeholder = TasksWidgetSnapshot(
        generatedAt: .now,
        date: .now,
        items: [
            TaskWidgetItemSnapshot(
                id: UUID(),
                title: String(localized: "発表資料を作る"),
                areaSymbol: "💻",
                areaName: String(localized: "その他"),
                areaColorHex: "#34C759",
                measurement: .focusBlocks,
                plannedAmount: 2,
                actualProgress: 1,
                focusedSeconds: 25 * 60,
                isCompleted: false
            ),
            TaskWidgetItemSnapshot(
                id: UUID(),
                title: String(localized: "読書"),
                areaSymbol: "📚",
                areaName: String(localized: "読書"),
                areaColorHex: "#AF52DE",
                measurement: .checkbox,
                plannedAmount: 1,
                actualProgress: 1,
                focusedSeconds: 0,
                isCompleted: true
            ),
        ]
    )
}
