import Foundation
import Testing
@testable import ThruFlow

@MainActor
struct DatabaseSearchTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func taskSearchReturnsMatchingTodosAcrossEveryDateAndUnscheduled() {
        let area = Area(name: "仕事", type: .neutral)
        let firstDate = date(2026, 7, 1)
        let secondDate = date(2026, 7, 25)
        let first = Todo(title: "Global report", area: area, scheduledDate: firstDate)
        let second = Todo(title: "Global review", area: area, scheduledDate: secondDate)
        let unscheduled = Todo(title: "Global backlog", area: area)
        let archived = Todo(title: "Global archived", area: area, scheduledDate: secondDate)
        archived.archive()
        let deleted = Todo(title: "Global deleted", area: area, scheduledDate: firstDate)
        deleted.softDelete()

        let sections = DatabaseSearchBuilder(calendar: calendar).taskSections(
            query: "global",
            todos: [first, second, unscheduled, archived, deleted],
            filter: .all
        )

        #expect(sections.map(\.date) == [secondDate, firstDate, nil])
        #expect(Set(sections.flatMap(\.todos).map(\.id)) == Set([first.id, second.id, unscheduled.id]))
    }

    @Test func taskSearchKeepsTheTaskHabitFilterAcrossTheDatabase() {
        let taskArea = Area(name: "仕事", type: .neutral)
        let habitArea = Area(name: "読書", type: .habit)
        let task = Todo(title: "共通の検索語", area: taskArea, scheduledDate: date(2026, 7, 1))
        let habit = Todo(title: "共通の検索語", area: habitArea, scheduledDate: date(2026, 7, 20))

        let sections = DatabaseSearchBuilder(calendar: calendar).taskSections(
            query: "検索語",
            todos: [task, habit],
            filter: .habits
        )

        #expect(sections.flatMap(\.todos).map(\.id) == [habit.id])
    }

    @Test func historyCalendarSearchFindsARecordOutsideTheSelectedDay() {
        let area = Area(name: "仕事", type: .neutral, symbolName: "💼")
        let oldTodo = Todo(title: "Global history target", area: area)
        let recentTodo = Todo(title: "Unrelated", area: area)
        let oldSession = completedSession(
            area: area,
            todo: oldTodo,
            startedAt: date(2026, 5, 2)
        )
        let recentSession = completedSession(
            area: area,
            todo: recentTodo,
            startedAt: date(2026, 7, 27)
        )

        let items = DatabaseSearchBuilder(calendar: calendar).historyCalendarItems(
            query: "history target",
            sessions: [recentSession, oldSession],
            breaks: [],
            referenceDate: date(2026, 7, 27)
        )

        #expect(items.count == 1)
        #expect(items.first?.session?.id == oldSession.id)
    }

    @Test func historyAggregateSearchIncludesTheTodoLinkedToAMatchingIntent() {
        let area = Area(name: "仕事", type: .neutral)
        let todo = Todo(title: "設計", area: area, scheduledDate: date(2026, 4, 8))
        let session = completedSession(
            area: area,
            todo: todo,
            startedAt: date(2026, 4, 8),
            intent: "Quarterly architecture review"
        )

        let snapshot = DatabaseSearchBuilder(calendar: calendar).historySnapshot(
            query: "quarterly",
            sessions: [session],
            todos: [todo],
            referenceDate: date(2026, 7, 27)
        )

        #expect(snapshot.flowCount == 1)
        #expect(snapshot.taskSummaries.map(\.todoID) == [todo.id])
    }

    @Test func historySearchMatchesOnlyTheSegmentThatOwnsTheArea() {
        let ankiArea = Area(name: "Anki", type: .neutral, symbolName: "📄")
        let hiroconArea = Area(name: "広コン", type: .neutral, symbolName: "💻")
        let ankiTodo = Todo(title: "単語を復習", area: ankiArea)
        let hiroconTodo = Todo(title: "ゲーム特別版のプレゼンを作成", area: hiroconArea)
        let start = date(2026, 7, 28)
        let session = completedSession(
            area: hiroconArea,
            todo: hiroconTodo,
            startedAt: start
        )
        session.actualFocusDurationSeconds = 18 * 60
        session.endedAt = start.addingTimeInterval(18 * 60)

        let ankiSegment = FlowSegment(
            session: session,
            area: ankiArea,
            todo: ankiTodo,
            startedAt: start,
            startFocusSeconds: 0
        )
        ankiSegment.close(
            at: start.addingTimeInterval(10 * 60),
            totalFocusSeconds: 10 * 60
        )
        let hiroconSegment = FlowSegment(
            session: session,
            area: hiroconArea,
            todo: hiroconTodo,
            startedAt: start.addingTimeInterval(10 * 60),
            startFocusSeconds: 10 * 60
        )
        hiroconSegment.close(
            at: start.addingTimeInterval(18 * 60),
            totalFocusSeconds: 18 * 60
        )
        session.resolvedSegments = [ankiSegment, hiroconSegment]

        let items = DatabaseSearchBuilder(calendar: calendar).historyCalendarItems(
            query: "広コン",
            sessions: [session],
            breaks: [],
            referenceDate: start
        )

        #expect(items.count == 1)
        #expect(items.first?.flowSegment?.id == hiroconSegment.id)
        #expect(items.first?.todo?.id == hiroconTodo.id)
        #expect(items.first?.title == "ゲーム特別版のプレゼンを作成")
    }

    private func completedSession(
        area: Area,
        todo: Todo,
        startedAt: Date,
        intent: String = ""
    ) -> FlowSession {
        FlowSession(
            area: area,
            todo: todo,
            intent: intent,
            mode: .twentyFiveFive,
            phase: .completed,
            status: .completed,
            startedAt: startedAt,
            plannedEndAt: startedAt.addingTimeInterval(25 * 60),
            endedAt: startedAt.addingTimeInterval(25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
