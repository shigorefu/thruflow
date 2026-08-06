import Foundation
import Testing

struct PrivacyManifestTests {
    @Test func appManifestDeclaresOnlyRequiredDefaultsReasons() throws {
        let manifest = try loadManifest(at: "ThruFlow/PrivacyInfo.xcprivacy")
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
        #expect(reasons(in: manifest) == ["1C8F.1", "CA92.1"])
    }

    @Test func widgetManifestDeclaresOnlySharedAppGroupDefaults() throws {
        let manifest = try loadManifest(at: "ThruFlowLiveActivity/PrivacyInfo.xcprivacy")
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
    }
}
