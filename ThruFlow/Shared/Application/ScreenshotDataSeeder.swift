import Foundation
import SwiftData

enum ScreenshotDataSeeder {
    static let featuredDirectionID = UUID(
        uuidString: "10000000-0000-4000-8000-000000000001"
    )!
    static let featuredTodoID = UUID(
        uuidString: "20000000-0000-4000-8000-000000000001"
    )!

    private static let learningDirectionID = UUID(
        uuidString: "10000000-0000-4000-8000-000000000002"
    )!
    private static let readingDirectionID = UUID(
        uuidString: "10000000-0000-4000-8000-000000000003"
    )!
    private static let healthDirectionID = UUID(
        uuidString: "10000000-0000-4000-8000-000000000004"
    )!
    private static let personalDirectionID = UUID(
        uuidString: "10000000-0000-4000-8000-000000000005"
    )!
    private static let otherDirectionID = UUID(
        uuidString: "10000000-0000-4000-8000-000000000006"
    )!

    static func seedIfNeeded(
        in container: ModelContainer,
        now: Date = .now,
        language: ScreenshotLanguage = .ja,
        calendar suppliedCalendar: Calendar? = nil
    ) throws {
        let context = ModelContext(container)
        var existingDirections = FetchDescriptor<Direction>()
        existingDirections.fetchLimit = 1
        guard try context.fetch(existingDirections).isEmpty else { return }

        var calendar = suppliedCalendar ?? Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: language.localeIdentifier)
        calendar.timeZone = suppliedCalendar?.timeZone ?? .autoupdatingCurrent
        calendar.firstWeekday = 2

        let copy = ScreenshotCopy(language: language)
        let today = calendar.startOfDay(for: now)
        let createdAt = calendar.date(byAdding: .day, value: -240, to: today) ?? today
        let directions = makeDirections(createdAt: createdAt, copy: copy)
        directions.all.forEach(context.insert)

        // Projects share the real model and task relationships used by the app.
        let projects = [
            Project(id: deterministicID(category: 0x601, index: 0), name: copy.projectNames[0], area: directions.work, createdAt: createdAt),
            Project(id: deterministicID(category: 0x601, index: 1), name: copy.projectNames[1], area: directions.learning, createdAt: createdAt),
            Project(id: deterministicID(category: 0x601, index: 2), name: copy.projectNames[2], area: directions.learning, createdAt: createdAt),
            Project(id: deterministicID(category: 0x601, index: 3), name: copy.projectNames[3], area: directions.personal, createdAt: createdAt)
        ]
        projects.forEach(context.insert)
        projects[3].habitSettings = ProjectHabitSettings(isEnabled: true, goalTarget: 25, goalUnit: .minutes, startsOn: today)

        var generator = DeterministicGenerator(seed: 0x5448_5255_464C_4F57)
        seedHistory(
            directions: directions,
            reportProject: projects[0],
            studyProject: projects[1],
            today: today,
            calendar: calendar,
            copy: copy,
            generator: &generator,
            context: context
        )
        seedToday(
            directions: directions,
            reportProject: projects[0],
            studyProject: projects[1],
            today: today,
            calendar: calendar,
            copy: copy,
            context: context
        )

