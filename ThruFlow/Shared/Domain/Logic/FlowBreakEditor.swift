//
//  FlowBreakEditor.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/14.
//

import Foundation
import SwiftData

enum FlowBreakEditorError: Error, Equatable {
    case activeFlowWouldMove
}

struct FlowBreakEditResult: Equatable {
    let durationSeconds: Int
    let shiftedSeconds: Int
}

struct FlowBreakEditor {
    static let minimumDurationMinutes = 1
    static let maximumDurationMinutes = 720

    func updateDuration(
        of flowBreak: FlowBreak,
        minutes: Int,
        modelContext: ModelContext,
        protectedSessionID: UUID? = nil,
        now: Date = .now
    ) throws -> FlowBreakEditResult {
        let clampedMinutes = min(
            max(minutes, Self.minimumDurationMinutes),
            Self.maximumDurationMinutes
        )
        let durationSeconds = clampedMinutes * 60
        let adjustedEnd = flowBreak.startedAt.addingTimeInterval(TimeInterval(durationSeconds))
        let sessions = (try? modelContext.fetch(FetchDescriptor<FlowSession>())) ?? []
        let seriesSessions = sessions
            .filter { ($0.seriesID ?? $0.id) == flowBreak.seriesID }
            .sorted { $0.startedAt < $1.startedAt }
        let nextSession = flowBreak.nextSessionID.flatMap { nextID in
            seriesSessions.first { $0.id == nextID }
        }
        let shiftedSeconds = nextSession.map {
            max(0, Int(ceil(adjustedEnd.timeIntervalSince($0.startedAt))))
        } ?? 0

        if shiftedSeconds > 0,
           let protectedSessionID,
           let protectedSession = seriesSessions.first(where: { $0.id == protectedSessionID }),
           let nextSession,
           protectedSession.startedAt >= nextSession.startedAt {
            throw FlowBreakEditorError.activeFlowWouldMove
        }

        flowBreak.adjustedEndAt = adjustedEnd
        flowBreak.updatedAt = now

        if shiftedSeconds > 0, let nextSession {
            let offset = TimeInterval(shiftedSeconds)
            for session in seriesSessions where session.startedAt >= nextSession.startedAt {
                shift(session: session, by: offset, now: now)
            }

            let breaks = (try? modelContext.fetch(FetchDescriptor<FlowBreak>())) ?? []
            for laterBreak in breaks where
                laterBreak.id != flowBreak.id &&
                laterBreak.seriesID == flowBreak.seriesID &&
                laterBreak.startedAt >= nextSession.startedAt &&
                !laterBreak.isDeleted {
                shift(flowBreak: laterBreak, by: offset, now: now)
            }
        }

        try modelContext.save()
        return FlowBreakEditResult(
            durationSeconds: durationSeconds,
            shiftedSeconds: shiftedSeconds
        )
    }

    private func shift(session: FlowSession, by seconds: TimeInterval, now: Date) {
        session.startedAt = session.startedAt.addingTimeInterval(seconds)
        session.plannedEndAt = session.plannedEndAt.addingTimeInterval(seconds)
        session.endedAt = session.endedAt?.addingTimeInterval(seconds)
        session.updatedAt = now

        for segment in session.resolvedSegments {
            segment.startedAt = segment.startedAt.addingTimeInterval(seconds)
            segment.endedAt = segment.endedAt?.addingTimeInterval(seconds)
        }
    }

    private func shift(flowBreak: FlowBreak, by seconds: TimeInterval, now: Date) {
        flowBreak.startedAt = flowBreak.startedAt.addingTimeInterval(seconds)
        flowBreak.timerStoppedAt = flowBreak.timerStoppedAt?.addingTimeInterval(seconds)
        flowBreak.connectedUntil = flowBreak.connectedUntil?.addingTimeInterval(seconds)
        flowBreak.adjustedEndAt = flowBreak.adjustedEndAt?.addingTimeInterval(seconds)
        flowBreak.updatedAt = now
    }
}
