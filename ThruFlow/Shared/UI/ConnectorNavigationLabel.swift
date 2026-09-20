import SwiftUI

/// Navigation stays neutral; each provider row carries its own Beta badge.
struct ConnectorNavigationLabel: View {
    var body: some View {
        Label(String(localized: "コネクタ"), systemImage: "puzzlepiece.extension")
    }
}

struct ConnectorBetaBadge: View {
    var body: some View {
        Text(verbatim: "Beta")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
            .fixedSize()
    }
}
