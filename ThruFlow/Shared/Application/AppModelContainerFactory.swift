import Foundation
import Security
import SwiftData

enum AppModelContainerFactory {
    static let cloudKitContainerIdentifier = "iCloud.com.shigorefu.thruflow"
    static let appGroupIdentifier = "group.com.shigorefu.thruflow"
    static let schema = Schema([
        Area.self,
        Todo.self,
        FlowSession.self,
        FlowSegment.self,
        FlowBreak.self,
    ])

    static func make() -> ModelContainer {
        let configuration: ModelConfiguration
        if isRunningTests {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else if !usesCloudKitForCurrentProcess {
            configuration = ModelConfiguration(
                schema: schema,
                url: persistentStoreURL,
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                url: persistentStoreURL,
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
        }

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    static var usesCloudKitForCurrentProcess: Bool {
        shouldUseCloudKit(
            isRunningTests: isRunningTests,
            isCloudKitDisabled: isCloudKitDisabled,
            isRunningInSimulator: isRunningInSimulator,
            hasCloudKitEntitlement: hasCloudKitEntitlement
        )
    }

    private static var isRunningTests: Bool {
        let processInfo = ProcessInfo.processInfo
        return processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            processInfo.arguments.contains("--uitesting")
    }

    private static var isCloudKitDisabled: Bool {
        let processInfo = ProcessInfo.processInfo
        return processInfo.environment["THRUFLOW_DISABLE_CLOUDKIT"] == "1" ||
            processInfo.arguments.contains("--local-store")
    }

    private static var isRunningInSimulator: Bool {
#if targetEnvironment(simulator)
        true
#else
        false
#endif
    }

    private static var persistentStoreURL: URL {
        let fileManager = FileManager.default
        let applicationSupportDirectory: URL

        if let appGroupDirectory = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            applicationSupportDirectory = appGroupDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        } else if let localApplicationSupportDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            applicationSupportDirectory = localApplicationSupportDirectory
        } else {
            fatalError("Could not resolve the Application Support directory")
        }

        do {
            try fileManager.createDirectory(
                at: applicationSupportDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            fatalError("Could not create the Application Support directory: \(error)")
        }

        return applicationSupportDirectory.appendingPathComponent(
            storeFilename(for: currentStoreEnvironment),
            isDirectory: false
        )
    }

    private static var currentStoreEnvironment: StoreEnvironment {
#if DEBUG
        .development
#else
        .production
#endif
    }

    enum StoreEnvironment: Sendable {
        case development
        case production
    }

    static func storeFilename(for environment: StoreEnvironment) -> String {
        switch environment {
        case .development:
            "default-development.store"
        case .production:
            "default.store"
        }
    }

    private static var hasCloudKitEntitlement: Bool {
#if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil),
              let containerIdentifiers = SecTaskCopyValueForEntitlement(
                  task,
                  "com.apple.developer.icloud-container-identifiers" as CFString,
                  nil
              ) as? [String] else {
            return false
        }

        return containerIdentifiers.contains(cloudKitContainerIdentifier)
#else
        true
#endif
    }

    static func shouldUseCloudKit(
        isRunningTests: Bool,
        isCloudKitDisabled: Bool,
        isRunningInSimulator: Bool,
        hasCloudKitEntitlement: Bool
    ) -> Bool {
        !isRunningTests &&
            !isCloudKitDisabled &&
            !isRunningInSimulator &&
            hasCloudKitEntitlement
    }
}
