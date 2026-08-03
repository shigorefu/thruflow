import Foundation
import SwiftData
import Testing
@testable import ThruFlow

struct DefaultDirectionReconcilerTests {
    @Test func taskInboxUsesStableSystemRole() {
        let inbox = DefaultDirections.makeTaskInbox(now: Date(timeIntervalSince1970: 0))

        #expect(inbox.systemRole == .taskInbox)
        #expect(DefaultDirections.isTaskInbox(inbox))
    }

    @Test func legacyLocalizedInboxesAreRecognizedWithoutMatchingUserDirections() {
        for name in ["その他", "Other", "Другое"] {
            let legacy = Direction(
                name: name,
                type: .neutral,
                symbolName: DefaultDirections.taskInboxSymbol,
                colorHex: DefaultDirections.taskInboxColorHex
            )
            #expect(DefaultDirections.isTaskInbox(legacy))
        }

        let userDirection = Direction(name: "Other", type: .neutral)
        #expect(!DefaultDirections.isTaskInbox(userDirection))
    }

    @Test @MainActor func duplicateInboxesConvergeWithoutLosingRelationships() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let oldDate = Date(timeIntervalSince1970: 100)
        let newDate = Date(timeIntervalSince1970: 200)
        let canonical = Direction(
            name: "その他",
            type: .neutral,
            symbolName: DefaultDirections.taskInboxSymbol,
            colorHex: DefaultDirections.taskInboxColorHex,
            createdAt: oldDate,
            updatedAt: oldDate
        )
        let duplicate = DefaultDirections.makeTaskInbox(now: newDate)
        let ordinaryDirection = Direction(name: "Other", type: .neutral, createdAt: oldDate)
        let todo = Todo(title: "記録", direction: duplicate, createdAt: newDate)
        let session = FlowSession(
            direction: duplicate,
            todo: todo,
            mode: .sprint,
            startedAt: newDate,
            plannedEndAt: newDate.addingTimeInterval(720),
            plannedFocusDurationSeconds: 720,
            plannedBreakDurationSeconds: 180
        )
        let segment = FlowSegment(
            session: session,
            direction: duplicate,
            todo: todo,
            startedAt: newDate,
            startFocusSeconds: 0
        )

        for model in [canonical, duplicate, ordinaryDirection] {
            context.insert(model)
        }
        context.insert(todo)
        context.insert(session)
        context.insert(segment)
        try context.save()

        let result = try DefaultDirectionReconciler().reconcile(
            modelContext: context,
            now: Date(timeIntervalSince1970: 300)
        )

        #expect(result.canonicalID == canonical.id)
        #expect(result.archivedDuplicateCount == 1)
        #expect(canonical.systemRole == .taskInbox)
        #expect(duplicate.isArchived)
        #expect(todo.direction?.id == canonical.id)
        #expect(session.direction?.id == canonical.id)
        #expect(segment.direction?.id == canonical.id)
        #expect(!ordinaryDirection.isArchived)

        let activeInboxes = try context.fetch(FetchDescriptor<Direction>())
            .filter(DefaultDirections.isTaskInbox)
        #expect(activeInboxes.map(\.id) == [canonical.id])
    }

    @Test @MainActor func reconciliationCreatesOnlyOneInboxWhenMissing() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let reconciler = DefaultDirectionReconciler()

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
        let activeInboxes = try context.fetch(FetchDescriptor<Direction>())
            .filter(DefaultDirections.isTaskInbox)
        #expect(activeInboxes.count == 1)
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Direction.self,
            Todo.self,
            FlowSession.self,
            FlowSegment.self,
            FlowBreak.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
