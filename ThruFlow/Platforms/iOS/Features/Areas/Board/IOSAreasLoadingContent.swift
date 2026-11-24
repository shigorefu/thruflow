#if os(iOS)
import SwiftUI

struct IOSAreasLoadingContent: View {
    let loadFailed: Bool

    var body: some View {
        if loadFailed {
            ContentUnavailableView(
                String(localized: "データを読み込めませんでした。"),
                systemImage: "exclamationmark.triangle"
            )
        } else {
            FeatureLoadingIndicator()
        }
    }
}
#endif
