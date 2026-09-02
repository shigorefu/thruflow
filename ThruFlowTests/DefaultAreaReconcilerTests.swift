import Foundation
import SwiftData
import Testing
@testable import ThruFlow

struct DefaultAreaReconcilerTests {
    @Test func taskInboxUsesStableSystemRole() {
        let inbox = DefaultAreas.makeTaskInbox(now: Date(timeIntervalSince1970: 0))

        #expect(inbox.systemRole == .taskInbox)
        #expect(DefaultAreas.isTaskInbox(inbox))
    }

    @Test func legacyLocalizedInboxesAreRecognizedWithoutMatchingUserAreas() {
        for name in ["その他", "Other", "Другое"] {
            let legacy = Area(
                name: name,
                type: .neutral,
                symbolName: DefaultAreas.taskInboxSymbol,
                colorHex: DefaultAreas.taskInboxColorHex
            )
            #expect(DefaultAreas.isTaskInbox(legacy))
        }

        let userArea = Area(name: "Other", type: .neutral)
        #expect(!DefaultAreas.isTaskInbox(userArea))
    }

    @Test @MainActor func duplicateInboxesConvergeWithoutLosingRelationships() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let oldDate = Date(timeIntervalSince1970: 100)
        let newDate = Date(timeIntervalSince1970: 200)
        let canonical = Area(
            name: "その他",
            type: .neutral,
            symbolName: DefaultAreas.taskInboxSymbol,
            colorHex: DefaultAreas.taskInboxColorHex,
            createdAt: oldDate,
            updatedAt: oldDate
        )
        let duplicate = DefaultAreas.makeTaskInbox(now: newDate)
        let ordinaryArea = Area(name: "Other", type: .neutral, createdAt: oldDate)
        let todo = Todo(title: "記録", area: duplicate, createdAt: newDate)
        let session = FlowSession(
            area: duplicate,
            todo: todo,
            mode: .sprint,
            startedAt: newDate,
            plannedEndAt: newDate.addingTimeInterval(720),
            plannedFocusDurationSeconds: 720,
            plannedBreakDurationSeconds: 180
        )
        let segment = FlowSegment(
            session: session,
            area: duplicate,
            todo: todo,
            startedAt: newDate,
            startFocusSeconds: 0
        )

        for model in [canonical, duplicate, ordinaryArea] {
            context.insert(model)
        }
        context.insert(todo)
        context.insert(session)
        context.insert(segment)
        try context.save()

        let result = try DefaultAreaReconciler().reconcile(
            modelContext: context,
            now: Date(timeIntervalSince1970: 300)
        )

        #expect(result.canonicalID == canonical.id)
        #expect(result.archivedDuplicateCount == 1)
        #expect(canonical.systemRole == .taskInbox)
        #expect(duplicate.isArchived)
        #expect(todo.area?.id == canonical.id)
        #expect(session.area?.id == canonical.id)
        #expect(segment.area?.id == canonical.id)
        #expect(!ordinaryArea.isArchived)

        let activeInboxes = try context.fetch(FetchDescriptor<Area>())
            .filter(DefaultAreas.isTaskInbox)
        #expect(activeInboxes.map(\.id) == [canonical.id])
    }

    @Test @MainActor func reconciliationCreatesOnlyOneInboxWhenMissing() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let reconciler = DefaultAreaReconciler()

        let first = try reconciler.reconcile(
            modelContext: context,
            now: Date(timeIntervalSince1970: 100)
        )
        let second = try reconciler.reconcile(
            modelContext: context,
            now: Date(timeIntervalSince1970: 200)
        )

        #expect(first.canonicalID == second.canonicalID)
        #expect(second.archivedDuplicateCount == 0)
        let activeInboxes = try context.fetch(FetchDescriptor<Area>())
            .filter(DefaultAreas.isTaskInbox)
        #expect(activeInboxes.count == 1)
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Area.self,
            Todo.self,
            FlowSession.self,
            FlowSegment.self,
            FlowBreak.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
