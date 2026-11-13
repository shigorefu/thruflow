#if os(iOS)
import SwiftUI

struct IOSHistorySeriesTimelineSheet: View {
    @Environment(\.dismiss) private var dismiss

    let block: HistoryCalendarSeriesBlock
    @State private var selectedItem: HistoryCalendarItem?

    var body: some View {
        NavigationStack {
            IOSHistoryChronologicalTimeline(
                items: block.items,
                gapInterval: nil,
                onSelect: { selectedItem = $0 }
            )
            .iosCenteredNavigationTitle(String(localized: "一連の集中記録"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "閉じる")) {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedItem) { item in
            IOSHistoryItemDetail(item: item)
                .presentationDetents(item.kind == .flow ? [.large] : [.medium])
        }
    }
}
#endif
