import SwiftUI

struct IOSRootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                IOSFlowView()
            }
            .tabItem {
                Label(String(localized: "Flow"), systemImage: "waveform.path")
            }

            NavigationStack {
                IOSTasksView()
            }
            .tabItem {
                Label(String(localized: "タスク"), systemImage: "checklist")
            }

            NavigationStack {
                IOSDirectionsView()
            }
            .tabItem {
                Label(String(localized: "方向"), systemImage: "point.3.connected.trianglepath.dotted")
            }

            NavigationStack {
                IOSSettingsView()
            }
            .tabItem {
                Label(String(localized: "設定"), systemImage: "gearshape")
            }
        }
    }
}
