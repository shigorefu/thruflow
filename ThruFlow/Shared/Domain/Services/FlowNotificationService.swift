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
    func cancelPendingFlowNotifications()
}

final class LocalFlowNotificationService: FlowNotificationService {
    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults

    init(center: UNUserNotificationCenter = .current(), defaults: UserDefaults = .standard) {
        self.center = center
        self.defaults = defaults
    }

    func requestAuthorizationIfNeeded() {
        guard !defaults.bool(forKey: "flow.notificationsRequested") else { return }
        defaults.set(true, forKey: "flow.notificationsRequested")

        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func scheduleFocusFinished(mode: FlowMode, focusedSeconds: Int, fireDate: Date) {
        schedule(
            id: "flow.focusFinished",
            title: focusTitle(mode: mode, focusedSeconds: focusedSeconds),
            fireDate: fireDate
        )
    }

    func scheduleBreakFinished(fireDate: Date) {
        schedule(
            id: "flow.breakFinished",
            title: String(localized: "休憩が終わりました。Flowに戻りますか？"),
            fireDate: fireDate
        )
    }

    func cancelPendingFlowNotifications() {
        center.removePendingNotificationRequests(withIdentifiers: [
            "flow.focusFinished",
            "flow.breakFinished",
        ])
    }

    private func schedule(id: String, title: String, fireDate: Date) {
        let interval = max(1, fireDate.timeIntervalSinceNow)
        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    private func focusTitle(mode: FlowMode, focusedSeconds: Int) -> String {
        switch focusedSeconds {
        case 12 * 60:
            String(localized: "最初の0.5 Blockが完了しました。1 Blockまで続けますか？")
        case 25 * 60:
            String(localized: "1 Blockが完了しました。")
        case 50 * 60:
            String(localized: "2 Blocksが完了しました。")
        default:
            String(localized: "\(BlockUnit.displayText(forFocusedSeconds: focusedSeconds)) が完了しました。")
        }
    }
}
