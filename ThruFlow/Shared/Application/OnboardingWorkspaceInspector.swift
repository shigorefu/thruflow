struct OnboardingWorkspaceState: Equatable, Sendable {
    let hasUserAreas: Bool
    let hasTasks: Bool
    let hasFlowHistory: Bool

    var hasUserContent: Bool {
        hasUserAreas || hasTasks || hasFlowHistory
    }
}

@MainActor
enum OnboardingWorkspaceInspector {
    static func inspect(
        directions: [Direction],
        todos: [Todo],
        flowSessions: [FlowSession],
        flowBreaks: [FlowBreak]
    ) -> OnboardingWorkspaceState {
        OnboardingWorkspaceState(
            hasUserAreas: directions.contains { !DefaultDirections.isTaskInboxRecord($0) },
            hasTasks: todos.contains { !$0.isDeleted },
            hasFlowHistory: !flowSessions.isEmpty || flowBreaks.contains { !$0.isDeleted }
        )
    }
}
