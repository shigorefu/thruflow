#if DEBUG
import Foundation
import SwiftData

@MainActor
enum StatisticsDemoData {
    static func seed(modelContext: ModelContext, now: Date = .now, calendar: Calendar = .current) throws {
        // A fixture is only suitable for an empty, isolated store.
        guard try modelContext.fetchCount(FetchDescriptor<Area>()) == 0,
              try modelContext.fetchCount(FetchDescriptor<Todo>()) == 0,
              try modelContext.fetchCount(FetchDescriptor<FlowSession>()) == 0 else { return }
        let areas = [
            Area(name: "テスト・読書", type: .neutral, symbolName: "📚", colorHex: "#4488CC"), // localisation-audit: persisted-value — Japanese fixture content, not UI copy.
            Area(name: "テスト・運動", type: .neutral, symbolName: "🏃", colorHex: "#E58C43"), // localisation-audit: persisted-value — Japanese fixture content, not UI copy.
            Area(name: "テスト・学習", type: .nice, symbolName: "🧠", colorHex: "#8A63C8") // localisation-audit: persisted-value — Japanese fixture content, not UI copy.
        ]
        let today = calendar.startOfDay(for: now)
        for (areaIndex, area) in areas.enumerated() {
            modelContext.insert(area)
            for (index, offset) in [1, 2, 4, 7, 14, 35, 60].enumerated() {
                let day = calendar.date(byAdding: .day, value: -offset, to: today)!
                let start = calendar.date(bySettingHour: 10 + areaIndex * 2, minute: 0, second: 0, of: day)!
                let minutes = [12, 25, 50][(index + areaIndex) % 3]
                let end = start.addingTimeInterval(Double(minutes * 60))
                let measurement: TodoMeasurement = areaIndex == 1 ? .minutes : .checkbox
                let todo = Todo(title: "サンプル \(area.name)", notes: "動作確認用の架空の記録", hashtags: ["demo"], area: area, // localisation-audit: persisted-value — Japanese fixture content, not UI copy.
                    measurement: measurement, plannedAmount: areaIndex == 1 ? minutes : 1,
                    actualProgress: areaIndex == 1 ? minutes : (index.isMultiple(of: 2) ? 1 : 0),
                    status: index.isMultiple(of: 2) ? .completed : .active,
                    completedAt: index.isMultiple(of: 2) ? end : nil, scheduledDate: day,
                    createdAt: start, updatedAt: end)
                modelContext.insert(todo)
                let session = FlowSession(area: area, todo: todo, result: "テスト記録", mode: .twentyFiveFive, // localisation-audit: persisted-value — Japanese fixture content, not UI copy.
                    phase: .completed, status: .completed, startedAt: start, plannedEndAt: end, endedAt: end,
                    plannedFocusDurationSeconds: minutes * 60, actualFocusDurationSeconds: minutes * 60,
                    plannedBreakDurationSeconds: 5 * 60, completedAt: end, createdAt: start, updatedAt: end)
                modelContext.insert(session)
                let segment = FlowSegment(session: session, area: area, todo: todo, startedAt: start, startFocusSeconds: 0)
                segment.close(at: end, totalFocusSeconds: minutes * 60)
                modelContext.insert(segment)
            }
            modelContext.insert(Todo(title: "今日のサンプル \(area.name)", hashtags: ["demo"], area: area, scheduledDate: today)) // localisation-audit: persisted-value — Japanese fixture content, not UI copy.
        }
        try modelContext.save()
        try FlowProgressReconciler().reconcileAll(modelContext: modelContext, now: now)
        try modelContext.save()
    }
}
#endif