        let allTodos = try context.fetch(FetchDescriptor<Todo>())
        if let featured = allTodos.first(where: { $0.id == featuredTodoID }) {
            featured.setTiming(minutes: 14 * 60, reminderEnabled: true, now: now)
        }
        try context.save()
        try HabitTodoMaterializer(calendar: calendar).materialize(areas: directions.all, dates: [today], modelContext: context, now: now)
        try context.save()
        try FlowProgressReconciler().reconcileAll(
            modelContext: context,
            now: now
        )
        try context.save()
    }

    private static func makeDirections(
        createdAt: Date,
        copy: ScreenshotCopy
    ) -> ScreenshotDirections {
        let work = Direction(
            id: featuredDirectionID,
            name: copy.workDirection,
            type: .neutral,
            symbolName: "💼",
            colorHex: "#0A84FF",
            sortIndex: 0,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let learning = Direction(
            id: learningDirectionID,
            name: copy.studyDirection,
            type: .neutral,
            symbolName: "🧠",
            colorHex: "#5E5CE6",
            sortIndex: 1,
            createdAt: createdAt.addingTimeInterval(1),
            updatedAt: createdAt
        )
        let reading = Direction(
            id: readingDirectionID,
            name: copy.readingDirection,
            type: .habit,
            symbolName: "📚",
            colorHex: "#30D158",
            goalTarget: 1,
            goalPeriod: .daily,
            goalUnit: .focusBlocks,
            goalSchedule: .everyDay,
            sortIndex: 2,
            createdAt: createdAt.addingTimeInterval(2),
            updatedAt: createdAt
        )
        let health = Direction(
            id: healthDirectionID,
            name: copy.healthDirection,
            type: .habit,
            symbolName: "🏃",
            colorHex: "#FF9F0A",
            goalTarget: 30,
            goalPeriod: .daily,
            goalUnit: .minutes,
            goalSchedule: .everyDay,
            sortIndex: 3,
            createdAt: createdAt.addingTimeInterval(3),
            updatedAt: createdAt
        )
        let personal = Direction(
            id: personalDirectionID,
            name: copy.personalDirection,
            type: .nice,
            symbolName: "🌿",
            colorHex: "#64D2FF",
            sortIndex: 4,
            createdAt: createdAt.addingTimeInterval(4),
            updatedAt: createdAt
        )
        let other = Direction(
            id: otherDirectionID,
            name: copy.otherDirection,
            systemRole: .taskInbox,
            type: .neutral,
            symbolName: "📝",
            colorHex: "#8E8E93",
            sortIndex: 5,
            createdAt: createdAt.addingTimeInterval(5),
            updatedAt: createdAt
        )

        return ScreenshotDirections(
            work: work,
            learning: learning,
            reading: reading,
            health: health,
            personal: personal,
            other: other
        )
    }

    private static func seedHistory(
        directions: ScreenshotDirections,
        reportProject: Project,
        studyProject: Project,
        today: Date,
        calendar: Calendar,
        copy: ScreenshotCopy,
        generator: inout DeterministicGenerator,
        context: ModelContext
    ) {
        let templates = copy.templates

        for dayOffset in (-180)...(-1) {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else {
                continue
            }

            let weekday = calendar.component(.weekday, from: day)
            let restChance = weekday == 1 ? 46 : 17
            guard generator.next(upperBound: 100) >= restChance else { continue }

            let sessionCount = 1 + generator.next(upperBound: 3)
            let dayIndex = dayOffset + 180
            let seriesID = deterministicID(category: 0x501, index: dayIndex)
            var cursor = date(
                on: day,
                hour: 8 + generator.next(upperBound: 3),
                minute: [0, 10, 20, 30, 40][generator.next(upperBound: 5)],
                calendar: calendar
            )

            var usedHabitAreaIDs = Set<UUID>()
            for sessionIndex in 0..<sessionCount {
                let globalIndex = dayIndex * 4 + sessionIndex
                var area = historicalDirection(
                    from: directions,
                    roll: generator.next(upperBound: 100)
                )
                // Each Habit has one occurrence per day; distinct activities must not
                // be silently merged by the real occurrence reconciler.
                if area.type == .habit, !usedHabitAreaIDs.insert(area.id).inserted {
                    area = directions.work
                }
                let mode = historicalMode(roll: generator.next(upperBound: 100))
                let sampledTemplateIndex = generator.next(upperBound: 16)
                let templateIndex = area.type == .habit ? 0 : sampledTemplateIndex
                let focusedSeconds = historicalFocusedMinutes(for: area.id, index: templateIndex) * 60
                let end = cursor.addingTimeInterval(TimeInterval(focusedSeconds))
                let todo = makeHistoricalTodo(
                    id: deterministicID(category: 0x601, index: globalIndex),
                    title: templates.title(
                        for: area.id,
                        index: templateIndex
                    ),
                    area: area,
                    focusedSeconds: focusedSeconds,
                    scheduledDate: day,
                    completedAt: end,
                    index: sessionIndex,
                    focusHashtag: templates.focusHashtag
                )
                if area.id == directions.work.id, templateIndex % templates.work.count == 0 {
                    todo.project = reportProject
                } else if area.id == directions.learning.id {
                    todo.project = studyProject
                }
                let sessionID = deterministicID(category: 0x701, index: globalIndex)
                let session = FlowSession(
                    id: sessionID,
                    seriesID: seriesID,
                    area: area,
                    todo: todo,
                    intent: todo.title,
                    result: templates.memo(index: generator.next(upperBound: 12)),
                    mode: mode,
                    phase: .completed,
                    status: .completed,
                    startedAt: cursor,
                    plannedEndAt: cursor.addingTimeInterval(
                        TimeInterval(mode.initialFocusDurationSeconds)
                    ),
                    endedAt: end,
                    plannedFocusDurationSeconds: mode.initialFocusDurationSeconds,
                    actualFocusDurationSeconds: focusedSeconds,
                    plannedBreakDurationSeconds: mode.breakDurationSeconds,
                    completedAt: end,
                    createdAt: cursor,
                    updatedAt: end
                )
                let segment = FlowSegment(
                    id: deterministicID(category: 0x801, index: globalIndex),
                    session: session,
                    area: area,
                    todo: todo,
                    startedAt: cursor,
                    startFocusSeconds: 0
                )
                segment.close(at: end, totalFocusSeconds: focusedSeconds)
                session.resolvedSegments = [segment]

                context.insert(todo)
                context.insert(session)

                guard sessionIndex < sessionCount - 1 else { continue }
                let breakSeconds = mode.breakDurationSeconds
                let breakEnd = end.addingTimeInterval(TimeInterval(breakSeconds))
                let nextSessionID = deterministicID(category: 0x701, index: globalIndex + 1)
                let flowBreak = FlowBreak(
                    id: deterministicID(category: 0x901, index: globalIndex),
                    seriesID: seriesID,
                    previousSessionID: sessionID,
                    nextSessionID: nextSessionID,
                    startedAt: end,
                    timerStoppedAt: breakEnd,
                    connectedUntil: breakEnd,
                    plannedDurationSeconds: breakSeconds,
                    isLongBreak: sessionIndex == 3,
                    createdAt: end,
                    updatedAt: breakEnd
                )
                context.insert(flowBreak)
                cursor = breakEnd
            }
        }
    }

    private static func seedToday(
        directions: ScreenshotDirections,
        reportProject: Project,
        studyProject: Project,
        today: Date,
        calendar: Calendar,
        copy: ScreenshotCopy,
        context: ModelContext
    ) {
        let featured = Todo(
            id: featuredTodoID,
            title: copy.featuredTitle,
            notes: copy.featuredNotes,
            hashtags: copy.featuredHashtags,
            area: directions.work,
            measurement: .focusBlocks,
            priority: .high,
            plannedAmount: 4,
            scheduledDate: today,
            deadline: today,
            sortIndex: 0,
            createdAt: date(on: today, hour: 7, minute: 45, calendar: calendar),
            updatedAt: date(on: today, hour: 10, minute: 30, calendar: calendar)
        )
        let email = Todo(
            id: deterministicID(category: 0x201, index: 2),
            title: copy.emailTitle,
            hashtags: copy.emailHashtags,
            area: directions.work,
            measurement: .checkbox,
            priority: .medium,
            actualProgress: 1,
            focusDurationSeconds: 10 * 60,
            status: .completed,
            completedAt: date(on: today, hour: 11, minute: 35, calendar: calendar),
            scheduledDate: today,
            sortIndex: 1
        )
        let planTomorrow = Todo(
            id: deterministicID(category: 0x201, index: 3),
            title: copy.planTitle,
            hashtags: copy.planHashtags,
            area: directions.work,
            measurement: .checkbox,
            priority: .high,
            scheduledDate: today,
            deadline: today,
            sortIndex: 2
        )
        let reading = Todo(
            id: deterministicID(category: 0x201, index: 4),
            title: copy.readingTitle,
            notes: copy.readingNotes,
            hashtags: copy.readingHashtags,
            area: directions.reading,
            habitOccurrence: true,
            measurement: .focusBlocks,
            priority: .medium,
            plannedAmount: 1,
            scheduledDate: today,
            sortIndex: 0
        )
        let learning = Todo(
            id: deterministicID(category: 0x201, index: 5),
            title: copy.studyTitle,
            notes: copy.studyNotes,
            hashtags: copy.studyHashtags,
            area: directions.learning,
            measurement: .minutes,
            priority: .medium,
            plannedAmount: 30,
            scheduledDate: today,
            sortIndex: 1
        )
        let health = Todo(
            id: deterministicID(category: 0x201, index: 6),
            title: copy.runTitle,
            area: directions.health,
            habitOccurrence: true,
            measurement: .minutes,
            priority: .medium,
            plannedAmount: 30,
            scheduledDate: today,
            sortIndex: 1
        )
        let journal = Todo(
            id: deterministicID(category: 0x201, index: 7),
            title: copy.journalTitle,
            area: directions.personal,
            measurement: .checkbox,
            priority: .low,
            isRoomIfPossible: true,
            scheduledDate: today,
            sortIndex: 0
        )
        let tidyRoom = Todo(
            id: deterministicID(category: 0x201, index: 8),
            title: copy.tidyTitle,
            area: directions.other,
            measurement: .checkbox,
            priority: .low,
            scheduledDate: nil,
            sortIndex: 0
        )
        featured.project = reportProject
        learning.project = studyProject
        let todos = [
            featured,
            email,
            planTomorrow,
            reading,
            learning,
            health,
            journal,
            tidyRoom,
        ]
        todos.forEach(context.insert)

        let records = [
            TodayFlowRecord(
                todo: reading,
                area: directions.reading,
                hour: 7,
                minute: 50,
                focusedMinutes: 25,
                mode: .twentyFiveFive,
                memo: copy.readingMemo
            ),
            TodayFlowRecord(
                todo: featured,
                area: directions.work,
                hour: 8,
                minute: 20,
                focusedMinutes: 50,
                mode: .fiftyTen,
                memo: copy.reportOutlineMemo
            ),
            TodayFlowRecord(
                todo: featured,
                area: directions.work,
                hour: 9,
                minute: 20,
                focusedMinutes: 25,
                mode: .twentyFiveFive,
                memo: copy.reportFinishMemo
            ),
            TodayFlowRecord(
                todo: email,
                area: directions.work,
                hour: 11,
                minute: 25,
                focusedMinutes: 10,
                mode: .sprint,
                memo: copy.emailTitle
            ),
            TodayFlowRecord(
                todo: learning,
                area: directions.learning,
                hour: 13,
                minute: 20,
                focusedMinutes: 25,
                mode: .twentyFiveFive,
                memo: copy.studyMemo
            ),
            TodayFlowRecord(
                todo: health,
                area: directions.health,
                hour: 16,
                minute: 10,
                focusedMinutes: 30,
                mode: .twentyFiveFive,
                memo: copy.runMemo
            ),
        ]

        let morningSeriesID = deterministicID(category: 0x301, index: 1)
        for (index, record) in records.enumerated() {
            let start = date(
                on: today,
                hour: record.hour,
                minute: record.minute,
                calendar: calendar
            )
            let seconds = record.focusedMinutes * 60
            let end = start.addingTimeInterval(TimeInterval(seconds))
            let sessionID = deterministicID(category: 0x401, index: index)
            let session = FlowSession(
                id: sessionID,
                seriesID: index < 3 ? morningSeriesID : sessionID,
                area: record.area,
                todo: record.todo,
                intent: record.todo.title,
                result: record.memo,
                mode: record.mode,
                phase: .completed,
                status: .completed,
                startedAt: start,
                plannedEndAt: start.addingTimeInterval(
                    TimeInterval(record.mode.initialFocusDurationSeconds)
                ),
                endedAt: end,
                plannedFocusDurationSeconds: record.mode.initialFocusDurationSeconds,
                actualFocusDurationSeconds: seconds,
                plannedBreakDurationSeconds: record.mode.breakDurationSeconds,
                completedAt: end,
                createdAt: start,
                updatedAt: end
            )
            let segment = FlowSegment(
                id: deterministicID(category: 0x402, index: index),
                session: session,
                area: record.area,
                todo: record.todo,
                startedAt: start,
                startFocusSeconds: 0
            )
            segment.close(at: end, totalFocusSeconds: seconds)
            session.resolvedSegments = [segment]
            context.insert(session)

            guard index < 2 else { continue }
            let breakSeconds = record.mode.breakDurationSeconds
            let breakEnd = end.addingTimeInterval(TimeInterval(breakSeconds))
            let flowBreak = FlowBreak(
                id: deterministicID(category: 0x403, index: index),
                seriesID: morningSeriesID,
                previousSessionID: sessionID,
                nextSessionID: deterministicID(category: 0x401, index: index + 1),
                startedAt: end,
                timerStoppedAt: breakEnd,
                connectedUntil: breakEnd,
                plannedDurationSeconds: breakSeconds,
                createdAt: end,
                updatedAt: breakEnd
            )
            context.insert(flowBreak)
        }
    }

    private static func makeHistoricalTodo(
        id: UUID,
        title: String,
        area: Direction,
        focusedSeconds: Int,
        scheduledDate: Date,
        completedAt: Date,
        index: Int,
        focusHashtag: String
    ) -> Todo {
        let usesMinutes = area.type == .habit
            ? area.goalUnit == .minutes
            : focusedSeconds < BlockUnit.secondsPerBlock
        let plannedAmount = usesMinutes
            ? max(1, focusedSeconds / 60)
            : max(1, BlockUnit.wholeBlocks(forFocusedSeconds: focusedSeconds))
        return Todo(
            id: id,
            title: title,
            hashtags: index.isMultiple(of: 3) ? [focusHashtag] : [],
            area: area,
            habitOccurrence: area.type == .habit,
            measurement: usesMinutes ? .minutes : .focusBlocks,
            priority: index == 0 ? .high : .medium,
            plannedAmount: plannedAmount,
            actualProgress: plannedAmount,
            focusDurationSeconds: focusedSeconds,
            status: .completed,
            completedAt: completedAt,
            scheduledDate: scheduledDate,
            sortIndex: index,
            createdAt: scheduledDate,
            updatedAt: completedAt
        )
    }

    private static func historicalDirection(
        from directions: ScreenshotDirections,
        roll: Int
    ) -> Direction {
        switch roll {
        case 0..<40: directions.work
        case 40..<61: directions.learning
        case 61..<78: directions.reading
        case 78..<89: directions.health
        case 89..<97: directions.personal
        default: directions.other
        }
    }

    /// Fixture durations follow the same stable template index as localized titles.
    private static func historicalFocusedMinutes(for areaID: UUID, index: Int) -> Int {
        let minutes: [Int]
        switch areaID {
        case featuredDirectionID: minutes = [50, 10, 25, 25, 10]
        case learningDirectionID: minutes = [20, 25, 25, 15, 20]
        case readingDirectionID: minutes = [25, 20, 10, 25]
        case healthDirectionID: minutes = [30, 10, 25, 25]
        case personalDirectionID: minutes = [20, 25, 15, 35, 10]
        default: minutes = [10, 5, 20]
        }
        return minutes[index % minutes.count]
    }

    private static func historicalMode(roll: Int) -> FlowMode {
        switch roll {
        case 0..<16: .sprint
        case 16..<83: .twentyFiveFive
        default: .fiftyTen
        }
    }

    private static func date(
        on day: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: day
        ) ?? day
    }

    private static func deterministicID(category: Int, index: Int) -> UUID {
        let first = "A11CE" + String(format: "%03X", category & 0xFFF)
        let second = String(format: "%04X", index & 0xFFFF)
        let tailValue = (UInt64(category & 0xFFF) << 32) | (UInt64(truncatingIfNeeded: index) & 0xFFFF_FFFF)
        let value = String(
            format: "%@-%@-4000-8000-%012llX",
            first,
            second,
            tailValue
        )
        return UUID(uuidString: value)!
    }
}

private struct ScreenshotDirections {
    let work: Direction
    let learning: Direction
    let reading: Direction
    let health: Direction
    let personal: Direction
    let other: Direction

    var all: [Direction] {
        [work, learning, reading, health, personal, other]
    }
}

private struct TodayFlowRecord {
    let todo: Todo
    let area: Direction
    let hour: Int
    let minute: Int
    let focusedMinutes: Int
    let mode: FlowMode
    let memo: String
}


private struct DeterministicGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next(upperBound: Int) -> Int {
        precondition(upperBound > 0)
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 32) % UInt64(upperBound))
    }
}
