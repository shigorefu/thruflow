import Foundation
import Testing
@testable import ThruFlow

@MainActor
struct OnboardingAndReviewPromptTests {
    @Test func onboardingAppearsOnlyUntilItIsCompleted() {
        let defaults = makeDefaults()
        let firstLaunch = OnboardingStore(defaults: defaults, arguments: [])

        #expect(firstLaunch.isPresented)
        #expect(firstLaunch.launchKind == .firstRun)
        #expect(firstLaunch.experience == .undecided)
        firstLaunch.complete()
        #expect(!firstLaunch.isPresented)

        let nextLaunch = OnboardingStore(defaults: defaults, arguments: [])
        #expect(!nextLaunch.isPresented)
        nextLaunch.presentReplay()
        #expect(nextLaunch.isPresented)
        #expect(nextLaunch.launchKind == .replay)
        #expect(nextLaunch.experience == .tour)
    }

    @Test func applicationDataResetRestoresTheFirstRunJourney() {
        let defaults = makeDefaults()
        let store = OnboardingStore(defaults: defaults, arguments: [])
        store.complete()

        store.presentAfterApplicationDataReset()

        #expect(store.isPresented)
        #expect(store.launchKind == .firstRun)
        #expect(store.experience == .undecided)
        #expect(store.step == .welcome)
        #expect(OnboardingStore(defaults: defaults, arguments: []).isPresented)
    }

    @Test func previewModeNeverChangesFirstRunState() {
        let defaults = makeDefaults()
        let preview = OnboardingStore(
            defaults: defaults,
            arguments: ["--uitesting", "--onboarding-preview"]
        )

        #expect(preview.isPreviewMode)
        #expect(preview.isPresented)
        #expect(preview.launchKind == .preview)
        #expect(preview.experience == .guided)
        preview.complete()
        #expect(!preview.isPresented)

        let firstRealLaunch = OnboardingStore(defaults: defaults, arguments: [])
        #expect(firstRealLaunch.isPresented)
    }

