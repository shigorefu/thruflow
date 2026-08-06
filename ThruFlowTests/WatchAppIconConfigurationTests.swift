import Foundation
import Testing

struct WatchAppIconConfigurationTests {
    @Test func watchAppDeclaresDeviceAndMarketingIcons() throws {
        let infoData = try Data(contentsOf: repositoryURL.appending(path: "ThruFlow/Platforms/watchOS/App/Info.plist"))
        let info = try #require(
            PropertyListSerialization.propertyList(from: infoData, format: nil) as? [String: Any]
        )
        let icons = try #require(info["CFBundleIcons"] as? [String: Any])
        let primary = try #require(icons["CFBundlePrimaryIcon"] as? [String: Any])

        #expect(primary["CFBundleIconName"] as? String == "AppIcon-Watch")
        #expect(primary["CFBundleIconFiles"] as? [String] == ["AppIcon-Watch"])

        let catalogURL = repositoryURL.appending(
            path: "ThruFlow/Assets.xcassets/AppIcon-Watch.appiconset"
        )
        let catalogData = try Data(contentsOf: catalogURL.appending(path: "Contents.json"))
        let catalog = try #require(
            JSONSerialization.jsonObject(with: catalogData) as? [String: Any]
        )
        let images = try #require(catalog["images"] as? [[String: Any]])
        let roles = Set(images.compactMap { $0["role"] as? String })

        #expect(roles.isSuperset(of: [
            "notificationCenter",
            "companionSettings",
            "appLauncher",
            "quickLook",
        ]))
        #expect(images.contains { $0["idiom"] as? String == "watch-marketing" })

        for image in images {
            let filename = try #require(image["filename"] as? String)
            #expect(FileManager.default.fileExists(atPath: catalogURL.appending(path: filename).path))
        }
    }

    private var repositoryURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
