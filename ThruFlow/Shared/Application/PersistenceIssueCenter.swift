import CloudKit
import Combine
import CoreData
import Foundation
import OSLog
import SwiftData

enum PersistenceOperation: String, Sendable {
    case flowStart
    case flowUpdate
    case flowStop
    case flowDelete
    case flowSynchronization
    case taskUpdate
    case areaUpdate
    case historyUpdate
    case habitMaterialization
    case dataLoad
    case widgetSnapshot
    case export
}

struct PersistenceIssue: Identifiable, Equatable, Sendable {
    let id = UUID()
    let operation: PersistenceOperation
    let occurredAt: Date
}

enum CloudSyncState: Equatable, Sendable {
    case localOnly
    case checking
    case available
    case syncing
    case synced(Date)
    case unavailable
    case failed(Date)
}

@MainActor
final class PersistenceIssueCenter: ObservableObject {
    static let shared = PersistenceIssueCenter()

    @Published private(set) var currentIssue: PersistenceIssue?
    @Published private(set) var cloudSyncState: CloudSyncState = .checking

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.shigorefu.thruflow",
        category: "Persistence"
    )
    private var cloudKitObserver: NSObjectProtocol?
    private var isMonitoringCloudKit = false

    deinit {
        if let cloudKitObserver {
            NotificationCenter.default.removeObserver(cloudKitObserver)
        }
    }

    @discardableResult
    func save(
        _ modelContext: ModelContext,
        operation: PersistenceOperation,
        rollbackOnFailure: Bool = true
    ) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            if rollbackOnFailure {
                modelContext.rollback()
            }
            report(error, operation: operation)
            return false
        }
    }

    func report(_ error: Error, operation: PersistenceOperation) {
        log(error, operation: operation)
        currentIssue = PersistenceIssue(operation: operation, occurredAt: .now)
    }

    func log(_ error: Error, operation: PersistenceOperation) {
        logger.error("Persistence operation failed: \(operation.rawValue, privacy: .public); error: \(String(describing: error), privacy: .public)")
    }

    func dismissCurrentIssue() {
        currentIssue = nil
    }

    func beginCloudKitMonitoring(
        isEnabled: Bool,
        containerIdentifier: String
    ) async {
        guard isEnabled else {
            cloudSyncState = .localOnly
            return
        }

        installCloudKitObserverIfNeeded()
        cloudSyncState = .checking

        do {
            let status = try await CKContainer(identifier: containerIdentifier).accountStatus()
            switch status {
            case .available:
                cloudSyncState = .available
            case .couldNotDetermine, .noAccount, .restricted, .temporarilyUnavailable:
                cloudSyncState = .unavailable
            @unknown default:
                cloudSyncState = .unavailable
            }
        } catch {
            logger.error(
                "CloudKit account status failed: \(String(describing: error), privacy: .public)"
            )
            cloudSyncState = .failed(.now)
        }
    }

    private func installCloudKitObserverIfNeeded() {
        guard !isMonitoringCloudKit else { return }
        isMonitoringCloudKit = true

        cloudKitObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event else {
                return
            }

            Task { @MainActor [weak self] in
                self?.handleCloudKitEvent(event)
            }
        }
    }

    private func handleCloudKitEvent(_ event: NSPersistentCloudKitContainer.Event) {
        guard event.endDate != nil else {
            cloudSyncState = .syncing
            return
        }

        if event.succeeded {
            cloudSyncState = .synced(event.endDate ?? .now)
            return
        }

        if let error = event.error {
            logger.error("CloudKit event failed: type=\(String(describing: event.type), privacy: .public); error=\(String(describing: error), privacy: .public)")
        } else {
            logger.error("CloudKit event failed without an error: type=\(String(describing: event.type), privacy: .public)")
        }
        cloudSyncState = .failed(event.endDate ?? .now)
    }
}

@MainActor
extension ModelContext {
    @discardableResult
    func saveReporting(
        _ operation: PersistenceOperation,
        rollbackOnFailure: Bool = true
    ) -> Bool {
        PersistenceIssueCenter.shared.save(
            self,
            operation: operation,
            rollbackOnFailure: rollbackOnFailure
        )
    }
}
