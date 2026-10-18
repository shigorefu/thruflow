import SwiftUI
import UserNotifications

/// Draft-only controls. Permission is requested only after an explicit user opt-in.
struct TaskTimingControls: View {
    @Environment(\.calendar) private var calendar
    let scheduledDate: Date?
    @Binding var timeMinutes: Int?
    @Binding var reminderEnabled: Bool
    @State private var isRequestingPermission = false
    @State private var permissionDenied = false
    @State private var needsDevicePermission = false
    @State private var permissionRequest: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(String(localized: "時刻を指定"), isOn: hasTime)
                .disabled(scheduledDate == nil)
            if scheduledDate == nil {
                Text(String(localized: "日付を選ぶと時刻を指定できます。"))
                    .font(.caption).foregroundStyle(.secondary)
            } else if timeMinutes != nil {
                DatePicker(String(localized: "時刻"), selection: time, displayedComponents: .hourAndMinute)
                Toggle(String(localized: "この時刻に通知"), isOn: reminder)
                    .disabled(isRequestingPermission)
                if needsDevicePermission {
                    Button(String(localized: "この端末で通知を許可")) { requestPermission() }
                        .disabled(isRequestingPermission)
                }
                if permissionDenied {
                    Text(String(localized: "通知が許可されていません。システム設定で通知を許可してください。"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: scheduledDate) { _, date in
            if date == nil { cancelPermissionRequest(); timeMinutes = nil; reminderEnabled = false }
        }
        .onDisappear { cancelPermissionRequest() }
        .task {
            guard reminderEnabled else { return }
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            permissionDenied = status == .denied
            needsDevicePermission = status == .notDetermined
        }
    }

    private func cancelPermissionRequest() {
        permissionRequest?.cancel()
        permissionRequest = nil
        isRequestingPermission = false
    }

    private var hasTime: Binding<Bool> {
        Binding(get: { timeMinutes != nil }, set: { enabled in
            if enabled {
                let parts = calendar.dateComponents([.hour, .minute], from: .now)
                timeMinutes = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
            } else {
                cancelPermissionRequest()
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

    private var reminder: Binding<Bool> {
        Binding(get: { reminderEnabled }, set: { enabled in
            guard enabled else {
                cancelPermissionRequest()
                reminderEnabled = false
                needsDevicePermission = false
                return
            }
            requestPermission()
        })
    }

    private func requestPermission() {
        guard !isRequestingPermission else { return }
        let wasEnabled = reminderEnabled
        isRequestingPermission = true
        permissionRequest = Task { @MainActor in
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])) == true
            guard !Task.isCancelled else { return }
            isRequestingPermission = false
            permissionDenied = !granted
            needsDevicePermission = false
            // Denial on another device must not turn off an already-synced reminder.
            reminderEnabled = (wasEnabled || granted) && scheduledDate != nil && timeMinutes != nil
        }
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
