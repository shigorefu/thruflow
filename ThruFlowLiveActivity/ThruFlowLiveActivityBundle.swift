import SwiftUI
import WidgetKit

@main
struct ThruFlowLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        FlowTimerWidget()
        TasksWidget()
        FlowDotsWidget()
#if os(iOS)
        FlowLiveActivityWidget()
#endif
    }
}
