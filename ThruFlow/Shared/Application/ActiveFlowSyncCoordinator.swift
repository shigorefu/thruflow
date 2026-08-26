import Foundation
import SwiftData

struct ActiveFlowSyncResolution {
    var canonicalSession: FlowSession?
    var supersededSessions: [FlowSession]
}

struct ActiveFlowSyncCoordinator {
    func resolve(modelContext: ModelContext) throws -> ActiveFlowSyncResolution {
        let sessions = try modelContext.fetch(FetchDescriptor<FlowSession>())
        return resolve(sessions: sessions)
    }

    func resolve(sessions: [FlowSession]) -> ActiveFlowSyncResolution {
        let activeSessions = sessions.filter { $0.reconstructableTimerState != nil }
        guard let canonicalSession = activeSessions.max(by: isOlder) else {
            return ActiveFlowSyncResolution(
                canonicalSession: nil,
                supersededSessions: []
            )
        }

        return ActiveFlowSyncResolution(
            canonicalSession: canonicalSession,
            supersededSessions: activeSessions.filter { $0.id != canonicalSession.id }
        )
    }

    private func isOlder(_ lhs: FlowSession, _ rhs: FlowSession) -> Bool {
        if lhs.runtimeVersion != rhs.runtimeVersion {
            return lhs.runtimeVersion < rhs.runtimeVersion
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    func interruptSuperseded(
        _ sessions: [FlowSession],
        canonicalSession: FlowSession,
        now: Date
    ) {
        for session in sessions {
            session.phase = .completed
            session.status = .interrupted
            session.endedAt = session.endedAt ?? min(now, canonicalSession.updatedAt)
            session.completedAt = session.completedAt ?? session.endedAt
            session.recordRuntimeMutation(now: now)
        }
    }
}
