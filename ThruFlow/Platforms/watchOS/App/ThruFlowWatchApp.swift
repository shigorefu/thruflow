import SwiftData
import SwiftUI

@main
struct ThruFlowWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var activeFlowStore: ActiveFlowStore
    @StateObject private var settings: AppSettings
    @StateObject private var taskReminders = TaskReminderScheduler()

    private let modelContainer: ModelContainer
    private let appDefaults: UserDefaults
    private let isScreenshotMode: Bool

    init() {
        let isScreenshotMode = ScreenshotMode.isEnabled()
        let defaults = ScreenshotMode.configuredDefaults()
        self.isScreenshotMode = isScreenshotMode
        self.appDefaults = defaults
        modelContainer = AppModelContainerFactory.make()
        _activeFlowStore = StateObject(wrappedValue: ActiveFlowStore(
            defaults: defaults,
            notifications: isScreenshotMode ? ScreenshotFlowNotificationService() : nil,
            liveActivities: isScreenshotMode ? NoopLiveActivityService() : nil
        ))
        _settings = StateObject(wrappedValue: AppSettings(defaults: defaults))
    }

    var body: some Scene {
        WindowGroup {
            WatchFlowDashboardView()
                .defaultAppStorage(appDefaults)
                .persistenceIssuePresenter()
                .environmentObject(activeFlowStore)
                .environment(\.calendar, settings.effectiveCalendar)
                .environment(\.appDayBoundary, settings.dayBoundary)
                .environment(\.locale, settings.effectiveLocale)
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
        }
        .modelContainer(modelContainer)
    }
}
