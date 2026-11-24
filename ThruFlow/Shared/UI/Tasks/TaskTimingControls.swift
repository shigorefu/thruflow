import SwiftUI
import UserNotifications

/// Draft-only controls; the owning form applies taskTimingDefaults.
struct TaskTimingControls: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let scheduledDate: Date?
    @Binding var timeMinutes: Int?
    @Binding var reminderEnabled: Bool
    var showsTrailingTimeSwitch = false
    var animatesVisibility = false
    @State private var permissionDenied = false
    @State private var needsDevicePermission = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsTrailingTimeSwitch {
                HStack(spacing: 10) {
                    Label(String(localized: "時刻を指定"), systemImage: "clock")
                        .font(.subheadline.weight(.medium))
                        .accessibilityHidden(true)
                    Spacer(minLength: 8)
#if os(macOS)
                    if scheduledDate != nil && timeMinutes != nil {
                        DatePicker(String(localized: "時刻"), selection: time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.field)
                            .labelsHidden()
                            .fixedSize()
                            .transition(.opacity)
                    }
#endif
                    Toggle(String(localized: "時刻を指定"), isOn: hasTime)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                .disabled(scheduledDate == nil)
            } else {
                Toggle(String(localized: "時刻を指定"), isOn: hasTime)
                    .disabled(scheduledDate == nil)
            }
            if scheduledDate == nil {
                Text(String(localized: "日付を選ぶと時刻を指定できます。"))
                    .font(.caption).foregroundStyle(.secondary)
                    .transition(.opacity)
            } else if timeMinutes != nil {
#if os(macOS)
                if !showsTrailingTimeSwitch {
                    DatePicker(String(localized: "時刻"), selection: time, displayedComponents: .hourAndMinute)
                        .transition(.opacity)
                }
#else
                DatePicker(String(localized: "時刻"), selection: time, displayedComponents: .hourAndMinute)
                    .transition(.opacity)
#endif
                Toggle(String(localized: "この時刻に通知"), isOn: $reminderEnabled)
                    .transition(.opacity)
                if needsDevicePermission {
                    Button(String(localized: "この端末で通知を許可")) {
                        TaskReminderAuthorization.requestForUserAction()
                    }
                    .transition(.opacity)
                }
                if permissionDenied {
                    Text(String(localized: "通知が許可されていません。システム設定で通知を許可してください。"))
                        .font(.caption).foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
        }
        .animation(visibilityAnimation, value: animatesVisibility && scheduledDate != nil)
        .animation(visibilityAnimation, value: animatesVisibility && showsTimeDetails)
        .animation(visibilityAnimation, value: animatesVisibility && showsTimeDetails && needsDevicePermission)
        .animation(visibilityAnimation, value: animatesVisibility && showsTimeDetails && permissionDenied)
        .onChange(of: scheduledDate) { _, date in
            if date == nil { timeMinutes = nil; reminderEnabled = false }
        }
        .task(id: reminderEnabled) { await refreshAuthorization() }
        .onReceive(NotificationCenter.default.publisher(for: TaskReminderAuthorization.didChange)) { _ in
            Task { await refreshAuthorization() }
        }
    }

    private var visibilityAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.18)
    }

    private var showsTimeDetails: Bool { scheduledDate != nil && timeMinutes != nil }

    private func refreshAuthorization() async {
        guard reminderEnabled else {
            permissionDenied = false
            needsDevicePermission = false
            return
        }
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        permissionDenied = status == .denied
        needsDevicePermission = status == .notDetermined
    }

    private var hasTime: Binding<Bool> {
        Binding(get: { timeMinutes != nil }, set: { enabled in
            if enabled {
                let parts = calendar.dateComponents([.hour, .minute], from: .now)
                timeMinutes = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
            } else {
                timeMinutes = nil
                reminderEnabled = false
                permissionDenied = false
                needsDevicePermission = false
            }
        })
    }

    private var time: Binding<Date> {
        Binding(get: {
            TaskTimeFormatting.date(on: scheduledDate ?? .now, minutes: timeMinutes ?? 540,
                                    calendar: calendar) ?? scheduledDate ?? .now
        }, set: { date in
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            timeMinutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        })
    }

}

private struct TaskTimingDefaultsModifier: ViewModifier {
    @Binding var timeMinutes: Int?
    @Binding var reminderEnabled: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: timeMinutes) { old, new in
                reminderEnabled = TaskTimingDefaults.reminderEnabled(
                    previousMinutes: old, newMinutes: new, current: reminderEnabled
                )
            }
            .onChange(of: reminderEnabled) { _, enabled in
                if enabled && timeMinutes != nil { TaskReminderAuthorization.requestForUserAction() }
            }
    }
}

extension View {
    func taskTimingDefaults(timeMinutes: Binding<Int?>, reminderEnabled: Binding<Bool>) -> some View {
        modifier(TaskTimingDefaultsModifier(timeMinutes: timeMinutes, reminderEnabled: reminderEnabled))
    }
}

struct TaskTimeLabel: View {
    let minutes: Int
    var reminderEnabled = false

    var body: some View {
        Label(TaskTimeFormatting.text(minutes: minutes), systemImage: reminderEnabled ? "bell" : "clock")
            .font(.caption).monospacedDigit().foregroundStyle(.secondary)
    }
}
