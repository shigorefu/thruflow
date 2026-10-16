import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct ProjectTests {
    @Test func projectTaskPersistsAndCompletingProjectPreservesTaskAndFlow() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "Cloud", type: .neutral)
        context.insert(area)
        let service = ProjectEditingService()
        let project = try service.save(name: " AWS ", notes: " Exam ", area: area, modelContext: context)
        let task = try TaskEditingService().save(draft: TodoDraft(title: "Study", area: area, project: project), modelContext: context)
        let flow = try FlowHistoryEditor().createManual(todo: task, area: area, mode: .twentyFiveFive,
            startedAt: Date(timeIntervalSince1970: 1_000), focusSeconds: 1500, modelContext: context)
        let taskUpdatedAt = task.updatedAt
        try service.setCompleted(true, for: project, modelContext: context)
        #expect(project.isCompleted)
        #expect(!task.isCompleted)
        #expect(task.updatedAt == taskUpdatedAt)
        #expect(flow.todo?.id == task.id)
        #expect(flow.actualFocusDurationSeconds == 1500)
        var draft = TodoDraft(todo: task)
        draft.title = "Renamed"
        _ = try TaskEditingService().save(draft: draft, editing: task, modelContext: context)
        let loaded = try #require(try ModelContext(container).fetch(FetchDescriptor<Todo>()).first)
        #expect(loaded.project?.id == project.id)
        #expect(loaded.project?.area?.id == area.id)
        #expect(loaded.project?.name == "AWS")
        #expect(loaded.project?.notes == "Exam")
        try service.setCompleted(false, for: project, modelContext: context)
        #expect(project.isAvailableForNewTasks)
        #expect(!task.isCompleted)
    }

    @Test func invalidProjectAssignmentsAreRejectedAndDirectTasksRemainValid() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "Cloud", type: .neutral)
        let other = Area(name: "Home", type: .neutral)
        context.insert(area); context.insert(other)
        let project = try ProjectEditingService().save(name: "Azure", area: area, modelContext: context)
        let service = TaskEditingService()
        #expect(service.validationErrors(for: TodoDraft(area: other, project: project)) == [.projectAreaMismatch])
        try ProjectEditingService().setCompleted(true, for: project, modelContext: context)
        #expect(service.validationErrors(for: TodoDraft(area: area, project: project)) == [.unavailableProject])
        try ProjectEditingService().setCompleted(false, for: project, modelContext: context)
        try AreaLifecycleService().archive(area, modelContext: context)
        #expect(service.validationErrors(for: TodoDraft(area: area, project: project)) == [.unavailableProject])
        let direct = try service.save(draft: TodoDraft(area: other), modelContext: context)
        #expect(direct.project == nil)
        #expect(direct.area?.id == other.id)
        #expect(throws: ProjectEditingError.self) {
            try ProjectEditingService().save(name: "New", area: area, modelContext: context)
        }
    }

    @Test func generatedHabitCannotAcquireProjectAndManualTaskCan() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "Study", type: .habit)
        context.insert(area)
        let project = try ProjectEditingService().save(name: "Exam", area: area, modelContext: context)
        let generated = Todo(title: "Study", area: area, habitOccurrence: true)
        context.insert(generated); try context.save()
        var draft = TodoDraft(todo: generated); draft.project = project
        _ = try TaskEditingService().save(draft: draft, editing: generated, modelContext: context)
        #expect(generated.project == nil)
        let manual = try TaskEditingService().save(draft: draft, modelContext: context)
        #expect(manual.project?.id == project.id)
        #expect(!manual.isHabitOccurrence)
    }

    @Test func projectParentCannotChangeAndTaskCanLeaveProject() throws {
        let container = try makeContainer(); let context = container.mainContext
        let area = Area(name: "Cloud", type: .neutral); let other = Area(name: "Work", type: .neutral)
        context.insert(area); context.insert(other)
        let project = try ProjectEditingService().save(name: "AWS", area: area, modelContext: context)
        #expect(throws: ProjectEditingError.self) {
            try ProjectEditingService().save(name: "AWS", area: other, editing: project, modelContext: context)
        }
        let task = try TaskEditingService().save(draft: TodoDraft(area: area, project: project), modelContext: context)
        var draft = TodoDraft(todo: task); draft.area = other; draft.project = nil
        _ = try TaskEditingService().save(draft: draft, editing: task, modelContext: context)
        #expect(task.project == nil)
        #expect(task.area?.id == other.id)
    }

    @Test func failedProjectSaveAndStatusChangeRestoreRetainedModels() throws {
        let container = try makeContainer(); let context = container.mainContext
        let area = Area(name: "Cloud", type: .neutral); context.insert(area)
        let project = try ProjectEditingService().save(name: "AWS", notes: "Original", area: area, modelContext: context)
        let service = ProjectEditingService(saveChanges: { _ in throw Failure.save })
        #expect(throws: Failure.self) { try service.save(name: "Azure", notes: "Changed", area: area, editing: project, modelContext: context) }
        #expect(project.name == "AWS"); #expect(project.notes == "Original")
        #expect(throws: Failure.self) { try service.setCompleted(true, for: project, modelContext: context) }
        #expect(!project.isCompleted)
        #expect(throws: Failure.self) { try service.save(name: "New", area: area, modelContext: context) }
        #expect(try context.fetch(FetchDescriptor<Project>()).count == 1)
        let loaded = try #require(try ModelContext(container).fetch(FetchDescriptor<Project>()).first)
        #expect(loaded.name == "AWS"); #expect(!loaded.isCompleted)
    }

    @Test func failedTaskReassignmentRestoresOriginalProject() throws {
        let container = try makeContainer(); let context = container.mainContext
        let area = Area(name: "Cloud", type: .neutral); context.insert(area)
        let project = try ProjectEditingService().save(name: "AWS", area: area, modelContext: context)
        let task = try TaskEditingService().save(draft: TodoDraft(area: area, project: project), modelContext: context)
        var draft = TodoDraft(todo: task); draft.project = nil
        #expect(throws: Failure.self) {
            try TaskEditingService(saveChanges: { _ in throw Failure.save }).save(draft: draft, editing: task, modelContext: context)
        }
        #expect(task.project?.id == project.id)
        let loaded = try #require(try ModelContext(container).fetch(FetchDescriptor<Todo>()).first)
        #expect(loaded.project?.id == project.id)
    }

    @Test func resetIncludesProjects() throws {
        let container = try makeContainer(); let context = container.mainContext
        let area = Area(name: "Cloud", type: .neutral); context.insert(area)
        _ = try ProjectEditingService().save(name: "AWS", area: area, modelContext: context)
        _ = try AppDataResetService().reset(modelContext: context)
        #expect(try context.fetch(FetchDescriptor<Project>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Area>()).isEmpty)
    }

    @Test func existingStoreMigratesWithoutLosingIdentityOrHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("legacy.store")
        let ids = try writeLegacyStore(at: url)
        let schema = AppModelContainerFactory.schema
        let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let task = try #require(try context.fetch(FetchDescriptor<Todo>()).first)
        let flow = try #require(try context.fetch(FetchDescriptor<FlowSession>()).first)
        #expect(task.id == ids.task); #expect(task.area?.id == ids.area)
        #expect(task.project == nil); #expect(task.actualProgress == 25)
        #expect(flow.id == ids.flow); #expect(flow.todo?.id == ids.task)
        #expect(flow.actualFocusDurationSeconds == 1500)
        #expect(flow.segments?.count == 1)
        #expect(try context.fetch(FetchDescriptor<FlowBreak>()).count == 1)
        let project = try ProjectEditingService().save(name: "AWS", area: try #require(task.area), modelContext: context)
        var draft = TodoDraft(todo: task); draft.project = project
        _ = try TaskEditingService().save(draft: draft, editing: task, modelContext: context)
        #expect(task.project?.id == project.id)
        #expect(flow.todo?.id == task.id)
    }

    private func writeLegacyStore(at url: URL) throws -> (area: UUID, task: UUID, flow: UUID) {
        let schema = Schema(versionedSchema: PreProjectSchema.self)
        let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let area = PreProjectSchema.Direction(); area.name = "Cloud"
        let task = PreProjectSchema.Todo(); task.title = "Legacy"; task.direction = area
        task.measurementRawValue = TodoMeasurement.minutes.rawValue; task.actualProgress = 25; task.plannedAmount = 30
        let flow = PreProjectSchema.FlowSession(); flow.todo = task; flow.direction = area
        flow.actualFocusDurationSeconds = 1500; flow.endedAt = flow.startedAt.addingTimeInterval(1500)
        let segment = PreProjectSchema.FlowSegment(); segment.session = flow; segment.todo = task
        segment.direction = area; segment.endFocusSeconds = 1500
        let rest = PreProjectSchema.FlowBreak(); rest.previousSessionID = flow.id
        context.insert(area); context.insert(task); context.insert(flow); context.insert(segment); context.insert(rest)
        try context.save()
        return (area.id, task.id, flow.id)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = AppModelContainerFactory.schema
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
    }
    private enum Failure: Error { case save }
}
