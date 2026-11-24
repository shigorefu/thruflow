#if os(macOS)
import SwiftData
import SwiftUI

struct HistoryCalendarPeriodWorkspace<Content: View, Inspector: View>: View {
    let sidebarHeader: AnyView
    @ViewBuilder let content: Content
    @ViewBuilder let inspector: Inspector

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 900 {
                HStack(spacing: 0) {
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    VStack(spacing: 0) {
                        sidebarHeader

                        Divider()

                        inspector
                            .padding(16)
                        Spacer(minLength: 0)
                    }
                    .frame(width: min(390, max(310, geometry.size.width * 0.30)))
                    .background(Color.secondary.opacity(0.035))
                }
            } else {
                VStack(spacing: 0) {
                    sidebarHeader
                    Divider()
                    content
                }
            }
        }
    }
}
#endif
