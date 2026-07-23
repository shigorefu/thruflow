import Foundation

enum TaskWidgetMeasurement: String, Codable, Equatable {
    case checkbox
    case focusBlocks
    case minutes
}

struct TaskWidgetItemSnapshot: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var directionSymbol: String
    var directionName: String
    var directionColorHex: String
    var measurement: TaskWidgetMeasurement
    var plannedAmount: Int
    var actualProgress: Int
    var focusedSeconds: Int
    var isCompleted: Bool

    var progress: Double {
        switch measurement {
        case .checkbox:
            return isCompleted ? 1 : 0
        case .focusBlocks:
            guard plannedAmount > 0 else { return 0 }
            return min(
                max(Double(focusedSeconds) / Double(plannedAmount * 25 * 60), 0),
                1
            )
        case .minutes:
            guard plannedAmount > 0 else { return 0 }
            return min(max(Double(actualProgress) / Double(plannedAmount), 0), 1)
        }
    }
}

struct TasksWidgetSnapshot: Codable, Equatable {
    var generatedAt: Date
    var date: Date
    var items: [TaskWidgetItemSnapshot]

    var completedCount: Int {
        items.filter(\.isCompleted).count
    }
}

struct DotsWidgetDaySnapshot: Codable, Equatable, Identifiable {
    var date: Date
    var focusedSeconds: Int
    var mixedColorHex: String?

    var id: Date { date }
}

struct DotsWidgetSnapshot: Codable, Equatable {
    var generatedAt: Date
    var days: [DotsWidgetDaySnapshot]
}

struct ProductWidgetSnapshotStore {
    static let tasksWidgetKind = "TasksWidget"
    static let dotsWidgetKind = "FlowDotsWidget"

    private static let tasksKey = "productWidget.tasks.snapshot"
    private static let dotsKey = "productWidget.dots.snapshot"

    private let defaults: UserDefaults?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults? = UserDefaults(
        suiteName: FlowTimerWidgetSnapshotStore.appGroupIdentifier
    )) {
        self.defaults = defaults
    }

    func saveTasks(_ snapshot: TasksWidgetSnapshot) {
        save(snapshot, key: Self.tasksKey)
    }

    func loadTasks() -> TasksWidgetSnapshot? {
        load(TasksWidgetSnapshot.self, key: Self.tasksKey)
    }

    func saveDots(_ snapshot: DotsWidgetSnapshot) {
        save(snapshot, key: Self.dotsKey)
    }

    func loadDots() -> DotsWidgetSnapshot? {
        load(DotsWidgetSnapshot.self, key: Self.dotsKey)
    }

    private func save<Value: Encodable>(_ value: Value, key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults?.set(data, forKey: key)
    }

    private func load<Value: Decodable>(_ type: Value.Type, key: String) -> Value? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }
}
