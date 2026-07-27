import AppIntents
import SwiftData
import SwiftUI

@main
struct ThruFlowiOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var activeFlowStore: ActiveFlowStore
    @StateObject private var settings = AppSettings()

    private let modelContainer: ModelContainer
    private let liveActivityControl: FlowLiveActivityControl

    init() {
        let modelContainer = AppModelContainerFactory.make()
        let activeFlowStore = ActiveFlowStore(
            liveActivities: IOSFlowLiveActivityService()
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
        _activeFlowStore = StateObject(wrappedValue: activeFlowStore)
        AppDependencyManager.shared.add(dependency: liveActivityControl)
    }

    var body: some Scene {
        WindowGroup {
            IOSRootView()
                .environmentObject(activeFlowStore)
                .environmentObject(settings)
                .environment(\.calendar, settings.effectiveCalendar)
                .environment(\.appDayBoundary, settings.dayBoundary)
                .environment(\.locale, settings.effectiveLocale)
                .preferredColorScheme(settings.preferredColorScheme)
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
                .background {
                    IOSProductWidgetSnapshotSyncView()
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
