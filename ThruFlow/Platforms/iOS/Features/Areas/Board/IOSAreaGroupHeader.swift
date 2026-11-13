#if os(iOS)
import SwiftUI

struct IOSAreaGroupHeader: View {
    let type: AreaType

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(type.displayName, systemImage: type.iosGroupSystemImage)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text(type.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension AreaType {
    var iosGroupSystemImage: String {
        switch self {
        case .neutral: "checklist"
        case .habit: "repeat"
        case .nice: "sparkles"
        }
    }
}
#endif
