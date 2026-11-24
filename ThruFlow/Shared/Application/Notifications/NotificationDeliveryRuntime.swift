import Foundation
import Combine
import LocalAuthentication
import Security
import UserNotifications

/// Local transport state only; no SwiftData/CloudKit schema or user identity.
nonisolated struct RemoteNotificationEvent: Codable, Equatable, Sendable {
    let identifier: String
    let version: String
    let fireAt: TimeInterval
    let title: String
    let body: String
    let badge: Int
    var systemIdentifier: String {
        identifier.hasPrefix("task.reminder.") ? identifier + ".delivery." + version : identifier
    }

    func request(deferred: Bool) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = badge as NSNumber
        content.userInfo = ["local_identifier": systemIdentifier, "logical_identifier": identifier,
                            "event_version": version, "original_fire_at": fireAt,
                            "fallback_fire_at": fireAt + (deferred ? 30 : 0)]
        if identifier.hasPrefix("task.reminder.") { content.userInfo["taskReminderDate"] = fireAt }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second],
            from: Date(timeIntervalSince1970: fireAt + (deferred ? 30 : 0)))
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        return UNNotificationRequest(identifier: systemIdentifier, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
    }

    /// Never export user-authored Task text. Remote Task alerts contain only fixed app copy.
    var publicPayload: RemoteNotificationEvent {
        RemoteNotificationEvent(identifier: systemIdentifier, version: version, fireAt: fireAt,
                                title: title, body: "", badge: badge)
    }
}

nonisolated struct RemoteNotificationSnapshot: Codable, Equatable, Sendable {
    var revision: Int64 = 0
    var events: [RemoteNotificationEvent] = []
}

@MainActor
protocol RemoteNotificationTransport {
    func enroll(token: String, environment: String) async throws -> RemoteNotificationEnrollment
    func replace(_ snapshot: RemoteNotificationSnapshot) async throws -> Bool
    func revoke() async throws
    func cancelPendingRequests()
    func renewed() throws -> any RemoteNotificationTransport
}

extension Notification.Name {
    static let notificationRemotePreferenceChanged = Notification.Name("notification.remote.preferenceChanged")
}

nonisolated struct RemoteNotificationEnrollment: Sendable {
    let ready: Bool
    let revision: Int64
}

@MainActor
protocol NotificationDeliveryCenter {
    func pending() async -> [UNNotificationRequest]
    func delivered() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func removePending(_ identifiers: [String])
    func removeDelivered(_ identifiers: [String])
}

@MainActor
private final class SystemNotificationDeliveryCenter: NotificationDeliveryCenter {
    private let center = UNUserNotificationCenter.current()
    func pending() async -> [UNNotificationRequest] { await center.pendingNotificationRequests() }
    func delivered() async -> [UNNotificationRequest] { await center.deliveredNotifications().map(\.request) }
    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
    func removePending(_ identifiers: [String]) { center.removePendingNotificationRequests(withIdentifiers: identifiers) }
    func removeDelivered(_ identifiers: [String]) { center.removeDeliveredNotifications(withIdentifiers: identifiers) }
}

