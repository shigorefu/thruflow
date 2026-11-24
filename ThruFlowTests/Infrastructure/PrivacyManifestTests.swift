import Foundation
import Testing

struct PrivacyManifestTests {
    @Test func appManifestDeclaresNotificationDataOnlyForLinkedAppFunctionality() throws {
        let manifest = try loadManifest(at: "ThruFlow/PrivacyInfo.xcprivacy")
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        let collected = try #require(manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        #expect(collected.count == 2)
        #expect(Set(collected.compactMap { $0["NSPrivacyCollectedDataType"] as? String }) == [
            "NSPrivacyCollectedDataTypeDeviceID", "NSPrivacyCollectedDataTypeProductInteraction",
        ])
        for declaration in collected {
            #expect(declaration["NSPrivacyCollectedDataTypeLinked"] as? Bool == true)
            #expect(declaration["NSPrivacyCollectedDataTypeTracking"] as? Bool == false)
            #expect(declaration["NSPrivacyCollectedDataTypePurposes"] as? [String] == [
                "NSPrivacyCollectedDataTypePurposeAppFunctionality",
            ])
        }
        #expect(reasons(in: manifest) == ["1C8F.1", "CA92.1"])
    }

    @Test(arguments: [
        "ThruFlowLiveActivity/PrivacyInfo.xcprivacy",
        "ThruFlowNotificationService/PrivacyInfo.xcprivacy",
    ])
    func extensionManifestDeclaresOnlySharedAppGroupDefaults(path: String) throws {
        let manifest = try loadManifest(at: path)
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
        #expect(reasons(in: manifest) == ["1C8F.1"])
    }

    private func loadManifest(at path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: repositoryRoot.appending(path: path))
        return try #require(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
    }

    private func reasons(in manifest: [String: Any]) -> Set<String> {
        guard let types = manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]] else {
            return []
        }
        return Set(types.flatMap { $0["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? [] })
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
