//
//  FlowNotificationService.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import Foundation
import UserNotifications

protocol FlowNotificationService {
    func requestAuthorizationIfNeeded()
    func scheduleFocusFinished(mode: FlowMode, focusedSeconds: Int, fireDate: Date)
    func scheduleBreakFinished(fireDate: Date)
    func scheduleRunningTooLong(phase: FlowNotificationPhase, fireDate: Date)
    func cancelPendingFlowNotifications()
    func clearBadge()
}

enum FlowNotificationPhase: Equatable {
    case focus
    case breakTime
}

final class LocalFlowNotificationService: FlowNotificationService {
    private static let authorizationDefaultsKey = "flow.notificationsRequested.v2"

    private enum NotificationID {
        static let focusFinished = "flow.focusFinished"
        static let breakFinished = "flow.breakFinished"
        static let focusRunningTooLong = "flow.focusRunningTooLong"
        static let breakRunningTooLong = "flow.breakRunningTooLong"

        static let all = [
            focusFinished,
            breakFinished,
            focusRunningTooLong,
            breakRunningTooLong,
        ]
    }

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults

    init(center: UNUserNotificationCenter = .current(), defaults: UserDefaults = .standard) {
        self.center = center
        self.defaults = defaults
    }

    func requestAuthorizationIfNeeded() {
        guard !defaults.bool(forKey: Self.authorizationDefaultsKey) else { return }
        defaults.set(true, forKey: Self.authorizationDefaultsKey)

        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func scheduleFocusFinished(mode: FlowMode, focusedSeconds: Int, fireDate: Date) {
        schedule(
            id: NotificationID.focusFinished,
            title: focusTitle(mode: mode, focusedSeconds: focusedSeconds),
            fireDate: fireDate
        )
    }

    func scheduleBreakFinished(fireDate: Date) {
        schedule(
            id: NotificationID.breakFinished,
            title: String(localized: "休憩が終わりました。Flowに戻りますか？"),
            fireDate: fireDate
        )
    }

    func scheduleRunningTooLong(phase: FlowNotificationPhase, fireDate: Date) {
        let id: String
        let title: String

        switch phase {
        case .focus:
            id = NotificationID.focusRunningTooLong
            title = String(localized: "Flowを開始して1時間以上経過しました。タイマーを止め忘れていませんか？")
        case .breakTime:
            id = NotificationID.breakRunningTooLong
            title = String(localized: "休憩を開始して1時間以上経過しました。タイマーを止め忘れていませんか？")
        }

        schedule(id: id, title: title, fireDate: fireDate)
    }

    func cancelPendingFlowNotifications() {
        center.removePendingNotificationRequests(withIdentifiers: NotificationID.all)
    }

    func clearBadge() {
        center.setBadgeCount(0)
    }

    private func schedule(id: String, title: String, fireDate: Date) {
        let interval = max(1, fireDate.timeIntervalSinceNow)
        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = .default
        content.badge = 1

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    private func focusTitle(mode: FlowMode, focusedSeconds: Int) -> String {
        switch completionMode(for: mode, focusedSeconds: focusedSeconds) {
        case .sprint:
            String(localized: "お疲れ様です。Sprintが完了しました。")
        case .twentyFiveFive:
            String(localized: "お疲れ様です。Focusが完了しました。")
        case .fiftyTen:
            String(localized: "お疲れ様です。Deepが完了しました。")
        case .adaptive:
            String(localized: "お疲れ様です。Flowが完了しました。")
        }
    }

    private func completionMode(for mode: FlowMode, focusedSeconds: Int) -> FlowMode {
        guard mode == .adaptive else { return mode }

        switch focusedSeconds {
        case (50 * 60)...:
            return .fiftyTen
        case (25 * 60)...:
            return .twentyFiveFive
        default:
            return .sprint
        }
    }
}
