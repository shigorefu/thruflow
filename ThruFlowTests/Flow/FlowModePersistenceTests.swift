import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct FlowModePersistenceTests {
    @Test func modeUpdatesDisplayBeforePersistingAndCoalescesRapidSelections() throws {
        let fixture = try Fixture()
        let store = fixture.store
        let session = try #require(store.activeSession)
        let revision = session.runtimeRevision
        store.selectMode(.sprint, modelContext: fixture.context, now: fixture.now)
        #expect(store.timerState?.mode == .sprint)
        #expect(session.mode == .twentyFiveFive)
        #expect(fixture.defaults.string(forKey: "flow.selectedMode") == FlowMode.twentyFiveFive.rawValue)
        store.selectMode(.fiftyTen, modelContext: fixture.context, now: fixture.now)
        #expect(store.timerState?.plannedFocusDurationSeconds == 3000)
        #expect(session.runtimeRevision == revision)
        #expect(store.flushPendingModeChange())
        #expect(session.mode == .fiftyTen)
        #expect(session.runtimeRevision == revision + 1)
        #expect(fixture.defaults.string(forKey: "flow.selectedMode") == FlowMode.fiftyTen.rawValue)
        #expect(store.flushPendingModeChange())
        #expect(session.runtimeRevision == revision + 1)
    }

    @Test func pausePersistsSelectedDurationBeforeChangingPhase() throws {
        let fixture = try Fixture()
        fixture.store.selectMode(.fiftyTen, modelContext: fixture.context, now: fixture.now)
        fixture.store.pause(modelContext: fixture.context, now: fixture.now.addingTimeInterval(10))
        let session = try #require(fixture.store.activeSession)
        #expect(session.mode == .fiftyTen)
        #expect(session.phase == .paused)
        #expect(session.plannedFocusDurationSeconds == 3000)
        #expect(fixture.store.flushPendingModeChange())
        #expect(session.phase == .paused)
    }

    @Test func stopCannotBeOverwrittenByPendingMode() throws {
        let fixture = try Fixture()
        fixture.store.selectMode(.sprint, modelContext: fixture.context, now: fixture.now)
        fixture.store.stop(modelContext: fixture.context, now: fixture.now.addingTimeInterval(120))
        let session = try #require(fixture.store.activeSession)
        #expect(session.phase == .awaitingResult)
        #expect(session.mode == .sprint)
        #expect(fixture.store.flushPendingModeChange())
        #expect(session.phase == .awaitingResult)
    }

    @Test func leavingForegroundFlushesModeAndSettings() throws {
        let fixture = try Fixture()
        fixture.store.selectMode(.fiftyTen, modelContext: fixture.context, now: fixture.now)
        fixture.store.endSynchronization()
        #expect(fixture.store.activeSession?.mode == .fiftyTen)
        #expect(fixture.defaults.string(forKey: "flow.selectedMode") == FlowMode.fiftyTen.rawValue)
    }

    @Test func resetCancelsIdlePendingSelection() throws {
        let fixture = try Fixture(start: false)
        fixture.store.selectMode(.fiftyTen, modelContext: fixture.context, now: fixture.now)
        fixture.store.resetAfterApplicationDataReset()
        #expect(fixture.store.flushPendingModeChange())
        #expect(fixture.store.selectedMode == .twentyFiveFive)
        #expect(fixture.defaults.string(forKey: "flow.selectedMode") == FlowMode.twentyFiveFive.rawValue)
        #expect(fixture.store.timerState == nil)
    }

    @Test func deletedSessionIsNotRevivedByPendingMode() throws {
        let fixture = try Fixture()
        let session = try #require(fixture.store.activeSession)
        fixture.store.selectMode(.sprint, modelContext: fixture.context, now: fixture.now)
        fixture.context.delete(session)
        #expect(!fixture.store.flushPendingModeChange())
        #expect(fixture.store.timerState == nil)
        #expect(fixture.store.activeSession == nil)
    }

    @Test func newerSessionRuntimeWinsOverPendingMode() throws {
        let fixture = try Fixture()
        let session = try #require(fixture.store.activeSession)
        let durable = try #require(fixture.store.timerState)
        fixture.store.selectMode(.sprint, modelContext: fixture.context, now: fixture.now)
        let externalState = FlowTimerEngine().pause(durable, now: fixture.now.addingTimeInterval(5))
        session.apply(timerState: externalState, now: fixture.now.addingTimeInterval(5))
        let externalVersion = session.runtimeVersion
        #expect(!fixture.store.flushPendingModeChange())
        #expect(fixture.store.timerState == externalState)
        #expect(fixture.store.selectedMode == .twentyFiveFive)
        #expect(session.runtimeVersion == externalVersion)
    }

    @Test func failedModeCommitRestoresDurableStateAndKeepsUnrelatedEdits() throws {
        let fixture = try Fixture(saveModeChange: { _ in throw CocoaError(.fileWriteUnknown) })
        let session = try #require(fixture.store.activeSession)
        let originalState = fixture.store.timerState
        let originalVersion = session.runtimeVersion
        fixture.area.name = "Unrelated unsaved edit"
        fixture.store.selectMode(.sprint, modelContext: fixture.context, now: fixture.now)
        fixture.store.selectMode(.fiftyTen, modelContext: fixture.context, now: fixture.now)
        #expect(!fixture.store.flushPendingModeChange())
        #expect(fixture.store.timerState == originalState)
        #expect(fixture.store.selectedMode == .twentyFiveFive)
        #expect(session.mode == .twentyFiveFive)
        #expect(session.runtimeVersion == originalVersion)
        #expect(fixture.defaults.string(forKey: "flow.selectedMode") == FlowMode.twentyFiveFive.rawValue)
        #expect(fixture.area.name == "Unrelated unsaved edit")
    }

    @MainActor
    private final class Fixture {
        let container: ModelContainer
        let defaults: UserDefaults
        let store: ActiveFlowStore
        let area: Area
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let suite = "FlowModePersistenceTests.\(UUID())"
        var context: ModelContext { container.mainContext }

        init(start: Bool = true, saveModeChange: @escaping @MainActor (ModelContext) throws -> Void = { try $0.save() }) throws {
            let schema = Schema([Area.self, Project.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
            container = try ModelContainer(for: schema, configurations: [
                ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            ])
            defaults = try #require(UserDefaults(suiteName: suite))
            store = ActiveFlowStore(defaults: defaults, notifications: SilentNotifications(), saveModeChange: saveModeChange)
            area = Area(name: "Study", type: .neutral)
            context.insert(area)
            try context.save()
            if start { store.start(area: area, todo: nil, modelContext: context, now: now) }
        }
    }

    @MainActor
    private final class SilentNotifications: FlowNotificationService {
        func requestAuthorizationIfNeeded() {}
        func scheduleFocusFinished(mode: FlowMode, focusedSeconds: Int, fireDate: Date) {}
        func scheduleBreakFinished(fireDate: Date) {}
        func scheduleRunningTooLong(phase: FlowNotificationPhase, fireDate: Date) {}
        func cancelPendingFlowNotifications() {}
        func clearBadge() {}
    }
}
