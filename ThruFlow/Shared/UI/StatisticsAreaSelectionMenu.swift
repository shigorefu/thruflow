import SwiftUI

#if os(iOS) || os(macOS)
struct StatisticsAreaSelectionMenu: View {
    @Binding var selectedAreaIDs: Set<UUID>
    let areas: [Area]
    var showsSelection = false

    private var selectionText: String {
        selectedAreaIDs.isEmpty
            ? String(localized: "すべて")
            : areas.filter { selectedAreaIDs.contains($0.id) }.map(\.name).joined(separator: ", ")
    }

    var body: some View {
        Menu {
            Button {
                selectedAreaIDs.removeAll()
            } label: {
                if selectedAreaIDs.isEmpty {
                    Label(String(localized: "すべて"), systemImage: "checkmark")
                } else {
                    Text(String(localized: "すべて"))
                }
            }
            if !areas.isEmpty {
                Divider()
                ForEach(areas) { area in
                    Toggle("\(area.symbolName) \(area.name)", isOn: Binding(
                        get: { selectedAreaIDs.contains(area.id) },
                        set: { selected in
                            if selected { selectedAreaIDs.insert(area.id) }
                            else { selectedAreaIDs.remove(area.id) }
                        }
                    ))
                }
            }
        } label: {
            if showsSelection {
                LabeledContent(String(localized: "方向フィルター"), value: selectionText)
            } else {
                Image(systemName: ProductSymbol.area)
                    .foregroundStyle(selectedAreaIDs.isEmpty ? Color.primary : Color.accentColor)
            }
        }
        #if os(iOS)
        .menuActionDismissBehavior(.disabled)
        #endif
        .accessibilityLabel(String(localized: "方向フィルター"))
        .accessibilityValue(selectionText)
        #if os(macOS)
        .menuStyle(.borderlessButton)
        .help(selectionText)
        #endif
    }
}
#endif
