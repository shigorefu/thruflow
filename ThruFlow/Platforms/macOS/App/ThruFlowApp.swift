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
    @StateObject private var activeFlowStore: ActiveFlowStore
    @StateObject private var settings: AppSettings
    @StateObject private var onboarding: OnboardingStore
    @StateObject private var connectors: ConnectorStore
    @StateObject private var taskReminders = TaskReminderScheduler()
    @NSApplicationDelegateAdaptor(MacOSAppDelegate.self) private var appDelegate

    private let sharedModelContainer: ModelContainer
    private let appDefaults: UserDefaults

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let isScreenshotMode = ScreenshotMode.isEnabled(arguments: arguments)
        let defaults = ScreenshotMode.configuredDefaults(arguments: arguments)
        let liveActivities: any LiveActivityService = isScreenshotMode
            ? NoopLiveActivityService()
            : MacOSFlowWidgetService()

        appDefaults = defaults
        sharedModelContainer = AppModelContainerFactory.make()
        _activeFlowStore = StateObject(wrappedValue: ActiveFlowStore(
            defaults: defaults,
            notifications: isScreenshotMode ? ScreenshotFlowNotificationService() : nil,
            liveActivities: liveActivities
        ))
        _settings = StateObject(wrappedValue: AppSettings(defaults: defaults))
        _onboarding = StateObject(wrappedValue: OnboardingStore(defaults: defaults, arguments: arguments))
        _connectors = StateObject(wrappedValue: ConnectorStore(defaults: defaults))
    }

    var body: some Scene {
        WindowGroup("ThruFlow", id: MacOSWindowID.main) {
            MacOSRootView()
                .onboardingJourney(store: onboarding)
                .persistenceIssuePresenter()
                .environmentObject(activeFlowStore)
                .environmentObject(onboarding)
                .environmentObject(connectors)
                .appSettingsEnvironment(settings)
                .defaultAppStorage(appDefaults)
                .onAppear {
                    guard !ScreenshotMode.isEnabled() else { return }
                    taskReminders.start(
                        modelContext: sharedModelContainer.mainContext,
                        calendar: settings.effectiveCalendar
                    )
                    activeFlowStore.clearNotificationBadge()
                    activeFlowStore.beginSynchronization(
                        modelContext: sharedModelContainer.mainContext
                    )
                }
                .task {
                    await PersistenceIssueCenter.shared.beginCloudKitMonitoring(
                        isEnabled: AppModelContainerFactory.usesCloudKitForCurrentProcess,
                        containerIdentifier: AppModelContainerFactory.cloudKitContainerIdentifier
                    )
                }
                .task(id: scenePhase) {
                    guard scenePhase == .active, !ScreenshotMode.isEnabled() else { return }
                    taskReminders.start(
                        modelContext: sharedModelContainer.mainContext,
                        calendar: settings.effectiveCalendar
                    )
                    await connectors.runForegroundSync(modelContext: sharedModelContainer.mainContext)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    activeFlowStore.flushPendingModeChange()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard !ScreenshotMode.isEnabled() else { return }
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
                    if ScreenshotMode.isEnabled() {
                        ScreenshotWindowActivationAnchor()
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    if !onboarding.isPresented, !ScreenshotMode.isEnabled() {
                        ProductWidgetSnapshotSyncView()
                        ReviewRequestGate()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1_280, height: 800)

        MenuBarExtra {
            FlowMiniPlayerView(style: .dashboard, taskSuggestionsBelow: true)
                .environmentObject(activeFlowStore)
                .appSettingsEnvironment(settings)
                .defaultAppStorage(appDefaults)
                .frame(width: 310, height: 410)
                .padding(16)
                .onAppear {
                    guard !ScreenshotMode.isEnabled() else { return }
                    taskReminders.start(
                        modelContext: sharedModelContainer.mainContext,
                        calendar: settings.effectiveCalendar
                    )
                }
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
                .appSettingsEnvironment(settings)
                .defaultAppStorage(appDefaults)
        }
        .modelContainer(sharedModelContainer)
    }
}

/// Activate only the screenshot window after AppKit attaches its native host.
private struct ScreenshotWindowActivationAnchor: NSViewRepresentable {
    func makeNSView(context: Context) -> ScreenshotWindowActivationView {
        ScreenshotWindowActivationView()
    }

    func updateNSView(_ nsView: ScreenshotWindowActivationView, context: Context) {}
}

private final class ScreenshotWindowActivationView: NSView {
    private weak var activatedWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard ScreenshotMode.isEnabled(), let window, activatedWindow !== window else { return }
        activatedWindow = window
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window, self.window === window, ScreenshotMode.isEnabled() else { return }
            NSApplication.shared.activate()
            window.makeKeyAndOrderFront(nil)
        }
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
