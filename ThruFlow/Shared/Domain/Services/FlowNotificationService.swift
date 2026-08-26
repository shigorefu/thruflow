//
//  FlowNotificationService.swift
//  ThruFlow
//
//

import Foundation
import UserNotifications

protocol FlowUserNotificationCenter: AnyObject {
    func requestAuthorization(
        options: UNAuthorizationOptions,
        completionHandler: @escaping @Sendable (Bool, (any Error)?) -> Void
    )
    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: (@Sendable ((any Error)?) -> Void)?
    )
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
    func clearBadge()
}

final class SystemFlowUserNotificationCenter: FlowUserNotificationCenter {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization(
        options: UNAuthorizationOptions,
        completionHandler: @escaping @Sendable (Bool, (any Error)?) -> Void
    ) {
        center.requestAuthorization(options: options, completionHandler: completionHandler)
    }

    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: (@Sendable ((any Error)?) -> Void)?
    ) {
        center.add(request, withCompletionHandler: completionHandler)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func clearBadge() {
#if os(watchOS)
        return
#else
        center.setBadgeCount(0, withCompletionHandler: nil)
#endif
    }
}

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
    private static let generationDefaultsKey = "flow.notificationGeneration.v1"
    private static let knownIdentifiersDefaultsKey = "flow.notificationIdentifiers.v1"

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

    private let center: any FlowUserNotificationCenter
    private let defaults: UserDefaults
    private let stateLock = NSLock()
    private var generation: String

    init(
        center: any FlowUserNotificationCenter = SystemFlowUserNotificationCenter(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults

        if let storedGeneration = defaults.string(forKey: Self.generationDefaultsKey) {
            generation = storedGeneration
        } else {
            let initialGeneration = UUID().uuidString
            generation = initialGeneration
            defaults.set(initialGeneration, forKey: Self.generationDefaultsKey)
        }
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
        let identifiers = withStateLock { () -> [String] in
            let knownIdentifiers = defaults.stringArray(
                forKey: Self.knownIdentifiersDefaultsKey
            ) ?? []
            let currentIdentifiers = NotificationID.all.map {
                versionedIdentifier(base: $0, generation: generation)
            }
            let identifiers = Array(
                Set(knownIdentifiers + currentIdentifiers + NotificationID.all)
            )

            generation = UUID().uuidString
            defaults.set(generation, forKey: Self.generationDefaultsKey)
            defaults.removeObject(forKey: Self.knownIdentifiersDefaultsKey)
            return identifiers
        }

        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func clearBadge() {
        center.clearBadge()
    }

    private func schedule(id baseIdentifier: String, title: String, fireDate: Date) {
        let interval = max(1, fireDate.timeIntervalSinceNow)
        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = .default
        content.badge = 1

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let scheduledGeneration = withStateLock { () -> String in
            let scheduledGeneration = generation
            let identifier = versionedIdentifier(
                base: baseIdentifier,
                generation: scheduledGeneration
            )
            var knownIdentifiers = Set(
                defaults.stringArray(forKey: Self.knownIdentifiersDefaultsKey) ?? []
            )
            knownIdentifiers.insert(identifier)
            defaults.set(Array(knownIdentifiers), forKey: Self.knownIdentifiersDefaultsKey)
            return scheduledGeneration
        }
        let identifier = versionedIdentifier(
            base: baseIdentifier,
            generation: scheduledGeneration
        )
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { [weak self] error in
            guard let self else { return }
            let isStale = self.withStateLock {
                scheduledGeneration != self.generation
            }
            guard error != nil || isStale else { return }

            self.center.removePendingNotificationRequests(withIdentifiers: [identifier])
            self.center.removeDeliveredNotifications(withIdentifiers: [identifier])
            self.removeKnownIdentifier(identifier)
        }
    }

    private func versionedIdentifier(base: String, generation: String) -> String {
        "\(base).\(generation)"
    }

    private func removeKnownIdentifier(_ identifier: String) {
        withStateLock {
            var knownIdentifiers = Set(
                defaults.stringArray(forKey: Self.knownIdentifiersDefaultsKey) ?? []
            )
            knownIdentifiers.remove(identifier)
            defaults.set(Array(knownIdentifiers), forKey: Self.knownIdentifiersDefaultsKey)
        }
    }

    private func withStateLock<Value>(_ operation: () -> Value) -> Value {
        stateLock.lock()
        defer { stateLock.unlock() }
        return operation()
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
