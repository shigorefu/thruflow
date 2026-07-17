//
//  LocalisationTests.swift
//  ThruFlowTests
//
//  Created by Codex on 2026/07/17.
//

import Foundation
import Testing

struct LocalisationTests {
    @Test func catalogUsesJapaneseAsSourceLanguage() throws {
        let data = try Data(contentsOf: catalogURL)
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: Any])

        #expect(root["sourceLanguage"] as? String == "ja")
        #expect(strings.count >= 350)
        #expect(!data.contains(Data("\"extractionState\" : \"stale\"".utf8)))
    }

    @Test func japaneseAppLiteralsUseLocalisationAPI() throws {
        let sourceRoot = repositoryRoot.appending(path: "ThruFlow")
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: sourceRoot,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        )
        var violations: [String] = []

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            for (offset, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                guard containsJapaneseStringLiteral(String(line)) else { continue }
                guard !line.contains("String(localized:") else { continue }

                let relativePath = fileURL.path.replacingOccurrences(
                    of: repositoryRoot.path + "/",
                    with: ""
                )
                violations.append("\(relativePath):\(offset + 1)")
            }
        }

        #expect(violations.isEmpty, "Unlocalized Japanese literals: \(violations.joined(separator: ", "))")
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var catalogURL: URL {
        repositoryRoot.appending(path: "ThruFlow/Localisation/Localizable.xcstrings")
    }

    private func containsJapaneseStringLiteral(_ line: String) -> Bool {
        line.range(
            of: #"\"[^\"\\]*(?:[ぁ-んァ-ヶ一-龯々ー])[^\"\\]*\""#,
            options: .regularExpression
        ) != nil
    }
}
