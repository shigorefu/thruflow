import SwiftUI

/// Sidebar label; native popup menus use a plain Beta suffix instead.
struct ConnectorNavigationLabel: View {
    var body: some View {
        HStack(spacing: 8) {
            Label(String(localized: "コネクタ"), systemImage: "puzzlepiece.extension")
            Text(verbatim: "Beta")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
        }
    }
}
