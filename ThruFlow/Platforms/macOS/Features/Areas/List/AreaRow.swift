#if os(macOS)
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct AreaRow: View {
    let area: Area

    var body: some View {
        HStack(spacing: 12) {
            Text(area.symbolName)
                .font(.title2)
                .frame(width: 36, height: 36)
                .background(Color(hex: area.colorHex).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
                .anchorPreference(key: AreaProjectTreeAnchors.self, value: .bounds) {
                    [.area(area.id): $0]
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(area.name)
                    .font(.headline)

                if let summary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: area.isArchived ? "archivebox" : "line.3.horizontal")
                .foregroundStyle(.secondary)
                .accessibilityLabel(area.isArchived ? String(localized: "アーカイブ済み") : String(localized: "並び替え"))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
    }

    private var summary: String? {
        guard
            let target = area.goalTarget,
            let period = area.goalPeriod,
            let unit = area.goalUnit
        else {
            return nil
        }

        return "\(target) \(unit.displayName.lowercased()) \(period.displayName.lowercased())"
    }

}
#endif
