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
        let work = Direction(
            name: "仕事",
            type: .neutral,
            symbolName: "💻",
            colorHex: "#34C759"
        )
        let medium = Todo(
            title: "Medium",
            direction: work,
            measurement: .checkbox,
            priority: .medium,
            scheduledDate: now
        )
        let high = Todo(
            title: "High",
            direction: work,
            measurement: .focusBlocks,
            priority: .high,
            plannedAmount: 2,
            focusDurationSeconds: 25 * 60,
            scheduledDate: now
        )
        let tomorrow = Todo(
            title: "Tomorrow",
            direction: work,
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
        #expect(snapshot.items[0].directionColorHex == "#34C759")
    }

    @Test func dotsSnapshotUsesCanonical180DayFlowProjection() {
        let now = Date(timeIntervalSince1970: 200 * 86_400)
        let direction = Direction(
            name: "読書",
            type: .habit,
            symbolName: "📚",
            colorHex: "#AF52DE"
        )
        let flow = FlowSession(
            direction: direction,
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
}
