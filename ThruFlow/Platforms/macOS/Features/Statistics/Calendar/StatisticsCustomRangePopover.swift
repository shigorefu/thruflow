#if os(macOS)
import SwiftUI

struct StatisticsCustomRangePopover: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let maximumDate: Date
    let onCancel: () -> Void
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "期間を指定"))
                .font(.headline)

            VStack(spacing: 12) {
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
            .datePickerStyle(.field)

            HStack {
                Spacer()
                Button(String(localized: "キャンセル"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "完了"), action: onApply)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 300)
        .onChange(of: startDate) { _, newValue in
            if endDate < newValue {
                endDate = newValue
            }
        }
    }
}
#endif
