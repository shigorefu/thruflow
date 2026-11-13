#if os(macOS)
import AppKit
import SwiftUI

struct HistoryRecordEditorView: View {
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    let item: HistoryCalendarItem
    let onClose: () -> Void

    @ViewBuilder
    var body: some View {
        switch item.kind {
        case .flow:
            if let session = item.session {
                FlowHistoryInspectorView(
                    session: session,
                    segment: item.flowSegment,
                    onClose: onClose
                )
            }
        case .rest:
            if let flowBreak = item.flowBreak {
                HistoryBreakEditorView(flowBreak: flowBreak, onClose: onClose)
                    .environmentObject(activeFlowStore)
            }
        }
    }
}
#endif
