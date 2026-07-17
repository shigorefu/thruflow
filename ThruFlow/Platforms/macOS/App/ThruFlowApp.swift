//
//  ThruFlowApp.swift
//  ThruFlow
//
//  Created by エドワード on 2026/07/08.
//

import AppKit
import SwiftData
import SwiftUI

@main
struct ThruFlowApp: App {
    @StateObject private var activeFlowStore = ActiveFlowStore()
    @StateObject private var settings = AppSettings()
    @NSApplicationDelegateAdaptor(MacOSAppDelegate.self) private var appDelegate

    private let sharedModelContainer = AppModelContainerFactory.make()

    var body: some Scene {
        WindowGroup {
            MacOSRootView()
                .environmentObject(activeFlowStore)
                .appSettingsEnvironment(settings)
        }
        .modelContainer(sharedModelContainer)

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
                .appSettingsEnvironment(settings)
        }
    }
}

private extension View {
    func appSettingsEnvironment(_ settings: AppSettings) -> some View {
        environmentObject(settings)
            .environment(\.calendar, settings.effectiveCalendar)
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
