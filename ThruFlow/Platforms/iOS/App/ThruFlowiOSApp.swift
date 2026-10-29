import AppIntents
import SwiftData
import SwiftUI

@main
struct ThruFlowiOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var activeFlowStore: ActiveFlowStore
    @StateObject private var settings: AppSettings
    @StateObject private var taskReminders = TaskReminderScheduler()
    @StateObject private var onboarding: OnboardingStore
    @StateObject private var connectors = ConnectorStore()

    private let modelContainer: ModelContainer
    private let liveActivityControl: FlowLiveActivityControl
    private let appDefaults: UserDefaults
    private let isScreenshotMode: Bool

    init() {
        let isScreenshotMode = ScreenshotMode.isEnabled()
        let defaults = ScreenshotMode.configuredDefaults()
        let modelContainer = AppModelContainerFactory.make()
        let liveActivities: any LiveActivityService = isScreenshotMode
            ? NoopLiveActivityService() : IOSFlowLiveActivityService()
        let activeFlowStore = ActiveFlowStore(
            defaults: defaults,
            notifications: isScreenshotMode ? ScreenshotFlowNotificationService() : nil,
            liveActivities: liveActivities
        )
        let liveActivityControl = FlowLiveActivityControl(
            seekBackward: { [weak activeFlowStore] in
                activeFlowStore?.seekBackward(modelContext: modelContainer.mainContext)
            },
            togglePause: { [weak activeFlowStore] in
                guard let activeFlowStore else { return }
                let context = modelContainer.mainContext
                if activeFlowStore.phase == .paused {
                    activeFlowStore.resume(modelContext: context)
                } else if activeFlowStore.phase == .focusing || activeFlowStore.phase == .breakTime {
                    activeFlowStore.pause(modelContext: context)
                }
            },
            finish: { [weak activeFlowStore] in
                guard let activeFlowStore else { return }
                let context = modelContainer.mainContext
                if activeFlowStore.isBreakPhase {
                    if activeFlowStore.phase == .paused {
                        activeFlowStore.resume(modelContext: context)
                    }
                    activeFlowStore.skipBreak(modelContext: context)
                    return
                }
                activeFlowStore.stop(modelContext: context)
                if activeFlowStore.phase == .awaitingResult {
                    activeFlowStore.completeResult(nil, modelContext: context)
                }
            },
            seekForward: { [weak activeFlowStore] in
                activeFlowStore?.seekForward(modelContext: modelContainer.mainContext)
            }
        )

        self.modelContainer = modelContainer
        self.liveActivityControl = liveActivityControl
        self.appDefaults = defaults
        self.isScreenshotMode = isScreenshotMode
        _activeFlowStore = StateObject(wrappedValue: activeFlowStore)
        _settings = StateObject(wrappedValue: AppSettings(defaults: defaults))
        _onboarding = StateObject(wrappedValue: OnboardingStore(defaults: defaults))
        if !isScreenshotMode {
            AppDependencyManager.shared.add(dependency: liveActivityControl)
        }
    }

    var body: some Scene {
        WindowGroup {
            IOSRootView()
                .defaultAppStorage(appDefaults)
                .onboardingJourney(store: onboarding)
                .persistenceIssuePresenter()
                .environmentObject(activeFlowStore)
                .environmentObject(settings)
                .environmentObject(onboarding)
                .environmentObject(connectors)
                .environment(\.calendar, settings.effectiveCalendar)
                .environment(\.appDayBoundary, settings.dayBoundary)
                .environment(\.locale, settings.effectiveLocale)
                .preferredColorScheme(settings.preferredColorScheme)
                .onAppear {
                    if !isScreenshotMode {
                        taskReminders.start(
                            modelContext: modelContainer.mainContext,
                            calendar: settings.effectiveCalendar
                        )
                    }
                    activeFlowStore.clearNotificationBadge()
                    activeFlowStore.beginSynchronization(
                        modelContext: modelContainer.mainContext
                    )
                }
                .task {
                    await PersistenceIssueCenter.shared.beginCloudKitMonitoring(
                        isEnabled: AppModelContainerFactory.usesCloudKitForCurrentProcess,
                        containerIdentifier: AppModelContainerFactory.cloudKitContainerIdentifier
                    )
                }
                .task(id: scenePhase) {
                    guard scenePhase == .active, !isScreenshotMode else { return }
                    await connectors.runForegroundSync(modelContext: modelContainer.mainContext)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        if !isScreenshotMode {
                            taskReminders.start(
                                modelContext: modelContainer.mainContext,
                                calendar: settings.effectiveCalendar
                            )
                        }
                        activeFlowStore.clearNotificationBadge()
                        activeFlowStore.beginSynchronization(
                            modelContext: modelContainer.mainContext
                        )
                    } else {
                        activeFlowStore.endSynchronization()
                    }
                }
                .background {
                    if !onboarding.isPresented, !isScreenshotMode {
                        ProductWidgetSnapshotSyncView()
                        ReviewRequestGate()
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}

private extension AppSettings {
    var preferredColorScheme: ColorScheme? {
        switch appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
