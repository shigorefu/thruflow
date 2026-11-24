#if os(macOS) || os(iOS)
import SwiftUI

struct HabitRestDaysPicker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var value: Int
    let validationErrors: [AreaValidationError]

    private var restErrors: [AreaValidationError] {
        validationErrors.filter(\.isRestScheduleError)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(String(localized: "休息日"), selection: $value) {
                Text(String(localized: "なし")).tag(0)
                ForEach(1...6, id: \.self) { days in
                    Text(String(localized: "\(days)日")).tag(days)
                }
            }
            .pickerStyle(.menu)
            ForEach(restErrors, id: \.self) { error in
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
            Text(String(localized: "習慣を完了した後、指定した日数は次のタスクを作成しません。"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: restErrors)
    }
}

/// Errors owned by the inline rest control rather than the form footer.
extension AreaValidationError {
    var isRestScheduleError: Bool {
        self == .invalidMinimumRestDays || self == .impossibleRestSchedule
    }
}
#endif
