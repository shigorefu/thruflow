#if os(iOS)
import SwiftUI

struct IOSStatisticsAnchorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var date: Date
    let maximumDate: Date
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            DatePicker(
                String(localized: "期間を指定"),
                selection: $date,
                in: ...maximumDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .iosCenteredNavigationTitle(String(localized: "期間を指定"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "キャンセル")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "完了"), action: onApply)
                }
            }
        }
    }
}

struct IOSStatisticsCustomRangeSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var startDate: Date
    @Binding var endDate: Date
    let maximumDate: Date
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(
                    String(localized: "開始日"),
                    selection: $startDate,
                    in: ...maximumDate,
                    displayedComponents: .date
                )
                DatePicker(
                    String(localized: "終了日"),
                    selection: $endDate,
                    in: ...maximumDate,
                    displayedComponents: .date
                )
            }
            .iosCenteredNavigationTitle(String(localized: "期間を指定"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "キャンセル")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "完了"), action: onApply)
                }
            }
            .onChange(of: startDate) { _, newValue in
                if endDate < newValue {
                    endDate = newValue
                }
            }
        }
    }
}
#endif
