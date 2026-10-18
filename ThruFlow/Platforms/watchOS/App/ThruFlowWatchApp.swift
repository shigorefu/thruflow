import SwiftData
import SwiftUI

@main
struct ThruFlowWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var activeFlowStore = ActiveFlowStore()
    @StateObject private var settings = AppSettings()
    @StateObject private var taskReminders = TaskReminderScheduler()

    private let modelContainer = AppModelContainerFactory.make()

    var body: some Scene {
        WindowGroup {
            WatchFlowDashboardView()
                .persistenceIssuePresenter()
                .environmentObject(activeFlowStore)
                .environment(\.calendar, settings.effectiveCalendar)
                .environment(\.appDayBoundary, settings.dayBoundary)
                .environment(\.locale, settings.effectiveLocale)
                .onAppear {
                    taskReminders.start(
                        modelContext: modelContainer.mainContext,
                        calendar: settings.effectiveCalendar
                    )
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
                        taskReminders.start(
                            modelContext: modelContainer.mainContext,
                            calendar: settings.effectiveCalendar
                        )
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
