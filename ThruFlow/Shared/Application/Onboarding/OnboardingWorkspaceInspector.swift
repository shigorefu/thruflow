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
        areas: [Area],
        todos: [Todo],
        flowSessions: [FlowSession],
        flowBreaks: [FlowBreak]
    ) -> OnboardingWorkspaceState {
        OnboardingWorkspaceState(
            hasUserAreas: areas.contains { !DefaultAreas.isTaskInboxRecord($0) },
            hasTasks: todos.contains { !$0.isDeleted },
            hasFlowHistory: !flowSessions.isEmpty || flowBreaks.contains { !$0.isDeleted }
        )
    }
}
