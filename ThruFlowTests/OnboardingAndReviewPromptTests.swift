import Foundation
import Testing
@testable import ThruFlow

@MainActor
struct OnboardingAndReviewPromptTests {
    @Test func onboardingAppearsOnlyUntilItIsCompleted() {
        let defaults = makeDefaults()
        let firstLaunch = OnboardingStore(defaults: defaults, arguments: [])

        #expect(firstLaunch.isPresented)
        firstLaunch.complete()
        #expect(!firstLaunch.isPresented)

        let nextLaunch = OnboardingStore(defaults: defaults, arguments: [])
        #expect(!nextLaunch.isPresented)
        nextLaunch.present()
        #expect(nextLaunch.isPresented)
    }

    @Test func previewModeNeverChangesFirstRunState() {
        let defaults = makeDefaults()
        let preview = OnboardingStore(
            defaults: defaults,
            arguments: ["--uitesting", "--onboarding-preview"]
        )

        #expect(preview.isPreviewMode)
        #expect(preview.isPresented)
        preview.complete()
        #expect(!preview.isPresented)

        let firstRealLaunch = OnboardingStore(defaults: defaults, arguments: [])
        #expect(firstRealLaunch.isPresented)
    }

    @Test func previewModeCanOpenAnExactWalkthroughStep() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            arguments: ["--onboarding-preview", "--onboarding-step=6"]
        )

        #expect(store.isPresented)
        #expect(store.step == .workflow)
        #expect(store.step.screen == .flow)
    }

    @Test func onboardingWalkthroughMovesAcrossRealApplicationScreens() {
        let store = OnboardingStore(defaults: makeDefaults(), arguments: [])

        #expect(store.step == .welcome)
        #expect(store.step.screen == .flow)

        store.advance()
        #expect(store.step == .flow)
        #expect(store.step.screen == .flow)

        store.advance()
        #expect(store.step == .directions)
        #expect(store.step.screen == .directions)

        for _ in 0..<4 { store.advance() }
        #expect(store.step == .workflow)
        #expect(store.step.screen == .flow)

        store.advance()
        #expect(!store.isPresented)

        store.present()
        #expect(store.step == .welcome)
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
