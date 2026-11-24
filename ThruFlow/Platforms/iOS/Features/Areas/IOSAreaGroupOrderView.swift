#if os(iOS)
import SwiftUI

struct IOSAreaGroupOrderView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var orderRawValue: String

    @State private var order: [AreaType]

    init(orderRawValue: Binding<String>) {
        _orderRawValue = orderRawValue
        _order = State(initialValue: AreaGroupOrder.decode(orderRawValue.wrappedValue))
    }

    var body: some View {
        List {
            ForEach(order) { type in
                Label(type.displayName, systemImage: type.iosGroupSystemImage)
            }
            .onMove { offsets, destination in
                order.move(fromOffsets: offsets, toOffset: destination)
                orderRawValue = AreaGroupOrder.encode(order)
            }
        }
        .environment(\.editMode, .constant(.active))
        .iosCenteredNavigationTitle(String(localized: "グループを並び替え"))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "完了")) { dismiss() }
            }
        }
    }
}
#endif