/// Durable server acceptance postpones a local fallback by 30 seconds. It never
/// proves APNs delivery; only matching receipt cancels the fallback. NSE execution
/// is best effort, so delivery cannot be described as exactly once.
@MainActor
final class NotificationDeliveryRuntime: ObservableObject {
    static let shared = NotificationDeliveryRuntime()
    private static let stateKey = "notifications.remote.snapshot.v1"
    private static let deferredKey = "notifications.remote.deferred.v1"
    private static let preferenceKey = "notification.remote.enabled"
    private static let unconfirmedKey = "notification.remote.revocationUnconfirmed"
    private static let pendingRevocationsKey = "notification.remote.pendingRevocations"
    private var pendingRevocations: Int
    static var isRemoteEnabled: Bool {
        isEnabled && (UserDefaults.standard.object(forKey: preferenceKey) as? Bool ?? true)
    }
    @Published private(set) var remoteEnabled: Bool
    @Published private(set) var revocationUnconfirmed: Bool
    private var generation = 0
    private var revocations: [Task<Void, Never>] = []
    static var isEnabled: Bool {
#if os(watchOS)
        false
#else
        !AppModelContainerFactory.usesDemoData &&
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil &&
        !ProcessInfo.processInfo.arguments.contains("--uitesting") &&
        !ProcessInfo.processInfo.arguments.contains("--screenshot-mode") && endpoint != nil
#endif
    }
    private static var endpoint: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "ThruFlowPushEndpoint") as? String,
              let url = URL(string: value), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else { return nil }
        return url
    }

    private let center: any NotificationDeliveryCenter
    private let defaults: UserDefaults
    private let enabled: @MainActor () -> Bool
    private let now: () -> Date
    private let systemHooks: Bool
    private var transport: (any RemoteNotificationTransport)?
    private var retiredTransport: (any RemoteNotificationTransport)?
    private var snapshot: RemoteNotificationSnapshot
    private var deferred: Set<String>
    private var receipts: [String: String] = [:]
    private var presentedVersions = Set<String>()
    private var receiptOrder: [String] = []
    private var presentationOrder: [String] = []
    private var started = false
    private var registered = false
    private var token: String?
    private var environment: String?
    private var needsSync = false
    private var synchronization: Task<Void, Never>?
    private var retryTimer: Timer?
    private var operations: [@MainActor () async -> Void] = []
    private var localWorker: Task<Void, Never>?
    private var presentationDelegate: RemoteNotificationPresentationDelegate?

    init(center: (any NotificationDeliveryCenter)? = nil, defaults: UserDefaults = .standard,
         transport: (any RemoteNotificationTransport)? = nil,
         enabled: @escaping @MainActor () -> Bool = { NotificationDeliveryRuntime.isEnabled },
         now: @escaping () -> Date = { .now }, systemHooks: Bool = true) {
        self.center = center ?? SystemNotificationDeliveryCenter()
        self.defaults = defaults
        self.transport = transport
        self.enabled = enabled
        self.now = now
        self.systemHooks = systemHooks
        remoteEnabled = defaults.object(forKey: Self.preferenceKey) as? Bool ?? true
        pendingRevocations = max(defaults.integer(forKey: Self.pendingRevocationsKey), defaults.bool(forKey: Self.unconfirmedKey) ? 1 : 0)
        revocationUnconfirmed = pendingRevocations > 0
        snapshot = defaults.data(forKey: Self.stateKey).flatMap {
            try? JSONDecoder().decode(RemoteNotificationSnapshot.self, from: $0)
        } ?? RemoteNotificationSnapshot(revision: Int64(now().timeIntervalSince1970 * 1_000))
        deferred = Set(defaults.stringArray(forKey: Self.deferredKey) ?? [])
    }

    func start() {
        guard enabled(), !started else { return }
        started = true
        if remoteEnabled, transport == nil, let endpoint = Self.endpoint {
            transport = try? HTTPRemoteNotificationTransport(endpoint: endpoint)
        }
        if !remoteEnabled {
            var retainedSafetyVersions = Set<String>()
            for event in snapshot.events {
                if event.fireAt > now().timeIntervalSince1970 {
                    queueAdd(event.request(deferred: false), event: event)
                } else if deferred.contains(event.version), event.fireAt + 30 > now().timeIntervalSince1970 {
                    retainedSafetyVersions.insert(event.version)
                    queueAdd(event.request(deferred: true), event: event)
                }
            }
            deferred = retainedSafetyVersions
            persist()
        }
        if systemHooks {
            UserDefaults(suiteName: "group.com.shigorefu.thruflow")?.set(remoteEnabled, forKey: Self.preferenceKey)
            let delegate = RemoteNotificationPresentationDelegate(runtime: self)
            presentationDelegate = delegate
            UNUserNotificationCenter.current().delegate = delegate
            if remoteEnabled { startRetryTimer() }
        }
        Task { [weak self] in await self?.reconcileDeliveredNotifications() }
    }

    /// Stops scheduling immediately. The single explicit revocation request is
    /// the only network operation allowed after switching off; it is never retried.
    func setRemoteEnabled(_ value: Bool) {
        guard enabled() else { return }
        defaults.set(value, forKey: Self.preferenceKey)
        guard remoteEnabled != value else { return }
        remoteEnabled = value
        generation += 1
        synchronization?.cancel()
        synchronization = nil
        needsSync = false
        retryTimer?.invalidate()
        retryTimer = nil
        registered = false
        token = nil
        environment = nil
        if systemHooks {
            UserDefaults(suiteName: "group.com.shigorefu.thruflow")?.set(value, forKey: Self.preferenceKey)
        }
        let previous = transport ?? retiredTransport
        previous?.cancelPendingRequests()
        if value {
            if let previous { transport = try? previous.renewed() }
            else if let endpoint = Self.endpoint {
                transport = try? HTTPRemoteNotificationTransport(endpoint: endpoint, rotateIdentity: true)
            }
            start()
            if systemHooks { startRetryTimer() }
        } else {
            restoreLocalDeadlines()
            let existing: (any RemoteNotificationTransport)?
            if let previous { existing = previous }
            else if let endpoint = Self.endpoint {
                existing = try? HTTPRemoteNotificationTransport(endpoint: endpoint, existingIdentityOnly: true)
            } else { existing = nil }
            transport = nil
            retiredTransport = existing
            if let existing {
                pendingRevocations += 1
                setRevocationUnconfirmed(true)
                let revocation = Task { [weak self] in
                    do {
                        try await existing.revoke()
                        guard let self else { return }
                        self.pendingRevocations = max(0, self.pendingRevocations - 1)
                        self.setRevocationUnconfirmed(self.pendingRevocations > 0)
                    } catch {
                        // Persist an honest warning; staying off never triggers retries.
                    }
                }
                revocations.append(revocation)
            }
        }
        NotificationCenter.default.post(name: .notificationRemotePreferenceChanged, object: nil)
    }

    private func setRevocationUnconfirmed(_ value: Bool) {
        revocationUnconfirmed = value
        defaults.set(value, forKey: Self.unconfirmedKey)
        defaults.set(pendingRevocations, forKey: Self.pendingRevocationsKey)
    }

    private func startRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.scheduleSynchronization() }
        }
    }

    private func restoreLocalDeadlines() {
        // Already-due safety requests retain their current pending deadline;
        // replaying a past calendar date could lose the alert or cause a burst.
        let previousEvents = snapshot.events
        snapshot.events = previousEvents.map { event in
            RemoteNotificationEvent(identifier: event.identifier, version: UUID().uuidString,
                fireAt: event.fireAt, title: event.title, body: event.body, badge: event.badge)
        }
        var retainedSafetyVersions = Set<String>()
        for (old, event) in zip(previousEvents, snapshot.events) {
            enqueue { [center] in center.removePending([old.systemIdentifier]) }
            if event.fireAt > now().timeIntervalSince1970 {
                queueAdd(event.request(deferred: false), event: event)
            } else if deferred.contains(old.version), event.fireAt + 30 > now().timeIntervalSince1970 {
                retainedSafetyVersions.insert(event.version)
                queueAdd(event.request(deferred: true), event: event)
            }
        }
        // New versions also protect restored local requests if an old NSE runs
        // after the user re-enables the server and its App Group gate is open.
        // Keep the due-window metadata across rapid toggles and relaunches.
        deferred = retainedSafetyVersions
        persist()
    }

    func registerDeviceToken(_ data: Data, environment: String) {
        guard enabled(), remoteEnabled, ["sandbox", "production"].contains(environment), !data.isEmpty else { return }
        start()
        token = data.map { String(format: "%02x", $0) }.joined()
        self.environment = environment
        registered = true
        scheduleSynchronization()
    }

    func registrationFailed() {
        registered = false
        token = nil
        for event in snapshot.events where deferred.contains(event.version) && event.fireAt > now().timeIntervalSince1970 {
            queueAdd(event.request(deferred: false), event: event)
        }
        deferred.removeAll()
        persist()
    }

    /// One queue owns all local adds/removals, including asynchronous ACK changes.
    func add(_ request: UNNotificationRequest, completion: (@Sendable ((any Error)?) -> Void)? = nil) {
        let triggerDate = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ??
            (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
        guard enabled(), let date = triggerDate, Self.owns(request.identifier) else {
            enqueue { [center] in
                do { try await center.add(request); completion?(nil) } catch { completion?(error) }
            }
            return
        }
        let timestamp = request.content.userInfo["taskReminderDate"] as? Double ?? date.timeIntervalSince1970
        let old = snapshot.events.first { $0.identifier == request.identifier }
        let equivalent = old.map {
            $0.fireAt == timestamp && $0.title == request.content.title && $0.body == request.content.body
        } ?? false
        let event = RemoteNotificationEvent(identifier: request.identifier,
            version: equivalent ? old!.version : UUID().uuidString,
            fireAt: timestamp, title: request.content.title, body: request.content.body,
            badge: request.content.badge?.intValue ?? 0)
        if !equivalent {
            if let old {
                receipts[old.systemIdentifier] = nil
                enqueue { [center] in center.removePending([old.systemIdentifier]) }
            }
            snapshot.events.removeAll { $0.identifier == event.identifier }
            snapshot.events.append(event)
            receipts[event.identifier] = nil
            changed()
        }
        queueAdd(event.request(deferred: deferred.contains(event.version)), event: event, completion: completion)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            add(request) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func removePending(_ identifiers: [String]) {
        let ids = Set(identifiers)
        let obsolete = snapshot.events.filter { ids.contains($0.identifier) || ids.contains($0.systemIdentifier) }
        if !obsolete.isEmpty {
            snapshot.events.removeAll { ids.contains($0.identifier) || ids.contains($0.systemIdentifier) }
            changed()
        }
        receipts = receipts.filter { id, _ in
            !ids.contains(id) && !ids.contains(id.components(separatedBy: ".delivery.").first ?? id)
        }
        enqueue { [center] in
            let actual = await center.pending().filter {
                ids.contains($0.identifier) || ($0.content.userInfo["logical_identifier"] as? String).map(ids.contains) == true
            }.map(\.identifier)
            center.removePending(Array(Set(actual + identifiers + obsolete.map(\.systemIdentifier))))
        }
    }
    func removeDelivered(_ identifiers: [String]) {
        let ids = Set(identifiers)
        enqueue { [center] in
            let actual = await center.delivered().filter {
                ids.contains($0.identifier) || ($0.content.userInfo["logical_identifier"] as? String).map(ids.contains) == true
            }.map(\.identifier)
            center.removeDelivered(Array(Set(actual + identifiers)))
        }
    }

    @discardableResult
    func receive(userInfo: [AnyHashable: Any]) async -> Bool {
        guard enabled(), remoteEnabled, let id = userInfo["local_identifier"] as? String,
              let version = userInfo["event_version"] as? String else { return false }
        let logicalID = id.components(separatedBy: ".delivery.").first ?? id
        let current = snapshot.events.first { $0.identifier == logicalID }
        if let current, current.version != version { return false }
        if receipts[id] == version { return true }
        // An NSE marker proves arrival, never currentness: completed/cancelled events stay rejected.
        guard let current, current.systemIdentifier == id else { return false }
        receipts[id] = version
        receiptOrder.append(id)
        if receiptOrder.count > 256 { receipts[receiptOrder.removeFirst()] = nil }
        snapshot.events.removeAll { $0.systemIdentifier == id && $0.version == version }
        changed()
        enqueue { [center] in
            if await center.pending().contains(where: { $0.identifier == id &&
                $0.content.userInfo["event_version"] as? String == version }) {
                center.removePending([id])
            }
            let delivered = await center.delivered()
            center.removeDelivered(delivered.filter {
                !($0.trigger is UNPushNotificationTrigger) && $0.identifier == id &&
                $0.content.userInfo["event_version"] as? String == version
            }.map(\.identifier))
        }
        // Native background completion must not allow suspension ahead of the local cancellation.
        await localWorker?.value
        return true
    }

    func shouldPresentRemote(userInfo: [AnyHashable: Any]) async -> Bool {
        guard await receive(userInfo: userInfo), let version = userInfo["event_version"] as? String,
              markPresented(version) else { return false }
        return true
    }
    func shouldPresentLocal(userInfo: [AnyHashable: Any]) -> Bool {
        guard let version = userInfo["event_version"] as? String else { return true }
        return markPresented(version)
    }
    private func markPresented(_ version: String) -> Bool {
        guard presentedVersions.insert(version).inserted else { return false }
        presentationOrder.append(version)
        if presentationOrder.count > 256 { presentedVersions.remove(presentationOrder.removeFirst()) }
        return true
    }

    func waitUntilIdle() async {
        await localWorker?.value
        await synchronization?.value
        for revocation in revocations { await revocation.value }
        revocations.removeAll()
        await localWorker?.value
    }

    private func queueAdd(_ request: UNNotificationRequest, event: RemoteNotificationEvent,
                          completion: (@Sendable ((any Error)?) -> Void)? = nil) {
        let scheduledGeneration = generation
        enqueue { [weak self, center] in
            guard let self, self.isCurrent(event), !self.hasReceipt(event.version) else {
                completion?(nil); return
            }
            do {
                let effective = (!self.remoteEnabled || self.generation != scheduledGeneration) && event.fireAt > self.now().timeIntervalSince1970
                    ? event.request(deferred: false) : request
                try await center.add(effective)
                completion?(nil)
                self.scheduleSynchronization()
            } catch { completion?(error) }
        }
    }
    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        operations.append(operation)
        guard localWorker == nil else { return }
        localWorker = Task { [weak self] in
            guard let self else { return }
            while !self.operations.isEmpty { await self.operations.removeFirst()() }
            self.localWorker = nil
        }
    }
    private func isCurrent(_ event: RemoteNotificationEvent) -> Bool {
        snapshot.events.contains { $0.identifier == event.identifier && $0.version == event.version }
    }
    private func hasReceipt(_ version: String) -> Bool {
        guard systemHooks, remoteEnabled else { return false }
        return UserDefaults(suiteName: "group.com.shigorefu.thruflow")?
            .object(forKey: "notification.receipt.\(version)") != nil
    }
    private func changed() {
        snapshot.revision = max(snapshot.revision + 1, Int64(now().timeIntervalSince1970 * 1_000))
        deferred.formIntersection(Set(snapshot.events.map(\.version)))
        persist()
        scheduleSynchronization()
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(snapshot) { defaults.set(data, forKey: Self.stateKey) }
        defaults.set(Array(deferred), forKey: Self.deferredKey)
    }
    private func scheduleSynchronization() {
        guard enabled(), remoteEnabled, started, registered, transport != nil else { return }
        needsSync = true
        guard synchronization == nil else { return }
        let currentGeneration = generation
        synchronization = Task { [weak self] in
            guard let self else { return }
            while self.needsSync && self.generation == currentGeneration && !Task.isCancelled {
                self.needsSync = false
                await self.synchronize(generation: currentGeneration)
            }
            if self.generation == currentGeneration { self.synchronization = nil }
        }
    }
    private func synchronize(generation expectedGeneration: Int) async {
        guard enabled(), remoteEnabled, generation == expectedGeneration, registered, let token, let environment, let transport else { return }
        do {
            let enrollment = try await transport.enroll(token: token, environment: environment)
            guard enrollment.ready, registered, remoteEnabled, generation == expectedGeneration, !Task.isCancelled else { return }
            if snapshot.revision <= enrollment.revision {
                snapshot.revision = enrollment.revision + 1
                persist()
            }
            // Keep validation/tombstone context beyond delivery; an NSE marker alone cannot resurrect a cancelled event.
            let events = snapshot.events.filter { $0.fireAt + 300 > now().timeIntervalSince1970 }
            if events != snapshot.events { snapshot.events = events; changed() }
            // Let the backend complete its bounded APNs retry window after the original deadline.
            let outgoing = snapshot.events.filter { $0.fireAt + 25 > now().timeIntervalSince1970 && !hasReceipt($0.version) }
            let sent = RemoteNotificationSnapshot(revision: snapshot.revision, events: outgoing.map(\.publicPayload))
            guard try await transport.replace(sent), registered, remoteEnabled, generation == expectedGeneration, !Task.isCancelled else { return }
            for sentEvent in sent.events {
                guard let event = snapshot.events.first(where: { $0.version == sentEvent.version }),
                      !hasReceipt(event.version), !deferred.contains(event.version),
                      event.fireAt > now().timeIntervalSince1970 else { continue }
                deferred.insert(event.version)
                queueAdd(event.request(deferred: true), event: event)
            }
            persist()
        } catch {
            // Offline/auth/readiness errors keep the local fallback. The minute retry is app-lifetime only.
        }
    }
    private func reconcileDeliveredNotifications() async {
        for request in await center.delivered() where request.trigger is UNPushNotificationTrigger {
            await receive(userInfo: request.content.userInfo)
        }
    }
    private static func owns(_ id: String) -> Bool { id.hasPrefix("flow.") || id.hasPrefix("task.reminder.") }
}

