#if os(macOS)
import SwiftData
import SwiftUI

struct HistoryVisibilityMenu: View {
    @Binding var visibleKinds: Set<HistoryCalendarItemKind>

    var body: some View {
        Menu {
            filterToggle(String(localized: "集中記録"), symbol: "waveform.path", kinds: [.flow])
            filterToggle(String(localized: "休憩"), symbol: "cup.and.saucer", kinds: [.rest])
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel(String(localized: "表示内容"))
    }

    private func filterToggle(_ title: String, symbol: String, kinds: Set<HistoryCalendarItemKind>) -> some View {
        Toggle(isOn: Binding(
            get: { kinds.isSubset(of: visibleKinds) },
            set: { isVisible in
                if isVisible { visibleKinds.formUnion(kinds) } else { visibleKinds.subtract(kinds) }
            }
        )) {
            Label(title, systemImage: symbol)
        }
        .toggleStyle(.checkbox)
    }

}
#endif
