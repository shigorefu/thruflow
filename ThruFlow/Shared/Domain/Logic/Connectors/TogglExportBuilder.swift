import Foundation

@MainActor struct TogglExportBuilder {
    func jobs(sessions: [FlowSession], configuration: TogglConfiguration, deviceID: String, now: Date) -> [TogglExportJob] {
        guard configuration.isEnabled, let since = configuration.enabledAt,
              let workspace = configuration.workspaceID else { return [] }
        var result: [TogglExportJob] = []
        for session in sessions {
            guard session.recordingDeviceID == deviceID, session.status == .completed,
                  session.createdAt >= since, session.startedAt >= since,
                  let end = session.endedAt, end <= now,
                  session.resolvedActualFocusDurationSeconds > 0 else { continue }
            let segments = session.resolvedSegments
            // Every newly started Flow has segments. An empty relationship may be incomplete CloudKit delivery.
            guard !segments.isEmpty,
                  segments.allSatisfy({ $0.endedAt != nil && $0.endFocusSeconds != nil }),
                  segments.reduce(0, { $0 + $1.resolvedFocusSeconds }) == session.resolvedActualFocusDurationSeconds else { continue }
            for segment in segments {
                append(id: segment.id, session: session, area: segment.area, todo: segment.todo,
                       start: segment.startedAt, end: segment.endedAt!, seconds: segment.resolvedFocusSeconds)
            }
        }
        return result.sorted { $0.payload.start < $1.payload.start }

        func append(id: UUID, session: FlowSession, area: Area?, todo: Todo?, start: Date, end: Date, seconds: Int) {
            guard seconds > 0, end > start, seconds <= Int(end.timeIntervalSince(start)) + 1,
                  let area, let project = configuration.areaProjects[area.id.uuidString] else { return }
            let title = todo.map(TodoDisplay.title(for:)) ?? area.name
            let payload = TogglTimePayload(workspace_id: workspace, project_id: project,
                                           description: title, start: ISO8601DateFormatter().string(from: start), duration: seconds)
            result.append(TogglExportJob(id: configuration.account.id + "/" + session.id.uuidString + "/" + id.uuidString,
                                        accountID: configuration.account.id, deviceID: deviceID, sessionID: session.id, payload: payload))
        }
    }
}
