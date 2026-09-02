import Foundation
import Testing
@testable import ThruFlow

@MainActor
struct ProductWidgetSnapshotTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func tasksSnapshotUsesTodayFilterAndDashboardOrdering() {
        let now = Date(timeIntervalSince1970: 5 * 86_400 + 12 * 3_600)
        let work = Area(
            name: "仕事",
            type: .neutral,
            symbolName: "💻",
            colorHex: "#34C759"
        )
        let medium = Todo(
            title: "Medium",
            area: work,
            measurement: .checkbox,
            priority: .medium,
            scheduledDate: now
        )
        let high = Todo(
            title: "High",
            area: work,
            measurement: .focusBlocks,
            priority: .high,
            plannedAmount: 2,
            focusDurationSeconds: 25 * 60,
            scheduledDate: now
        )
        let tomorrow = Todo(
            title: "Tomorrow",
            area: work,
            scheduledDate: now.addingTimeInterval(86_400)
        )

        let snapshot = ProductWidgetSnapshotBuilder(calendar: calendar).tasksSnapshot(
            todos: [medium, tomorrow, high],
            now: now
        )

        #expect(snapshot.date == calendar.startOfDay(for: now))
        #expect(snapshot.items.map(\.title) == ["High", "Medium"])
        #expect(snapshot.items[0].measurement == .focusBlocks)
        #expect(snapshot.items[0].progress == 0.5)
        #expect(snapshot.items[0].areaColorHex == "#34C759")
    }

    @Test func dotsSnapshotUsesCanonical180DayFlowProjection() {
        let now = Date(timeIntervalSince1970: 200 * 86_400)
        let area = Area(
            name: "読書",
            type: .habit,
            symbolName: "📚",
            colorHex: "#AF52DE"
        )
        let flow = FlowSession(
            area: area,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: now,
            plannedEndAt: now.addingTimeInterval(25 * 60),
            endedAt: now.addingTimeInterval(25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )

        let snapshot = ProductWidgetSnapshotBuilder(calendar: calendar).dotsSnapshot(
            sessions: [flow],
            now: now
        )

        #expect(snapshot.days.count == 180)
        #expect(snapshot.days.last?.focusedSeconds == 25 * 60)
        #expect(snapshot.days.last?.mixedColorHex == "#AF52DE")
    }

    @Test func productWidgetStoreRoundTripsBothSnapshots() {
        let suiteName = "ProductWidgetSnapshotTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = ProductWidgetSnapshotStore(defaults: defaults)
        let tasks = TasksWidgetSnapshot(
            generatedAt: .now,
            date: .now,
            items: []
        )
        let dots = DotsWidgetSnapshot(
            generatedAt: .now,
            days: [
                DotsWidgetDaySnapshot(
                    date: .now,
                    focusedSeconds: 1_500,
                    mixedColorHex: "#007AFF"
                )
            ]
        )

        store.saveTasks(tasks)
        store.saveDots(dots)

        #expect(store.loadTasks() == tasks)
        #expect(store.loadDots() == dots)
    }

    @Test func taskWidgetItemKeepsLegacySnapshotKeys() throws {
        let item = TaskWidgetItemSnapshot(
            id: UUID(),
            title: "Task",
            areaSymbol: "💻",
            areaName: "Work",
            areaColorHex: "#007AFF",
            measurement: .checkbox,
            plannedAmount: 1,
            actualProgress: 0,
            focusedSeconds: 0,
            isCompleted: false
        )

        let encoded = try JSONEncoder().encode(item)
        let json = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )

        #expect(json["directionSymbol"] as? String == "💻")
        #expect(json["directionName"] as? String == "Work")
        #expect(json["directionColorHex"] as? String == "#007AFF")
        #expect(json["areaSymbol"] == nil)
        #expect(json["areaName"] == nil)
        #expect(json["areaColorHex"] == nil)
    }
}
