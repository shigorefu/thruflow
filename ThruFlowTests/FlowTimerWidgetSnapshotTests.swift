//
//  FlowTimerWidgetSnapshotTests.swift
//  ThruFlowTests
//
//

import Foundation
import Testing
@testable import ThruFlow

@MainActor
struct FlowTimerWidgetSnapshotTests {
    @Test func minimalLiveActivityAlwaysCountsRemainingTimeDown() {
        #expect(
            FlowLiveActivityProgressSurface.minimal.countsDown(timerKind: .focus)
        )
        #expect(
            FlowLiveActivityProgressSurface.minimal.countsDown(timerKind: .breakTime)
        )
        #expect(
            !FlowLiveActivityProgressSurface.standard.countsDown(timerKind: .focus)
        )
        #expect(
            FlowLiveActivityProgressSurface.standard.countsDown(timerKind: .breakTime)
        )
    }

    @Test func liveActivityBreakPresentationReplacesTaskContext() {
        #expect(
            FlowLiveActivityPresentation.emoji(
                taskEmoji: "📚",
                timerKind: .focus
            ) == "📚"
        )
        #expect(
            FlowLiveActivityPresentation.title(
                taskTitle: "Swift",
                timerKind: .focus
            ) == "Swift"
        )
        #expect(
            FlowLiveActivityPresentation.areaName(
                "学習",
                timerKind: .focus
            ) == "学習"
        )

        #expect(
            FlowLiveActivityPresentation.emoji(
                taskEmoji: "📚",
                timerKind: .breakTime
            ) == "☕️"
        )
        #expect(
            FlowLiveActivityPresentation.title(
                taskTitle: "Swift",
                timerKind: .breakTime
            ) == String(localized: "休憩")
        )
        #expect(
            FlowLiveActivityPresentation.areaName(
                "学習",
                timerKind: .breakTime
            ).isEmpty
        )
    }

    @Test func liveActivityContentMapsToTimerWidgetSnapshot() {
        let sessionID = UUID(uuidString: "D0CC6DB2-BD54-475C-A76F-7BCE974DB1A4")!
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let plannedEndAt = startedAt.addingTimeInterval(25 * 60)
        let updatedAt = startedAt.addingTimeInterval(5 * 60)
        let content = FlowLiveActivityContent(
            sessionID: sessionID,
            taskEmoji: "📚",
            taskTitle: "Swift",
            areaEmoji: "🎓",
            areaName: "学習",
            areaColorHex: "#34C759",
            modeRawValue: "focus",
            modeName: "Focus",
            status: .focus,
            timerKind: .focus,
            timerStartedAt: startedAt,
            plannedEndAt: plannedEndAt,
            remainingSeconds: 20 * 60,
            progress: 0.2,
            updatedAt: updatedAt
        )

        let snapshot = content.timerWidgetSnapshot

        #expect(snapshot.sessionID == sessionID)
        #expect(snapshot.taskEmoji == "📚")
        #expect(snapshot.taskTitle == "Swift")
        #expect(snapshot.areaName == "学習")
        #expect(snapshot.areaColorHex == "#34C759")
        #expect(snapshot.modeName == "Focus")
        #expect(snapshot.timerRange == startedAt...plannedEndAt)
        #expect(!snapshot.isPaused)
        #expect(!snapshot.progressCountsDown)
    }

    @Test func timerWidgetSnapshotStoreRoundTripsAndClears() throws {
        let suiteName = "FlowTimerWidgetSnapshotTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = FlowTimerWidgetSnapshotStore(defaults: defaults)
        let snapshot = FlowTimerWidgetSnapshot(
            sessionID: UUID(),
            taskEmoji: "☕️",
            taskTitle: "休憩",
            areaName: "",
            areaColorHex: "#8E8E93",
            modeName: "Sprint",
            status: .paused,
            timerKind: .breakTime,
            timerStartedAt: Date(timeIntervalSince1970: 2_000),
            plannedEndAt: Date(timeIntervalSince1970: 2_180),
            remainingSeconds: 90,
            progress: 0.5,
            updatedAt: Date(timeIntervalSince1970: 2_090)
        )

        store.save(snapshot)

        let encoded = try JSONEncoder().encode(snapshot)
        let json = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        #expect(json["directionName"] as? String == "")
        #expect(json["directionColorHex"] as? String == "#8E8E93")
        #expect(json["areaName"] == nil)
        #expect(json["areaColorHex"] == nil)

        #expect(store.load() == snapshot)
        #expect(store.load()?.isPaused == true)
        #expect(store.load()?.progressCountsDown == true)

        store.clear()

        #expect(store.load() == nil)
    }
}
