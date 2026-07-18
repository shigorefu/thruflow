import SwiftData
import SwiftUI

@main
struct ThruFlowiOSApp: App {
    @StateObject private var activeFlowStore = ActiveFlowStore()
    @StateObject private var settings = AppSettings()

    private let modelContainer = AppModelContainerFactory.make()

    var body: some Scene {
        WindowGroup {
            IOSRootView()
                .environmentObject(activeFlowStore)
                .environmentObject(settings)
                .environment(\.calendar, settings.effectiveCalendar)
                .environment(\.locale, settings.effectiveLocale)
                .preferredColorScheme(settings.preferredColorScheme)
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
