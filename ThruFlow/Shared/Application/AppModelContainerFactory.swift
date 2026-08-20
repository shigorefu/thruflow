import Foundation
import Security
import SwiftData

enum AppModelContainerFactory {
    static let cloudKitContainerIdentifier = "iCloud.com.shigorefu.thruflow"

    static func make() -> ModelContainer {
        let schema = Schema([
            Direction.self,
            Todo.self,
            FlowSession.self,
            FlowSegment.self,
            FlowBreak.self,
        ])
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
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(
                schema: schema,
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
