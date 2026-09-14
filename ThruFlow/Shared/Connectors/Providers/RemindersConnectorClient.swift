#if os(macOS) || os(iOS)
import EventKit
import Foundation

/// EventKit reads selected lists and applies explicit completion changes.
@MainActor
final class RemindersConnectorClient: ConnectorClient {
    private let eventStore: EKEventStore
    private let installationID: String

    init(eventStore: EKEventStore = EKEventStore(), installationID: String? = nil) {
        self.eventStore = eventStore
        self.installationID = installationID ?? Self.localInstallationID()
    }

    func requestAccess() async throws {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess:
            return
        case .notDetermined:
            let granted: Bool
            do {
                granted = try await eventStore.requestFullAccessToReminders()
            } catch {
                throw ConnectorProviderError.accessDenied
            }
            guard granted else { throw ConnectorProviderError.accessDenied }
        default:
            throw ConnectorProviderError.accessDenied
        }
    }

    func account() async throws -> ConnectorAccount {
        try await requestAccess()
        return ConnectorAccount(id: "eventkit", name: String(localized: "Appleリマインダー"))
    }

    func sources() async throws -> [ConnectorSource] {
        try checkAccess()
        return eventStore.calendars(for: .reminder).map { calendar in
            ConnectorSource(
                id: calendar.calendarIdentifier,
                name: "\(calendar.title) · \(calendar.source.title)"
            )
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func tasks(sourceIDs: Set<String>) async throws -> [ConnectorTask] {
        try checkAccess()
        guard !sourceIDs.isEmpty else { return [] }
        let calendars = eventStore.calendars(for: .reminder).filter {
            sourceIDs.contains($0.calendarIdentifier)
        }
        guard Set(calendars.map(\.calendarIdentifier)) == sourceIDs else {
            throw ConnectorProviderError.sourceUnavailable
        }
        let predicate = eventStore.predicateForReminders(in: calendars)
        let reminders: [EKReminder] = try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                guard let reminders else {
                    continuation.resume(throwing: ConnectorProviderError.invalidResponse)
                    return
                }
                continuation.resume(returning: reminders)
            }
        }
        try Task.checkCancellation()
        try checkAccess()
        var seen = Set<String>()
        return try reminders.map { reminder in
            let id = RemindersTaskIdentity.make(
                externalID: reminder.calendarItemExternalIdentifier,
                localID: reminder.calendarItemIdentifier,
                installationID: installationID,
                isExchange: reminder.calendar.source.sourceType == .exchange,
                isLocal: reminder.calendar.source.sourceType == .local
            )
            guard seen.insert(id).inserted else {
                throw ConnectorProviderError.ambiguousTaskIdentity
            }
            if id.hasPrefix("external:"), let externalID = reminder.calendarItemExternalIdentifier {
                // A copied reminder can share its server identifier in another list.
                // Check all accessible lists so changing the selection cannot merge copies.
                let matches = eventStore.calendarItems(withExternalIdentifier: externalID)
                    .compactMap { $0 as? EKReminder }
                guard Set(matches.map(\.calendarItemIdentifier)).count <= 1 else {
                    throw ConnectorProviderError.ambiguousTaskIdentity
                }
            }
            var dueComponents = reminder.dueDateComponents
            if dueComponents?.timeZone == nil { dueComponents?.timeZone = .current }
            let dueCalendar = dueComponents?.calendar ?? Calendar(identifier: .gregorian)
            return ConnectorTask(
                id: id,
                sourceID: reminder.calendar.calendarIdentifier,
                title: reminder.title ?? "",
                notes: reminder.notes,
                dueDate: dueComponents.flatMap { dueCalendar.date(from: $0) },
                isCompleted: reminder.isCompleted,
                completedAt: reminder.completionDate,
                // EventKit's URL is user-authored content, not a link to this reminder.
                // There is no documented public deep link to one reminder.
                url: nil
            )
        }
    }

    func setCompletion(taskID: String, sourceIDs: Set<String>, change: ConnectorCompletionChange) async throws {
        try checkAccess()
        let matches: [EKReminder]
        if taskID.hasPrefix("external:") {
            matches = eventStore.calendarItems(withExternalIdentifier: String(taskID.dropFirst("external:".count)))
                .compactMap { $0 as? EKReminder }
        } else {
            let prefix = "local:\(installationID):"
            guard taskID.hasPrefix(prefix),
                  let reminder = eventStore.calendarItem(withIdentifier: String(taskID.dropFirst(prefix.count))) as? EKReminder else {
                throw ConnectorProviderError.sourceUnavailable
            }
            matches = [reminder]
        }
        guard matches.count <= 1 else { throw ConnectorProviderError.ambiguousTaskIdentity }
        guard let reminder = matches.first,
              sourceIDs.contains(reminder.calendar.calendarIdentifier),
              reminder.calendar.allowsContentModifications else { throw ConnectorProviderError.sourceUnavailable }
        // Replaying a target state must not complete a second recurrence.
        guard reminder.isCompleted != change.isCompleted else { return }
        try Task.checkCancellation()
        reminder.isCompleted = change.isCompleted
        reminder.completionDate = change.isCompleted ? change.createdAt : nil
        do { try eventStore.save(reminder, commit: true) }
        catch {
            eventStore.reset()
            throw ConnectorProviderError.serviceUnavailable
        }
    }

    private func checkAccess() throws {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
            throw ConnectorProviderError.accessDenied
        }
    }

    private static func localInstallationID() -> String {
        let key = "connectors.reminders.installationID"
        if let value = UserDefaults.standard.string(forKey: key), !value.isEmpty {
            return value
        }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: key)
        return value
    }
}

nonisolated enum RemindersTaskIdentity {
    static func make(externalID: String?, localID: String, installationID: String, isExchange: Bool, isLocal: Bool = false) -> String {
        if !isExchange, !isLocal, let externalID, !externalID.isEmpty {
            return "external:\(externalID)"
        }
        // Apple documents Exchange and on-device reminder external IDs as device-specific.
        // Fallback IDs can only deduplicate on this installation.
        return "local:\(installationID):\(localID)"
    }
}
#endif
