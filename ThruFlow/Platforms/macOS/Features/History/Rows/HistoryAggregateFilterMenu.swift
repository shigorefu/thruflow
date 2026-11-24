#if os(macOS)
import SwiftData
import SwiftUI

struct HistoryAggregateFilterMenu: View {
    @Binding var visibleTypes: Set<AreaType>
    let neutralLabel: String

    var body: some View {
        Menu {
            filterToggle(neutralLabel, type: .neutral)
            filterToggle(String(localized: "習慣一覧"), type: .habit)
            filterToggle(String(localized: "ナイス"), type: .nice)
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel(String(localized: "表示内容"))
    }

    private func filterToggle(_ title: String, type: AreaType) -> some View {
        Toggle(
            title,
            isOn: Binding(
                get: { visibleTypes.contains(type) },
                set: { isVisible in
                    if isVisible {
                        visibleTypes.insert(type)
                    } else {
                        visibleTypes.remove(type)
                    }
                }
            )
        )
        .toggleStyle(.checkbox)
    }
}
#endif
