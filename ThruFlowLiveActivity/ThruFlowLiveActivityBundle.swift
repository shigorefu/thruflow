import SwiftUI
import WidgetKit

@main
struct ThruFlowLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        FlowTimerWidget()
        TasksWidget()
        FlowDotsWidget()
        FlowLiveActivityWidget()
    }
}
