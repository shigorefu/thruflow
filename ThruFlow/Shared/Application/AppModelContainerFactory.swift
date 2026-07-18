import Foundation
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
        } else if isCloudKitDisabled {
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
}