    @Test func previewModeCanOpenAnExactWalkthroughStep() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            arguments: [
                "--onboarding-preview",
                "--onboarding-step=9",
                "--onboarding-experience=tour",
            ]
        )

        #expect(store.isPresented)
        #expect(store.step == .privacy)
        #expect(store.step.screen == .flow)
        #expect(store.experience == .tour)
    }

    @Test func tourWalkthroughMovesAcrossTenGuidanceSteps() {
        let store = OnboardingStore(defaults: makeDefaults(), arguments: [])

        #expect(!store.canAdvance)
        store.advance()
        #expect(store.step == .welcome)

        store.resolveWorkspace(hasUserContent: true)

        #expect(store.step == .welcome)
        #expect(store.step.screen == .flow)

        store.advance()
        #expect(store.step == .areas)
        #expect(store.step.screen == .directions)

        store.advance()
        #expect(store.step == .tasks)
        #expect(store.step.screen == .tasks)

        store.advance()
        #expect(store.step == .flow)
        #expect(store.step.screen == .flow)

        store.advance()
        #expect(store.step == .timer)
        #expect(store.step.screen == .flow)

        store.advance()
        #expect(store.step == .demo)
        #expect(store.step.screen == .flow)

        for _ in 0..<4 { store.advance() }
        #expect(store.step == .privacy)
        #expect(store.step.screen == .flow)

        store.advance()
        #expect(!store.isPresented)

        store.presentReplay()
        #expect(store.step == .welcome)
    }

    @Test func emptyWorkspaceUsesGuidedCreationAndRecordsOnlyStableIdentifiers() {
        let store = OnboardingStore(defaults: makeDefaults(), arguments: [])
        let areaID = UUID()
        let taskID = UUID()
        let taskPresentation = OnboardingTaskPresentation(
            title: "Report",
            areaName: "Work",
            areaSymbol: "💼",
            areaColorHex: "#007AFF"
        )

        store.resolveWorkspace(hasUserContent: false)
        #expect(store.experience == .guided)

        store.advance()
        #expect(store.step == .areas)
        #expect(store.canOfferAreaCreation)
        #expect(!store.canAdvance)
        #expect(store.requestAreaCreation())
        #expect(store.presentation == .areaEditor)

        #expect(store.recordArea(id: areaID))
        #expect(store.createdAreaID == areaID)
        #expect(store.step == .tasks)
        #expect(store.canOfferTaskCreation)
        #expect(!store.canAdvance)
        #expect(store.requestTaskCreation())
        #expect(store.presentation == .taskComposer)

        #expect(store.recordTask(id: taskID, presentation: taskPresentation))
        #expect(store.createdTaskID == taskID)
        #expect(store.demoTaskPresentation == taskPresentation)
        #expect(store.step == .flow)
        #expect(store.canAdvance)
    }

    @Test func existingDataAndReplayNeverOfferCreation() {
        let firstRun = OnboardingStore(defaults: makeDefaults(), arguments: [])
        firstRun.resolveWorkspace(hasUserContent: true)
        firstRun.advance()

        #expect(firstRun.experience == .tour)
        #expect(firstRun.step == .areas)
        #expect(!firstRun.canOfferAreaCreation)
        #expect(!firstRun.requestAreaCreation())
        #expect(!firstRun.recordArea(id: UUID()))

        firstRun.skip()
        firstRun.presentReplay()
        firstRun.advance()

        #expect(firstRun.launchKind == .replay)
        #expect(firstRun.experience == .tour)
        #expect(!firstRun.canOfferAreaCreation)
        #expect(!firstRun.requestAreaCreation())
    }

    @Test func newlyArrivedWorkspaceContentPreservesAnOpenDraftThenUsesTheTour() {
        let store = OnboardingStore(defaults: makeDefaults(), arguments: [])

        store.resolveWorkspace(hasUserContent: false)
        #expect(store.experience == .guided)
        store.advance()
        #expect(store.requestAreaCreation())
        #expect(store.presentation == .areaEditor)

        store.resolveWorkspace(hasUserContent: true)
        #expect(store.experience == .guided)
        #expect(store.presentation == .areaEditor)
        #expect(!store.canOfferAreaCreation)

        store.dismissPresentation()
        #expect(store.experience == .tour)
        #expect(store.presentation == nil)
    }

    @Test func savingAnOpenDraftAfterRemoteContentArrivesDoesNotOfferMoreCreation() {
        let store = OnboardingStore(defaults: makeDefaults(), arguments: [])

        store.resolveWorkspace(hasUserContent: false)
        store.advance()
        #expect(store.requestAreaCreation())

        store.resolveWorkspace(hasUserContent: true)
        #expect(store.recordArea(id: UUID()))
        #expect(store.experience == .tour)
        #expect(store.step == .tasks)
        #expect(!store.canOfferTaskCreation)
    }

    @Test func externalContentAfterTheFirstAreaStopsGuidedTaskCreation() {
        let store = OnboardingStore(defaults: makeDefaults(), arguments: [])

        store.resolveWorkspace(hasUserContent: false)
        store.advance()
        #expect(store.recordArea(id: UUID()))
        #expect(store.step == .tasks)

        store.resolveWorkspace(hasUserContent: true)
        #expect(store.experience == .tour)
        #expect(!store.canOfferTaskCreation)
    }

    @Test func dismissingCreationKeepsTheGuidedStepAvailable() {
        let store = OnboardingStore(defaults: makeDefaults(), arguments: [])
        store.resolveWorkspace(hasUserContent: false)
        store.advance()

        #expect(store.requestAreaCreation())
        store.dismissPresentation()

        #expect(store.presentation == nil)
        #expect(store.step == .areas)
        #expect(store.canOfferAreaCreation)
    }

    @Test func skipCompletesFromAnyGuidedStepAndKeepsTheCompletionKey() {
        let defaults = makeDefaults()
        let store = OnboardingStore(defaults: defaults, arguments: [])
        store.resolveWorkspace(hasUserContent: false)
        store.advance()
        _ = store.recordArea(id: UUID())

        store.skip()
        #expect(!store.isPresented)

        let nextLaunch = OnboardingStore(defaults: defaults, arguments: [])
        #expect(!nextLaunch.isPresented)
    }

    @Test func demoClockRunsACompressedFocusIntoBreakAndCancelsWhenLeavingItsStep() {
        let store = OnboardingStore(
            defaults: makeDefaults(),
            arguments: ["--onboarding-preview", "--onboarding-step=5"]
        )
        let start = Date(timeIntervalSince1970: 1_000)

        #expect(store.step == .demo)
        #expect(store.startDemo(at: start))
        #expect(store.demoState.isRunning)
        #expect(store.demoProgress(at: start.addingTimeInterval(4)) == 0.5)

        let initialProjection = store.demoState.projection(at: start)
        #expect(initialProjection.stage == .awaitingTask)
        #expect(initialProjection.phase == .idle)
        #expect(!initialProjection.contextIsSelected)
        #expect(initialProjection.remainingSeconds == 12 * 60)
        #expect(initialProjection.timerProgress == 0)

        let contextPress = store.demoState.projection(at: start.addingTimeInterval(0.5))
        #expect(contextPress.stage == .pressingContext)
        #expect(contextPress.contextIsPressed)
        #expect(!contextPress.contextIsSelected)

        let readyProjection = OnboardingDemoProjection(
            elapsed: OnboardingDemoProjection.contextSelectedAt
        )
        #expect(readyProjection.stage == .ready)
        #expect(readyProjection.contextIsSelected)

        let playPress = store.demoState.projection(at: start.addingTimeInterval(1.4))
        #expect(playPress.stage == .pressingPlay)
        #expect(playPress.primaryIsPressed)

        let focusStart = OnboardingDemoProjection(
            elapsed: OnboardingDemoProjection.focusStart
        )
        #expect(focusStart.stage == .focusing)
        #expect(focusStart.remainingSeconds == 12 * 60)

        let focusProjection = OnboardingDemoProjection(
            elapsed: OnboardingDemoProjection.focusStart
                + (OnboardingDemoProjection.focusEnd - OnboardingDemoProjection.focusStart) / 2
        )
        #expect(focusProjection.phase == .focusing)
        #expect(focusProjection.remainingSeconds == 6 * 60)
        #expect(abs(focusProjection.timerProgress - 0.5) < 0.000_001)

        let finalFocusProjection = store.demoState.projection(
            at: start.addingTimeInterval(5.449)
        )
        #expect(finalFocusProjection.phase == .focusing)
        #expect(finalFocusProjection.remainingSeconds <= 1)

        let heldFocusProjection = store.demoState.projection(
            at: start.addingTimeInterval(5.45)
        )
        #expect(heldFocusProjection.stage == .pressingBreak)
        #expect(heldFocusProjection.phase == .focusing)
        #expect(heldFocusProjection.remainingSeconds == 0)
        #expect(heldFocusProjection.primaryIsPressed)

        let breakProjection = OnboardingDemoProjection(
            elapsed: OnboardingDemoProjection.breakTransition
        )
        #expect(breakProjection.stage == .breakTime)
        #expect(breakProjection.phase == .breakTime)
        #expect(breakProjection.remainingSeconds == 3 * 60)
        #expect(breakProjection.timerProgress == 1)

        let laterBreakProjection = store.demoState.projection(at: start.addingTimeInterval(7))
        #expect(laterBreakProjection.phase == .breakTime)
        #expect(laterBreakProjection.timerProgress == 1)

        store.updateDemo(at: start.addingTimeInterval(7.9))
        #expect(store.demoState.isRunning)
        store.updateDemo(at: start.addingTimeInterval(8))
        #expect(store.demoState.isCompleted)
        #expect(store.demoProgress(at: start.addingTimeInterval(9)) == 1)

        let completedProjection = store.demoState.projection(at: start.addingTimeInterval(9))
        #expect(completedProjection.stage == .breakTime)
        #expect(completedProjection.phase == .breakTime)
        #expect(completedProjection.remainingSeconds == 3 * 60)
        #expect(completedProjection.timerProgress == 1)

        #expect(store.startDemo(at: start))
        store.goBack()
        #expect(store.step == .timer)
        #expect(store.demoState == .idle)
    }

    @Test func previewReplayStillNeverPersistsFirstRunCompletion() {
        let defaults = makeDefaults()
        let preview = OnboardingStore(
            defaults: defaults,
            arguments: ["--onboarding-preview"]
        )

        preview.presentReplay()
        #expect(preview.launchKind == .preview)
        #expect(preview.experience == .tour)
        preview.complete()

        #expect(OnboardingStore(defaults: defaults, arguments: []).isPresented)
    }

    @Test func reviewPromptRequiresTimeAndMeaningfulUse() {
        let calendar = testCalendar
        let installedAt = date(2026, 7, 1, calendar: calendar)
        let oneWeekLater = date(2026, 7, 8, calendar: calendar)
        let policy = ReviewPromptPolicy(calendar: calendar)

        #expect(!policy.isEligible(
            usage: usage(firstLaunchAt: installedAt, flows: 20, days: 7),
            currentVersion: "1.0",
            now: date(2026, 7, 7, calendar: calendar)
        ))
        #expect(!policy.isEligible(
            usage: usage(firstLaunchAt: installedAt, flows: 9, days: 4),
            currentVersion: "1.0",
            now: oneWeekLater
        ))
        #expect(policy.isEligible(
            usage: usage(firstLaunchAt: installedAt, flows: 5, days: 5),
            currentVersion: "1.0",
            now: oneWeekLater
        ))
        #expect(policy.isEligible(
            usage: usage(firstLaunchAt: installedAt, flows: 10, days: 2),
            currentVersion: "1.0",
            now: oneWeekLater
        ))
    }

    @Test func reviewPromptRunsAtMostOncePerAppVersion() {
        let calendar = testCalendar
        let installedAt = date(2026, 7, 1, calendar: calendar)
        let now = date(2026, 7, 20, calendar: calendar)
        let policy = ReviewPromptPolicy(calendar: calendar)
        let usedApp = usage(
            firstLaunchAt: installedAt,
            flows: 20,
            days: 8,
            lastRequestedVersion: "1.0"
        )

        #expect(!policy.isEligible(usage: usedApp, currentVersion: "1.0", now: now))
        #expect(policy.isEligible(usage: usedApp, currentVersion: "1.1", now: now))
    }

    @Test func reviewPromptStorePersistsInstallAndRequestMilestones() {
        let defaults = makeDefaults()
        let installedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let store = ReviewPromptStore(defaults: defaults, now: installedAt)

        #expect(store.firstLaunchAt == installedAt)
        #expect(store.lastRequestedVersion == nil)

        store.markRequested(version: "1.0")
        let restored = ReviewPromptStore(defaults: defaults, now: installedAt.addingTimeInterval(90_000))
        #expect(restored.firstLaunchAt == installedAt)
        #expect(restored.lastRequestedVersion == "1.0")
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func usage(
        firstLaunchAt: Date,
        flows: Int,
        days: Int,
        lastRequestedVersion: String? = nil
    ) -> ReviewPromptUsage {
        ReviewPromptUsage(
            firstLaunchAt: firstLaunchAt,
            completedFlowCount: flows,
            activeDayCount: days,
            lastRequestedVersion: lastRequestedVersion
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "OnboardingAndReviewPromptTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
