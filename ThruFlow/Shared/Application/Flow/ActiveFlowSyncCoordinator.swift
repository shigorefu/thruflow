import Foundation
import SwiftData

struct ActiveFlowSyncResolution {
    var canonicalSession: FlowSession?
    var supersededSessions: [FlowSession]
}

struct ActiveFlowSyncCandidate: Sendable {
    let id: UUID
    let version: FlowRuntimeVersion
}

@ModelActor
actor ActiveFlowSyncReader {
    func candidates() throws -> [ActiveFlowSyncCandidate] {
        try ActiveFlowSyncCoordinator.fetchCandidates(modelContext: modelContext).map {
            ActiveFlowSyncCandidate(id: $0.id, version: $0.runtimeVersion)
        }
    }
}

struct ActiveFlowSyncCoordinator {
    nonisolated static func fetchCandidates(modelContext: ModelContext) throws -> [FlowSession] {
        let focusing = FlowPhase.focusing.rawValue
        let paused = FlowPhase.paused.rawValue
        let breakTime = FlowPhase.breakTime.rawValue
        let awaitingExtension = FlowPhase.awaitingExtensionDecision.rawValue
        let completed = FlowSessionStatus.completed.rawValue
        let interrupted = FlowSessionStatus.interrupted.rawValue

        // Match reconstructableTimerState, including unknown legacy status values.
        return try modelContext.fetch(FetchDescriptor<FlowSession>(predicate: #Predicate {
            ($0.phaseRawValue == focusing || $0.phaseRawValue == paused ||
                $0.phaseRawValue == breakTime || $0.phaseRawValue == awaitingExtension) &&
                $0.statusRawValue != completed && $0.statusRawValue != interrupted
        }))
    }

    func resolve(modelContext: ModelContext) throws -> ActiveFlowSyncResolution {
        try resolve(sessions: Self.fetchCandidates(modelContext: modelContext))
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
