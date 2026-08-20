//
//  ThruFlowApp.swift
//  ThruFlow
//
//  Created by エドワード on 2026/07/08.
//

import AppKit
import SwiftData
import SwiftUI

enum MacOSWindowID {
    static let main = "main"
}

@main
struct ThruFlowApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var activeFlowStore = ActiveFlowStore(
        liveActivities: MacOSFlowWidgetService()
    )
    @StateObject private var settings = AppSettings()
    @StateObject private var onboarding = OnboardingStore()
    @StateObject private var supportPurchaseStore = SupportPurchaseStore()
    @NSApplicationDelegateAdaptor(MacOSAppDelegate.self) private var appDelegate

    private let sharedModelContainer = AppModelContainerFactory.make()

    var body: some Scene {
        Window("ThruFlow", id: MacOSWindowID.main) {
            MacOSRootView()
                .onboardingJourney(store: onboarding)
                .environmentObject(activeFlowStore)
                .environmentObject(onboarding)
                .environmentObject(supportPurchaseStore)
                .appSettingsEnvironment(settings)
                .onAppear {
                    activeFlowStore.clearNotificationBadge()
                    activeFlowStore.beginSynchronization(
                        modelContext: sharedModelContainer.mainContext
                    )
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        activeFlowStore.clearNotificationBadge()
                        activeFlowStore.beginSynchronization(
                            modelContext: sharedModelContainer.mainContext
                        )
                    } else {
                        activeFlowStore.endSynchronization()
                    }
                }
                .background {
                    if !onboarding.isPresented {
                        ProductWidgetSnapshotSyncView()
                        ReviewRequestGate()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1_280, height: 800)

        MenuBarExtra {
            FlowMiniPlayerView(style: .dashboard)
                .environmentObject(activeFlowStore)
                .appSettingsEnvironment(settings)
                .frame(width: 310, height: 410)
                .padding(16)
        } label: {
            MacOSFlowMenuBarLabel()
                .environmentObject(activeFlowStore)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(sharedModelContainer)

        Settings {
            MacOSSettingsView()
                .environmentObject(activeFlowStore)
                .environmentObject(onboarding)
                .environmentObject(supportPurchaseStore)
                .appSettingsEnvironment(settings)
        }
        .modelContainer(sharedModelContainer)
    }
}

private extension View {
    func appSettingsEnvironment(_ settings: AppSettings) -> some View {
        environmentObject(settings)
            .environment(\.calendar, settings.effectiveCalendar)
            .environment(\.appDayBoundary, settings.dayBoundary)
            .environment(\.locale, settings.effectiveLocale)
            .preferredColorScheme(settings.colorScheme)
    }
}

private extension AppSettings {
    var colorScheme: ColorScheme? {
        switch appearance {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}