@MainActor
private final class RemoteNotificationPresentationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private weak var runtime: NotificationDeliveryRuntime?
    init(runtime: NotificationDeliveryRuntime) { self.runtime = runtime }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor [weak self] in
            let remote = notification.request.trigger is UNPushNotificationTrigger
            let info = notification.request.content.userInfo
            let valid = remote ? await self?.runtime?.shouldPresentRemote(userInfo: info) == true :
                self?.runtime?.shouldPresentLocal(userInfo: info) == true
            let id = info["local_identifier"] as? String ?? notification.request.identifier
            completionHandler(valid && id.hasPrefix("task.reminder.") ? [.banner, .sound] : [])
        }
    }
}

/// Keeps the Domain protocol independent of the Application transport owner.
@MainActor
final class RoutedFlowUserNotificationCenter: FlowUserNotificationCenter {
    private let local = SystemFlowUserNotificationCenter()
    func requestAuthorization(options: UNAuthorizationOptions,
        completionHandler: @escaping @Sendable (Bool, (any Error)?) -> Void) {
        local.requestAuthorization(options: options, completionHandler: completionHandler)
    }
    func add(_ request: UNNotificationRequest,
        withCompletionHandler completionHandler: (@Sendable ((any Error)?) -> Void)?) {
        NotificationDeliveryRuntime.shared.add(request, completion: completionHandler)
    }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        NotificationDeliveryRuntime.shared.removePending(identifiers)
    }
    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        NotificationDeliveryRuntime.shared.removeDelivered(identifiers)
    }
    func clearBadge() { local.clearBadge() }
}

