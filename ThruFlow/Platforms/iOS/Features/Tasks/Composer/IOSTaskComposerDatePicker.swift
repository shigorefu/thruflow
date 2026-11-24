#if os(iOS)
import SwiftUI

struct IOSTaskComposerDatePicker: View {
    @Binding var date: Date
    let onCancel: () -> Void
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            DatePicker(
                String(localized: "日付"),
                selection: $date,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .iosCenteredNavigationTitle(String(localized: "日付を選択"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "キャンセル")) { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "完了")) {
                        onApply()
                    }
                }
            }
        }
    }
}
#endif
