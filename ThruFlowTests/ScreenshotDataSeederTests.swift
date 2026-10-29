import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct ScreenshotDataSeederTests {
    @Test func screenshotArgumentsSelectAnExactInitialScreen() {
        #expect(!ScreenshotMode.isEnabled(arguments: []))
        #expect(ScreenshotMode.initialScreen(arguments: []) == .flow)
        #expect(ScreenshotMode.isEnabled(arguments: ["--screenshot-mode"]))
        #expect(
            ScreenshotMode.initialScreen(arguments: [
                "--screenshot-mode",
                "--screenshot-screen=statistics",
            ]) == .statistics
        )
        #expect(
            ScreenshotMode.initialScreen(arguments: [
                "--screenshot-mode",
                "--screenshot-screen=statistics-dots",
            ]) == .statisticsDots
        )
        #expect(
            ScreenshotMode.initialScreen(arguments: [
                "--screenshot-mode",
                "--screenshot-screen=unknown",
            ]) == .flow
        )
    }

    @Test func screenshotArgumentsSelectLanguage() {
        #expect(ScreenshotMode.language(arguments: []) == .ja)
        #expect(
            ScreenshotMode.language(arguments: [
                "--screenshot-mode",
                "--screenshot-language=en",
            ]) == .en
        )
        #expect(
            ScreenshotMode.language(arguments: [
                "--screenshot-mode",
                "--screenshot-language=ru",
            ]) == .ru
        )
        #expect(
            ScreenshotMode.language(arguments: [
                "--screenshot-mode",
                "--screenshot-language=unknown",
            ]) == .ja
        )
    }

    @Test func screenshotPreferencesLeaveStandardSettingsUntouched() {
        let keys = ["settings.languageCode", "settings.appearance", "flow.selectedTodoID"]
        let before = keys.map { UserDefaults.standard.object(forKey: $0).map { String(describing: $0) } }
        for language in ScreenshotLanguage.allCases {
            let defaults = ScreenshotMode.configuredDefaults(arguments: [
                "--screenshot-mode", "--screenshot-language=\(language.rawValue)"
            ])
            #expect(defaults !== UserDefaults.standard)
            #expect(defaults.string(forKey: "settings.languageCode") == language.rawValue)
            #expect(defaults.string(forKey: "settings.appearance") == "dark")
        }
        let after = keys.map { UserDefaults.standard.object(forKey: $0).map { String(describing: $0) } }
        #expect(before == after)
    }

    @Test func screenshotSeedCreatesLargeIsolatedLocalizedWorkspaces() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let now = calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 24,
            hour: 18,
            minute: 30
        ))!

        let expectations: [(ScreenshotLanguage, String, String)] = [
            (.ja, "仕事", "報告書を仕上げる"),
            (.en, "Work", "Finish the report"),
            (.ru, "Работа", "Подготовить отчёт"),
            (.zhHans, ScreenshotCopy(language: .zhHans).workDirection, ScreenshotCopy(language: .zhHans).featuredTitle),
            (.zhHant, ScreenshotCopy(language: .zhHant).workDirection, ScreenshotCopy(language: .zhHant).featuredTitle),
        ]

        for (language, workDirectionName, featuredTitle) in expectations {
            let schema = Schema([
                Direction.self,
                Project.self,
                Todo.self,
                FlowSession.self,
                FlowSegment.self,
                FlowBreak.self,
            ])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )

            try ScreenshotDataSeeder.seedIfNeeded(
                in: container,
                now: now,
                language: language,
                calendar: calendar
            )

            let context = ModelContext(container)
            let directions = try context.fetch(FetchDescriptor<Direction>())
            let todos = try context.fetch(FetchDescriptor<Todo>())
            let sessions = try context.fetch(FetchDescriptor<FlowSession>())
            let breaks = try context.fetch(FetchDescriptor<FlowBreak>())

            let projects = try context.fetch(FetchDescriptor<Project>())
            #expect(projects.count == 4)
            #expect(directions.count == 6)
            #expect(todos.count >= 250)
            #expect(sessions.count >= 250)
            #expect(breaks.count >= 80)
            #expect(directions.contains { $0.name == workDirectionName })

            let featured = todos.first { $0.id == ScreenshotDataSeeder.featuredTodoID }
            #expect(featured?.project != nil)
            #expect(featured?.scheduledTimeMinutes == 14 * 60)
            #expect(featured?.title == featuredTitle)
            #expect(featured?.direction?.id == ScreenshotDataSeeder.featuredDirectionID)
            #expect(featured?.scheduledDate == calendar.startOfDay(for: now))

            let todayBreaks = breaks
                .filter { calendar.isDate($0.startedAt, inSameDayAs: now) }
                .sorted { $0.startedAt < $1.startedAt }
            #expect(todayBreaks.map(\.plannedDurationSeconds) == [5 * 60, 10 * 60])

            try verifyRealisticActivity(
                todos: todos, sessions: sessions, projects: projects,
                copy: ScreenshotCopy(language: language), today: calendar.startOfDay(for: now)
            )

            let firstCounts = (todos.count, sessions.count, breaks.count)
            try ScreenshotDataSeeder.seedIfNeeded(
                in: container,
                now: now,
                language: language,
                calendar: calendar
            )
            #expect(try context.fetchCount(FetchDescriptor<Todo>()) == firstCounts.0)
            #expect(try context.fetchCount(FetchDescriptor<FlowSession>()) == firstCounts.1)
            #expect(try context.fetchCount(FetchDescriptor<FlowBreak>()) == firstCounts.2)
        }
    }
    private func verifyRealisticActivity(
        todos: [Todo], sessions: [FlowSession], projects: [Project],
        copy: ScreenshotCopy, today: Date
    ) throws {
        let templates: [(String, [String], [Int])] = [
            (copy.workDirection, copy.templates.work, [50, 10, 25, 25, 10]),
            (copy.studyDirection, copy.templates.study, [20, 25, 25, 15, 20]),
            (copy.readingDirection, copy.templates.reading, [25, 20, 10, 25]),
            (copy.healthDirection, copy.templates.health, [30, 10, 25, 25]),
            (copy.personalDirection, copy.templates.personal, [20, 25, 15, 35, 10]),
            (copy.otherDirection, copy.templates.other, [10, 5, 20]),
        ]
        let reportProject = try #require(projects.first { $0.name == copy.projectNames[0] })
        let languageProject = try #require(projects.first { $0.name == copy.projectNames[1] })
        for session in sessions {
            let todo = try #require(session.todo)
            let end = try #require(session.endedAt)
            let seconds = try #require(session.actualFocusDurationSeconds)
            #expect(Int(end.timeIntervalSince(session.startedAt)) == seconds)
            #expect(session.resolvedSegments.reduce(0) { $0 + $1.resolvedFocusSeconds } == seconds)
            #expect(session.resolvedSegments.allSatisfy {
                $0.todo?.id == todo.id && $0.startedAt == session.startedAt && $0.endedAt == end
            })
            if session.startedAt < today {
                let template = try #require(templates.first { $0.0 == todo.area?.name })
                let index = try #require(template.1.firstIndex(of: todo.title))
                #expect(seconds == template.2[index] * 60)
                #expect(todo.focusDurationSeconds == seconds)
                if template.0 == copy.workDirection, index == 0 {
                    #expect(todo.project?.id == reportProject.id)
                } else if template.0 == copy.studyDirection {
                    #expect(todo.project?.id == languageProject.id)
                } else {
                    #expect(todo.project == nil)
                }
            }
        }
        let historicalHabits = todos.filter { $0.isHabitOccurrence && ($0.scheduledDate ?? today) < today }
        var occurrenceKeys = Set<String>()
        for todo in historicalHabits {
            let area = try #require(todo.area)
            let date = try #require(todo.scheduledDate)
            #expect(todo.habitOccurrence == true)
            #expect(!todo.isDeleted)
            #expect(occurrenceKeys.insert("\(area.id)/\(date.timeIntervalSince1970)").inserted)
            #expect(todo.measurement == (area.goalUnit == .minutes ? .minutes : .focusBlocks))
        }
        let chronological = sessions.sorted { $0.startedAt < $1.startedAt }
        for (previous, next) in zip(chronological, chronological.dropFirst()) {
            #expect(try #require(previous.endedAt) <= next.startedAt)
        }
        for todo in todos {
            let recordedSeconds = sessions.filter { $0.todo?.id == todo.id }
                .reduce(0) { $0 + ($1.actualFocusDurationSeconds ?? 0) }
            #expect((todo.focusDurationSeconds ?? 0) == recordedSeconds)
        }
        let todaySessions = sessions.filter { $0.startedAt >= today }
        #expect(todaySessions.reduce(0) { $0 + ($1.actualFocusDurationSeconds ?? 0) } == 165 * 60)
        let email = try #require(todaySessions.first { $0.todo?.title == copy.emailTitle })
        #expect(email.actualFocusDurationSeconds == 10 * 60)
        #expect(email.todo?.project == nil)
        let study = try #require(todaySessions.first { $0.todo?.title == copy.studyTitle })
        #expect(study.actualFocusDurationSeconds == 25 * 60)
        #expect(study.todo?.plannedAmount == 30)
        #expect(study.todo?.project?.id == languageProject.id)
        let planning = try #require(todos.first { $0.title == copy.planTitle && $0.scheduledDate == today })
        #expect(planning.project == nil)
        let fixtureText = (todos.map(\.title) + projects.map(\.name)).joined(separator: " ").lowercased()
        #expect(!fixtureText.contains("aws"))
        #expect(!fixtureText.contains("azure"))
    }

}