@MainActor
private final class HTTPRemoteNotificationTransport: RemoteNotificationTransport {
    private struct Identity: Codable { let id: String; let secret: String }
    private struct Enrollment: Encodable { let token: String; let environment: String; let platform: String }
    private struct Ready: Decodable { let ready: Bool; let revision: Int64 }
    private struct Accepted: Decodable { let accepted: Bool; let revision: Int64 }
    private enum Failure: Error { case keychain, response }
    private let endpoint: URL
    private let identity: Identity
    private let session: URLSession
    init(endpoint: URL, existingIdentityOnly: Bool = false, rotateIdentity: Bool = false) throws {
        self.endpoint = endpoint
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        config.httpShouldSetCookies = false
        config.urlCache = nil
        session = URLSession(configuration: config)
        let authentication = LAContext()
        authentication.interactionNotAllowed = true
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.shigorefu.thruflow.notifications.v1",
            kSecAttrAccount as String: endpoint.absoluteString, kSecAttrSynchronizable as String: false,
            kSecUseAuthenticationContext as String: authentication]
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if !rotateIdentity, status == errSecSuccess, let data = result as? Data,
           let stored = try? JSONDecoder().decode(Identity.self, from: data) { identity = stored }
        else if !existingIdentityOnly && (status == errSecItemNotFound || (rotateIdentity && status == errSecSuccess)) {
            var random = [UInt8](repeating: 0, count: 32)
            guard SecRandomCopyBytes(kSecRandomDefault, random.count, &random) == errSecSuccess else { throw Failure.keychain }
            identity = Identity(id: UUID().uuidString, secret: random.map { String(format: "%02x", $0) }.joined())
            query.removeValue(forKey: kSecReturnData as String)
            query.removeValue(forKey: kSecMatchLimit as String)
            query.removeValue(forKey: kSecUseAuthenticationContext as String)
            query[kSecValueData as String] = try JSONEncoder().encode(identity)
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            if status == errSecSuccess {
                let value = query.removeValue(forKey: kSecValueData as String)!
                query[kSecUseAuthenticationContext as String] = authentication
                guard SecItemUpdate(query as CFDictionary, [kSecValueData as String: value] as CFDictionary) == errSecSuccess else { throw Failure.keychain }
            } else {
                guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else { throw Failure.keychain }
            }
        } else { throw Failure.keychain }
    }
    func enroll(token: String, environment: String) async throws -> RemoteNotificationEnrollment {
#if os(macOS)
        let platform = "macOS"
#else
        let platform = "iOS"
#endif
        let data = try await put(path: "v1/installations/\(identity.id)",
            body: JSONEncoder().encode(Enrollment(token: token, environment: environment, platform: platform)))
        let response = try JSONDecoder().decode(Ready.self, from: data)
        return RemoteNotificationEnrollment(ready: response.ready, revision: response.revision)
    }
    func replace(_ snapshot: RemoteNotificationSnapshot) async throws -> Bool {
        let data = try await put(path: "v1/installations/\(identity.id)/schedule", body: JSONEncoder().encode(snapshot))
        let response = try JSONDecoder().decode(Accepted.self, from: data)
        return response.accepted && response.revision == snapshot.revision
    }
    func cancelPendingRequests() { session.invalidateAndCancel() }

    func renewed() throws -> any RemoteNotificationTransport {
        try HTTPRemoteNotificationTransport(endpoint: endpoint, rotateIdentity: true)
    }

    func revoke() async throws {
        // The scheduling session was invalidated first. A fresh, short-lived
        // session performs only this deliberate final request for the old identity.
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        config.httpShouldSetCookies = false
        config.urlCache = nil
        let revocationSession = URLSession(configuration: config)
        defer { revocationSession.invalidateAndCancel() }
        var request = URLRequest(url: endpoint.appendingPathComponent("v1/installations/\(identity.id)"))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(identity.secret)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await revocationSession.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { throw Failure.response }
    }

    private func put(path: String, body: Data) async throws -> Data {
        var request = URLRequest(url: endpoint.appendingPathComponent(path))
        request.httpMethod = "PUT"
        request.setValue("Bearer \(identity.secret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { throw Failure.response }
        return data
    }
}
