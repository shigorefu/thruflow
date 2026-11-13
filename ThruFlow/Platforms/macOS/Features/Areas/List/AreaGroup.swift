#if os(macOS)
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct AreaGroup: Identifiable {
    let type: AreaType
    let areas: [Area]

    var id: String { type.rawValue }

    static func order(from rawValue: String) -> [AreaType] {
        AreaGroupOrder.decode(rawValue)
    }

    var title: String {
        switch type {
        case .neutral: String(localized: "通常")
        case .habit: String(localized: "習慣一覧")
        case .nice: String(localized: "ナイス")
        }
    }

    var systemImage: String {
        switch type {
        case .neutral: "checklist"
        case .habit: "repeat"
        case .nice: "sparkles"
        }
    }

    static func groups(for areas: [Area], order: [AreaType]) -> [AreaGroup] {
        order.map { type in
            AreaGroup(
                type: type,
                areas: areas.filter { $0.type == type }
            )
        }
    }
}

struct AreaSectionHeader: View {
    let group: AreaGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: group.systemImage)
                    .font(.caption.weight(.semibold))
                    .frame(width: 14)
                    .accessibilityHidden(true)

                Text(group.title)
                    .font(.caption.weight(.semibold))

                Text("\(group.areas.count)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())

                Spacer(minLength: 0)

                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(String(localized: "グループを並び替え"))
            }

            Text(group.type.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .textCase(nil)
    }
}
#endif
