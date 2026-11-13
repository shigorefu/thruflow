import Foundation
import Testing
@testable import ThruFlow

@MainActor
struct OnboardingWorkspaceInspectorTests {
    @Test func builtInOtherAreaAloneDoesNotCountAsUserContent() {
        let state = OnboardingWorkspaceInspector.inspect(
            areas: [DefaultAreas.makeTaskInbox()],
            todos: [],
            flowSessions: [],
            flowBreaks: []
        )

        #expect(!state.hasUserAreas)
        #expect(!state.hasTasks)
        #expect(!state.hasFlowHistory)
        #expect(!state.hasUserContent)
    }

    @Test func aRealAreaCountsEvenWhenArchived() {
        let area = Area(name: "Work", type: .neutral)
        area.archive()

        let state = OnboardingWorkspaceInspector.inspect(
            areas: [DefaultAreas.makeTaskInbox(), area],
            todos: [],
            flowSessions: [],
            flowBreaks: []
        )

        #expect(state.hasUserAreas)
        #expect(state.hasUserContent)
    }

    @Test func nonDeletedTasksCountButSoftDeletedTasksDoNot() {
        let area = DefaultAreas.makeTaskInbox()
        let deleted = Todo(title: "Deleted", area: area)
        deleted.softDelete()

        var state = OnboardingWorkspaceInspector.inspect(
            areas: [area],
            todos: [deleted],
            flowSessions: [],
            flowBreaks: []
        )
        #expect(!state.hasUserContent)

        let active = Todo(title: "Active", area: area)
        state = OnboardingWorkspaceInspector.inspect(
            areas: [area],
            todos: [deleted, active],
            flowSessions: [],
            flowBreaks: []
        )
        #expect(state.hasTasks)
        #expect(state.hasUserContent)
    }

    @Test func flowSessionOrActiveBreakCountsAsHistory() {
        let area = DefaultAreas.makeTaskInbox()
        let start = Date(timeIntervalSince1970: 1_000)
        let session = FlowSession(
            area: area,
            mode: .twentyFiveFive,
            startedAt: start,
            plannedEndAt: start.addingTimeInterval(1_500),
            plannedFocusDurationSeconds: 1_500,
            plannedBreakDurationSeconds: 300
        )

        var state = OnboardingWorkspaceInspector.inspect(
            areas: [area],
            todos: [],
            flowSessions: [session],
            flowBreaks: []
        )
        #expect(state.hasFlowHistory)

        let flowBreak = FlowBreak(
            seriesID: UUID(),
            previousSessionID: UUID(),
            startedAt: start,
            plannedDurationSeconds: 300
        )
        state = OnboardingWorkspaceInspector.inspect(
            areas: [area],
            todos: [],
            flowSessions: [],
            flowBreaks: [flowBreak]
        )
        #expect(state.hasFlowHistory)

        flowBreak.deletedAt = start
        state = OnboardingWorkspaceInspector.inspect(
            areas: [area],
            todos: [],
            flowSessions: [],
            flowBreaks: [flowBreak]
        )
        #expect(!state.hasFlowHistory)
    }
}
