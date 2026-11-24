import SwiftUI

private struct AppDayBoundaryEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppDayBoundary.midnight
}

extension EnvironmentValues {
    var appDayBoundary: AppDayBoundary {
        get { self[AppDayBoundaryEnvironmentKey.self] }
        set { self[AppDayBoundaryEnvironmentKey.self] = newValue }
    }
}
