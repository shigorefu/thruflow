import SwiftUI

enum IOSAppRoute: Hashable {
    case tasks
    case history
    case directions
    case statistics
    case settings
}

struct IOSRootView: View {
    @State private var path: [IOSAppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            IOSFlowView(open: open)
                .navigationDestination(for: IOSAppRoute.self) { route in
                    destination(for: route)
                }
        }
    }

    @ViewBuilder
    private func destination(for route: IOSAppRoute) -> some View {
        switch route {
        case .tasks:
            IOSTasksView()
        case .history:
            IOSHistoryView()
        case .directions:
            IOSDirectionsView()
        case .statistics:
            IOSStatisticsView()
        case .settings:
            IOSSettingsView()
        }
    }

    private func open(_ route: IOSAppRoute) {
        path.append(route)
    }
}
