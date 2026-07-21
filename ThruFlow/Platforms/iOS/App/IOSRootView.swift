import SwiftUI

enum IOSAppRoute: Hashable, CaseIterable, Identifiable {
    case flow
    case tasks
    case history
    case directions
    case statistics
    case settings

    var id: String { String(describing: self) }

    var title: String {
        switch self {
        case .flow: String(localized: "Flow")
        case .tasks: String(localized: "タスク")
        case .history: String(localized: "履歴")
        case .directions: String(localized: "方向")
        case .statistics: String(localized: "統計")
        case .settings: String(localized: "設定")
        }
    }

    var systemImage: String {
        switch self {
        case .flow: "waveform.path"
        case .tasks: "checklist"
        case .history: "clock.arrow.circlepath"
        case .directions: "point.3.connected.trianglepath.dotted"
        case .statistics: "chart.bar.xaxis"
        case .settings: "gearshape"
        }
    }

    static var tabs: [IOSAppRoute] {
        [.flow, .tasks, .history, .directions, .statistics]
    }
}

struct IOSRootView: View {
    @State private var selection = IOSAppRoute.flow
    @State private var showsSettings = false

    var body: some View {
        NavigationStack {
            destination(for: selection)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selection != .tasks {
                IOSBottomNavigation(selection: $selection)
            }
        }
        .sheet(isPresented: $showsSettings) {
            NavigationStack {
                IOSSettingsView()
            }
        }
    }

    @ViewBuilder
    private func destination(for route: IOSAppRoute) -> some View {
        switch route {
        case .flow:
            IOSFlowView(open: open)
        case .tasks:
            IOSTasksView { selection = .flow }
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
        if route == .settings {
            showsSettings = true
        } else {
            selection = route
        }
    }
}

private struct IOSBottomNavigation: View {
    @Binding var selection: IOSAppRoute

    var body: some View {
        HStack(spacing: 2) {
            ForEach(IOSAppRoute.tabs) { route in
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        selection = route
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: route.systemImage)
                            .font(.body.weight(.semibold))
                        Text(route.title)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundStyle(selection == route ? Color.accentColor : Color.secondary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background {
                        if selection == route {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.accentColor.opacity(0.13))
                                .matchedGeometryEffect(id: "selected-tab", in: tabNamespace)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == route ? .isSelected : [])
            }
        }
        .padding(5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.primary.opacity(0.09))
        }
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        .padding(.horizontal, 10)
        .padding(.bottom, 5)
    }

    @Namespace private var tabNamespace
}
