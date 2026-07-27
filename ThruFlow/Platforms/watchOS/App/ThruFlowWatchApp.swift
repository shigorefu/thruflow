import SwiftData
import SwiftUI

@main
struct ThruFlowWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var activeFlowStore = ActiveFlowStore()
    @StateObject private var settings = AppSettings()

    private let modelContainer = AppModelContainerFactory.make()

    var body: some Scene {
        WindowGroup {
            WatchFlowDashboardView()
                .environmentObject(activeFlowStore)
                .environment(\.calendar, settings.effectiveCalendar)
                .environment(\.appDayBoundary, settings.dayBoundary)
                .environment(\.locale, settings.effectiveLocale)
                .onAppear {
                    activeFlowStore.clearNotificationBadge()
                    activeFlowStore.beginSynchronization(
                        modelContext: modelContainer.mainContext
                    )
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
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
