#if os(macOS) || os(iOS)
import SwiftUI

struct ConnectorMappingColumnHeaders: View {
    let destination: String

    var body: some View {
        HStack {
            Text(String(localized: "分野"))
            Spacer()
            Text(destination)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityAddTraits(.isHeader)
    }
}

struct ConnectorAreaMappingRow<Selection: View>: View {
    let area: Area
    @ViewBuilder var selection: Selection

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(area.symbolName) \(area.name)")
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            selection
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
#endif
