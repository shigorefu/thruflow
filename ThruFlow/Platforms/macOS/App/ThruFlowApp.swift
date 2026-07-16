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
    @NSApplicationDelegateAdaptor(MacOSAppDelegate.self) private var appDelegate

    private let sharedModelContainer = AppModelContainerFactory.make()

    var body: some Scene {
        WindowGroup {
            MacOSRootView()
                .environmentObject(activeFlowStore)
        }
        .modelContainer(sharedModelContainer)

        MenuBarExtra {
            FlowMiniPlayerView(style: .dashboard)
                .environmentObject(activeFlowStore)
                .frame(width: 310, height: 410)
                .padding(16)
        } label: {
            MacOSFlowMenuBarLabel()
                .environmentObject(activeFlowStore)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(sharedModelContainer)
    }
}
